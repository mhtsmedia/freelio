-- Freelio: database for Supabase.
-- Lim inn hele filen i Supabase: SQL Editor -> New query -> Run.
-- Skriptet kan kjøres flere ganger. Det sletter ikke data som finnes.

create extension if not exists pgcrypto;

-- ============================================================
-- Tabeller
-- ============================================================

-- Én rad per bruker. Lages automatisk når noen oppretter konto.
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null default '',
  created_at timestamptz not null default now()
);

-- Frilanserprofiler. Demo-frilansere har ingen bruker (user_id er tom).
-- Ekte frilansere har id lik bruker-id-en sin.
create table if not exists public.freelancers (
  id text primary key,
  user_id uuid unique references public.profiles (id) on delete cascade,
  demo boolean not null default false,
  published boolean not null default true,
  data jsonb not null,
  created_at timestamptz not null default now()
);

-- Oppdrag som kunder legger ut
create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles (id) on delete cascade,
  demo boolean not null default false,
  status text not null default 'open' check (status in ('open', 'booked', 'closed')),
  data jsonb not null,
  created_at timestamptz not null default now()
);

-- Tilbud fra frilansere på oppdrag
create table if not exists public.offers (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs (id) on delete cascade,
  freelancer_id text not null references public.freelancers (id) on delete cascade,
  price integer not null check (price > 0),
  msg text not null default '',
  visible_at timestamptz not null default now(),
  seen boolean not null default false,
  created_at timestamptz not null default now(),
  unique (job_id, freelancer_id)
);

-- Bestillinger med trygg betaling
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null,
  freelancer_id text not null references public.freelancers (id) on delete cascade,
  job_id uuid references public.jobs (id) on delete set null,
  status text not null default 'paid' check (status in ('paid', 'delivered', 'approved', 'dispute', 'cancelled')),
  title text not null,
  price integer not null check (price > 0),
  reviewed boolean not null default false,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Meldinger mellom kunde og frilanser
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null,
  freelancer_id text not null references public.freelancers (id) on delete cascade,
  sender text not null check (sender in ('customer', 'freelancer', 'system')),
  text text not null check (char_length(text) between 1 and 4000),
  created_at timestamptz not null default now()
);

-- Omtaler. Bare kunden på en godkjent bestilling kan skrive én omtale.
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders (id) on delete cascade,
  author_id uuid not null,
  freelancer_id text not null references public.freelancers (id) on delete cascade,
  author_name text not null default '',
  stars integer not null check (stars between 1 and 5),
  text text not null default '',
  job_label text not null default '',
  created_at timestamptz not null default now()
);

-- Lagrede frilansere
create table if not exists public.saved (
  user_id uuid not null references public.profiles (id) on delete cascade,
  freelancer_id text not null references public.freelancers (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, freelancer_id)
);

create index if not exists orders_customer_idx on public.orders (customer_id);
create index if not exists orders_freelancer_idx on public.orders (freelancer_id);
create index if not exists messages_customer_idx on public.messages (customer_id);
create index if not exists messages_freelancer_idx on public.messages (freelancer_id);
create index if not exists offers_job_idx on public.offers (job_id);
create index if not exists jobs_owner_idx on public.jobs (owner_id);

-- ============================================================
-- Funksjoner
-- ============================================================

-- Lager profil når en ny bruker registrerer seg
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(nullif(new.raw_user_meta_data ->> 'name', ''), split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Frilanser-id-ene som tilhører innlogget bruker
create or replace function public.my_freelancer_ids()
returns setof text language sql stable security definer set search_path = public as $$
  select id from public.freelancers where user_id = auth.uid()
$$;

create or replace function public.is_demo_freelancer(fid text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select demo from public.freelancers where id = fid), false)
$$;

create or replace function public.owns_job(jid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.jobs where id = jid and owner_id = auth.uid())
$$;

-- Samtaler, bestillinger og omtaler blir stående når en kunde sletter kontoen sin.
-- Frilanseren ser dem fortsatt, med navnet «Slettet bruker».
alter table public.orders drop constraint if exists orders_customer_id_fkey;
alter table public.messages drop constraint if exists messages_customer_id_fkey;
alter table public.reviews drop constraint if exists reviews_author_id_fkey;

-- Lar en bruker slette sin egen konto og alt som hører til den
create or replace function public.delete_my_account()
returns void language sql security definer set search_path = public as $$
  update public.reviews set author_name = 'Tidligere kunde' where author_id = auth.uid();
  delete from auth.users where id = auth.uid();
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- ============================================================
-- Tilgangsregler (Row Level Security)
-- ============================================================

alter table public.profiles enable row level security;
alter table public.freelancers enable row level security;
alter table public.jobs enable row level security;
alter table public.offers enable row level security;
alter table public.orders enable row level security;
alter table public.messages enable row level security;
alter table public.reviews enable row level security;
alter table public.saved enable row level security;

-- Profiler: navn kan leses av innloggede, bare egen profil kan endres
drop policy if exists "profiler les" on public.profiles;
create policy "profiler les" on public.profiles for select to authenticated using (true);
drop policy if exists "profiler endre egen" on public.profiles;
create policy "profiler endre egen" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Frilansere: publiserte er offentlige, bare eier kan endre sin egen
drop policy if exists "frilansere les" on public.freelancers;
create policy "frilansere les" on public.freelancers for select using (published or user_id = auth.uid());
drop policy if exists "frilansere lag egen" on public.freelancers;
create policy "frilansere lag egen" on public.freelancers for insert to authenticated
  with check (user_id = auth.uid() and id = auth.uid()::text and not demo);
drop policy if exists "frilansere endre egen" on public.freelancers;
create policy "frilansere endre egen" on public.freelancers for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid() and id = auth.uid()::text and not demo);
drop policy if exists "frilansere slett egen" on public.freelancers;
create policy "frilansere slett egen" on public.freelancers for delete to authenticated using (user_id = auth.uid());

-- Oppdrag: alle kan lese, bare eier kan lage, endre og slette
drop policy if exists "oppdrag les" on public.jobs;
create policy "oppdrag les" on public.jobs for select using (true);
drop policy if exists "oppdrag lag" on public.jobs;
create policy "oppdrag lag" on public.jobs for insert to authenticated with check (owner_id = auth.uid() and not demo);
drop policy if exists "oppdrag endre" on public.jobs;
create policy "oppdrag endre" on public.jobs for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid() and not demo);
drop policy if exists "oppdrag slett" on public.jobs;
create policy "oppdrag slett" on public.jobs for delete to authenticated using (owner_id = auth.uid());

-- Tilbud: synlige for eieren av oppdraget og frilanseren som sendte dem
drop policy if exists "tilbud les" on public.offers;
create policy "tilbud les" on public.offers for select to authenticated
  using (public.owns_job(job_id) or freelancer_id in (select public.my_freelancer_ids()));
drop policy if exists "tilbud lag" on public.offers;
create policy "tilbud lag" on public.offers for insert to authenticated
  with check (
    (freelancer_id in (select public.my_freelancer_ids()) and not public.owns_job(job_id))
    or (public.is_demo_freelancer(freelancer_id) and public.owns_job(job_id))
  );
drop policy if exists "tilbud endre" on public.offers;
create policy "tilbud endre" on public.offers for update to authenticated
  using (public.owns_job(job_id) or freelancer_id in (select public.my_freelancer_ids()));
drop policy if exists "tilbud slett" on public.offers;
create policy "tilbud slett" on public.offers for delete to authenticated
  using (freelancer_id in (select public.my_freelancer_ids()) or public.owns_job(job_id));

-- Bestillinger: bare kunden og frilanseren ser og endrer dem
drop policy if exists "bestillinger les" on public.orders;
create policy "bestillinger les" on public.orders for select to authenticated
  using (customer_id = auth.uid() or freelancer_id in (select public.my_freelancer_ids()));
drop policy if exists "bestillinger lag" on public.orders;
create policy "bestillinger lag" on public.orders for insert to authenticated
  with check (customer_id = auth.uid() and status = 'paid' and freelancer_id not in (select public.my_freelancer_ids()));
drop policy if exists "bestillinger endre" on public.orders;
create policy "bestillinger endre" on public.orders for update to authenticated
  using (customer_id = auth.uid() or freelancer_id in (select public.my_freelancer_ids()))
  with check (customer_id = auth.uid() or freelancer_id in (select public.my_freelancer_ids()));

-- Meldinger: bare de to i samtalen
drop policy if exists "meldinger les" on public.messages;
create policy "meldinger les" on public.messages for select to authenticated
  using (customer_id = auth.uid() or freelancer_id in (select public.my_freelancer_ids()));
drop policy if exists "meldinger send" on public.messages;
create policy "meldinger send" on public.messages for insert to authenticated
  with check (
    (customer_id = auth.uid() and (sender in ('customer', 'system') or (sender = 'freelancer' and public.is_demo_freelancer(freelancer_id))))
    or (freelancer_id in (select public.my_freelancer_ids()) and sender in ('freelancer', 'system'))
  );

-- Omtaler: alle kan lese, bare kunden på en godkjent bestilling kan skrive
drop policy if exists "omtaler les" on public.reviews;
create policy "omtaler les" on public.reviews for select using (true);
drop policy if exists "omtaler skriv" on public.reviews;
create policy "omtaler skriv" on public.reviews for insert to authenticated
  with check (
    author_id = auth.uid()
    and exists (select 1 from public.orders o where o.id = order_id and o.customer_id = auth.uid() and o.status = 'approved' and o.freelancer_id = reviews.freelancer_id)
  );

-- Lagrede: bare egne
drop policy if exists "lagrede egne" on public.saved;
create policy "lagrede egne" on public.saved for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Tilgang for nettsiden (reglene over bestemmer hvilke rader)
grant usage on schema public to anon, authenticated;
grant select on public.freelancers, public.jobs, public.reviews to anon;
grant select, insert, update, delete on all tables in schema public to authenticated;

-- ============================================================
-- Fillagring for leveranser
-- Sti: <bestillings-id>/<fil-id>/original | preview | thumb
-- Kunden kan bare hente originalen når bestillingen er godkjent.
-- ============================================================

insert into storage.buckets (id, name, public)
values ('deliveries', 'deliveries', false)
on conflict (id) do nothing;

create or replace function public.can_read_delivery(path text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.orders o
    where o.id::text = split_part(path, '/', 1)
      and (
        o.freelancer_id in (select public.my_freelancer_ids())
        or (o.customer_id = auth.uid() and (split_part(path, '/', 3) <> 'original' or o.status = 'approved'))
      )
  )
$$;

create or replace function public.can_write_delivery(path text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.orders o
    where o.id::text = split_part(path, '/', 1)
      and o.status in ('paid', 'dispute')
      and (
        o.freelancer_id in (select public.my_freelancer_ids())
        or (o.customer_id = auth.uid() and public.is_demo_freelancer(o.freelancer_id))
      )
  )
$$;

drop policy if exists "leveranser les" on storage.objects;
create policy "leveranser les" on storage.objects for select to authenticated
  using (bucket_id = 'deliveries' and public.can_read_delivery(name));
drop policy if exists "leveranser last opp" on storage.objects;
create policy "leveranser last opp" on storage.objects for insert to authenticated
  with check (bucket_id = 'deliveries' and public.can_write_delivery(name));
drop policy if exists "leveranser slett" on storage.objects;
create policy "leveranser slett" on storage.objects for delete to authenticated
  using (bucket_id = 'deliveries' and public.can_write_delivery(name));
