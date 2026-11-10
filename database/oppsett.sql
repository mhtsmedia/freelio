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
grant select on public.freelancers to anon;
-- Uinnlogget får ikke interne id-er (jobs.owner_id, reviews.author_id/order_id)
grant select (id, demo, status, data, created_at) on public.jobs to anon;
grant select (id, freelancer_id, author_name, stars, text, job_label, created_at) on public.reviews to anon;
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

-- ============================================================
-- Innlegg på Utforsk
-- ============================================================

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  freelancer_id text not null references public.freelancers (id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists posts_created_idx on public.posts (created_at desc);
alter table public.posts enable row level security;

drop policy if exists "innlegg les" on public.posts;
create policy "innlegg les" on public.posts for select using (true);
drop policy if exists "innlegg lag" on public.posts;
create policy "innlegg lag" on public.posts for insert to authenticated
  with check (freelancer_id in (select public.my_freelancer_ids()));
drop policy if exists "innlegg slett" on public.posts;
create policy "innlegg slett" on public.posts for delete to authenticated
  using (freelancer_id in (select public.my_freelancer_ids()));

grant select on public.posts to anon;
grant select, insert, delete on public.posts to authenticated;

-- ============================================================
-- Profilbilder og porteføljebilder
-- Offentlige bilder. Sti: <bruker-id>/<filnavn>. Bare eieren kan laste opp, endre og slette.
-- ============================================================

alter table public.profiles add column if not exists avatar_url text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profiles', 'profiles', true, 52428800, array['image/webp', 'image/jpeg', 'image/png', 'video/mp4', 'video/quicktime', 'video/webm'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "profilbilder last opp" on storage.objects;
create policy "profilbilder last opp" on storage.objects for insert to authenticated
  with check (bucket_id = 'profiles' and split_part(name, '/', 1) = auth.uid()::text);
drop policy if exists "profilbilder endre" on storage.objects;
create policy "profilbilder endre" on storage.objects for update to authenticated
  using (bucket_id = 'profiles' and split_part(name, '/', 1) = auth.uid()::text);
drop policy if exists "profilbilder slett" on storage.objects;
create policy "profilbilder slett" on storage.objects for delete to authenticated
  using (bucket_id = 'profiles' and split_part(name, '/', 1) = auth.uid()::text);

-- ============================================================
-- Mapper for lagrede frilansere, innlegg og oppdrag
-- Hver bruker ser og endrer bare sine egne mapper.
-- items er en liste som [{"t":"f","id":"..."}]. t er f (frilanser), p (innlegg) eller j (oppdrag).
-- Kjør denne én gang i SQL Editor. Den kan kjøres flere ganger.
-- ============================================================

create table if not exists public.saved_folders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  items jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists saved_folders_user_idx on public.saved_folders (user_id);
alter table public.saved_folders enable row level security;

drop policy if exists "mapper egne" on public.saved_folders;
create policy "mapper egne" on public.saved_folders for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select, insert, update, delete on public.saved_folders to authenticated;

-- ============================================================
-- Liker og kommentarer på innlegg (Utforsk)
-- Alle kan se antall liker og kommentarene. Bare innloggede kan like og kommentere.
-- Du kan slette dine egne kommentarer, og frilanseren kan slette kommentarer på sine egne innlegg.
-- Kjør denne én gang i SQL Editor. Den kan kjøres flere ganger.
-- ============================================================

create table if not exists public.post_likes (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  author_name text not null default '',
  text text not null check (char_length(text) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index if not exists post_comments_post_idx on public.post_comments (post_id, created_at);

alter table public.post_likes enable row level security;
alter table public.post_comments enable row level security;

drop policy if exists "liker les" on public.post_likes;
create policy "liker les" on public.post_likes for select using (true);
drop policy if exists "liker lag" on public.post_likes;
create policy "liker lag" on public.post_likes for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "liker fjern" on public.post_likes;
create policy "liker fjern" on public.post_likes for delete to authenticated using (user_id = auth.uid());

drop policy if exists "kommentarer les" on public.post_comments;
create policy "kommentarer les" on public.post_comments for select using (true);
drop policy if exists "kommentarer skriv" on public.post_comments;
create policy "kommentarer skriv" on public.post_comments for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "kommentarer slett" on public.post_comments;
create policy "kommentarer slett" on public.post_comments for delete to authenticated
  using (user_id = auth.uid() or post_id in (select id from public.posts where freelancer_id in (select public.my_freelancer_ids())));

grant select on public.post_likes, public.post_comments to anon;
grant select, insert, delete on public.post_likes, public.post_comments to authenticated;

-- ============================================================
-- Sikkerhet: regler som nettsiden ikke kan omgå
-- Koden i nettleseren kan alle lese, og hvem som helst kan snakke direkte med databasen
-- med den offentlige nøkkelen. Derfor sjekker databasen selv at
--   * tekster og data ikke er for store
--   * bilder og videoer ligger i brukerens egen mappe i bildelagringen
--   * bestillinger og tilbud bare endres på lovlig måte
--   * merket «BankID-verifisert» og antall oppdrag ikke kan settes av frilanseren selv
--   * navnet på omtaler og kommentarer er det ekte navnet
--   * ingen kan sende meldinger til folk de ikke har kontakt med, eller sende for mye på kort tid
-- Gamle rader sjekkes ikke (not valid), men alt nytt og alt som endres må følge reglene.
-- Kjør denne én gang i SQL Editor, etter de andre filene. Den kan kjøres flere ganger.
-- ============================================================

-- ---------- hjelpere ----------

-- Sant hvis alle bilde- og videoadresser i data peker til mappen <uid>/ i bildelagringen «profiles»
create or replace function public.own_media(d jsonb, uid text)
returns boolean language sql immutable as $$
  select not exists (
    select 1 from (
      select jsonb_path_query(d, 'lax $.**.photo') as u
      union all select jsonb_path_query(d, 'lax $.**.url')
      union all select jsonb_path_query(d, 'lax $.**.thumb')
      union all select jsonb_path_query(d, 'lax $.**.src')
    ) x
    where jsonb_typeof(u) = 'string' and (u #>> '{}') <> ''
      and (u #>> '{}') !~ ('^https://[a-z0-9-]+\.supabase\.co/storage/v1/object/public/profiles/' || uid || '/')
  )
$$;

-- Frilanseren som er logget inn, kan skrive til denne kunden bare hvis kunden har tatt kontakt,
-- har en bestilling, eller har et oppdrag frilanseren har sendt tilbud på
create or replace function public.can_message(cid uuid, fid text)
returns boolean language sql stable security definer set search_path = public as $$
  select fid in (select public.my_freelancer_ids()) and (
    exists (select 1 from public.messages m where m.customer_id = cid and m.freelancer_id = fid and m.sender = 'customer')
    or exists (select 1 from public.orders o where o.customer_id = cid and o.freelancer_id = fid)
    or exists (select 1 from public.offers f join public.jobs j on j.id = f.job_id where j.owner_id = cid and f.freelancer_id = fid)
  )
$$;

-- Kunder som frilanseren som er logget inn, har en samtale eller bestilling med
create or replace function public.is_my_customer(cid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.messages m where m.customer_id = cid and m.freelancer_id in (select public.my_freelancer_ids()))
      or exists (select 1 from public.orders o where o.customer_id = cid and o.freelancer_id in (select public.my_freelancer_ids()))
$$;

-- Antall filer brukeren som er logget inn, har i bildelagringen
create or replace function public.my_file_count()
returns integer language sql stable security definer set search_path = public, storage as $$
  select count(*)::integer from storage.objects where bucket_id = 'profiles' and split_part(name, '/', 1) = auth.uid()::text
$$;

-- Stopper den som sender for mye på kort tid.
-- Argumenter: hvilke rader som er «mine» ($1 er bruker-id-en som tekst), hvor mange, og i hvor lang tid.
create or replace function public.limit_rate()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  n integer;
begin
  if auth.uid() is null then
    return new;
  end if;
  execute format('select count(*) from %I.%I where (%s) and created_at > now() - $2::interval', tg_table_schema, tg_table_name, tg_argv[0])
    into n using auth.uid()::text, tg_argv[2];
  if n >= tg_argv[1]::integer then
    raise exception 'Du har sendt for mye på kort tid. Vent litt og prøv igjen.' using errcode = 'P0001';
  end if;
  return new;
end $$;

-- ---------- nye brukere: navnet kortes ned ----------

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name)
  values (new.id, left(coalesce(nullif(new.raw_user_meta_data ->> 'name', ''), split_part(new.email, '@', 1)), 60))
  on conflict (id) do nothing;
  return new;
end $$;

-- ---------- grenser for lengde og størrelse ----------

alter table public.profiles drop constraint if exists profiles_grenser;
alter table public.profiles add constraint profiles_grenser check (
  char_length(name) <= 80
  and (avatar_url is null or (char_length(avatar_url) <= 500
    and avatar_url ~ ('^https://[a-z0-9-]+\.supabase\.co/storage/v1/object/public/profiles/' || id::text || '/')))
) not valid;

alter table public.freelancers drop constraint if exists freelancers_grenser;
alter table public.freelancers add constraint freelancers_grenser check (
  demo or (
    octet_length(data::text) <= 65536
    and char_length(coalesce(data ->> 'name', '')) <= 80
    and char_length(coalesce(data ->> 'role', '')) <= 80
    and char_length(coalesce(data ->> 'area', '')) <= 80
    and char_length(coalesce(data ->> 'bio', '')) <= 2000
    and (case when jsonb_typeof(data -> 'portfolio') = 'array' then jsonb_array_length(data -> 'portfolio') <= 40 else true end)
    and public.own_media(data, id)
  )
) not valid;

alter table public.jobs drop constraint if exists jobs_grenser;
alter table public.jobs add constraint jobs_grenser check (
  demo or (
    octet_length(data::text) <= 16384
    and char_length(coalesce(data ->> 'title', '')) <= 120
    and char_length(coalesce(data ->> 'desc', '')) <= 4000
  )
) not valid;

alter table public.offers drop constraint if exists offers_grenser;
alter table public.offers add constraint offers_grenser check (char_length(msg) <= 2000 and price <= 10000000) not valid;

alter table public.orders drop constraint if exists orders_grenser;
alter table public.orders add constraint orders_grenser check (
  char_length(title) <= 200 and price <= 10000000 and octet_length(data::text) <= 131072
) not valid;

alter table public.reviews drop constraint if exists reviews_grenser;
alter table public.reviews add constraint reviews_grenser check (
  char_length(text) <= 2000 and char_length(author_name) <= 80 and char_length(job_label) <= 200
) not valid;

alter table public.posts drop constraint if exists posts_grenser;
alter table public.posts add constraint posts_grenser check (
  octet_length(data::text) <= 8192
  and char_length(coalesce(data ->> 'cap', '')) <= 1000
  and public.own_media(data, freelancer_id)
) not valid;

-- ---------- frilansere: merker og tall settes av databasen ----------
-- Innlogging med BankID finnes ikke ennå, så ingen ekte profil kan være BankID-verifisert.
-- Antall oppdrag telles fra godkjente bestillinger. Snitt og antall omtaler regnes ut fra omtalene.

create or replace function public.guard_freelancer()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or new.demo then
    return new;
  end if;
  new.data := new.data || jsonb_build_object(
    'verified', false, 'rating', 0, 'reviews', 0,
    'jobs', (select count(*) from public.orders o where o.freelancer_id = new.id and o.status = 'approved'));
  return new;
end $$;

drop trigger if exists freelancers_guard on public.freelancers;
create trigger freelancers_guard before insert or update on public.freelancers
  for each row execute function public.guard_freelancer();

-- ---------- bestillinger ----------
-- Reglene for bestillinger (status, avtale og utbetaling) ligger i database/avtale.sql.

-- ---------- tilbud: etter at tilbudet er sendt, kan bare «sett» endres ----------

create or replace function public.guard_offer()
returns trigger language plpgsql set search_path = public as $$
begin
  if auth.uid() is not null and (to_jsonb(new) - 'seen') is distinct from (to_jsonb(old) - 'seen') then
    raise exception 'Et sendt tilbud kan ikke endres.' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists offers_guard on public.offers;
create trigger offers_guard before update on public.offers
  for each row execute function public.guard_offer();

-- ---------- omtaler: navnet er alltid navnet på kontoen ----------

create or replace function public.set_author_name()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then
    new.author_name := left(coalesce((select nullif(name, '') from public.profiles where id = auth.uid()), 'Bruker'), 80);
  end if;
  return new;
end $$;

drop trigger if exists reviews_author on public.reviews;
create trigger reviews_author before insert on public.reviews
  for each row execute function public.set_author_name();

-- ---------- meldinger: frilansere skriver bare til kunder de har kontakt med ----------

drop policy if exists "meldinger send" on public.messages;
create policy "meldinger send" on public.messages for insert to authenticated
  with check (
    (customer_id = auth.uid() and (sender in ('customer', 'system') or (sender = 'freelancer' and public.is_demo_freelancer(freelancer_id))))
    or (freelancer_id in (select public.my_freelancer_ids()) and sender in ('freelancer', 'system') and public.can_message(customer_id, freelancer_id))
  );

-- ---------- profiler: du ser din egen, og kundene du har samtaler eller bestillinger med ----------
-- Frilansere vises fra tabellen freelancers, så ingen trenger å se alle brukerne.

drop policy if exists "profiler les" on public.profiles;
create policy "profiler les" on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_my_customer(id));

-- ---------- bildelagring: høyst 1000 filer per bruker ----------

drop policy if exists "profilbilder last opp" on storage.objects;
create policy "profilbilder last opp" on storage.objects for insert to authenticated
  with check (bucket_id = 'profiles' and split_part(name, '/', 1) = auth.uid()::text and public.my_file_count() < 1000);

-- ---------- fartsgrenser ----------

drop trigger if exists messages_rate_min on public.messages;
create trigger messages_rate_min before insert on public.messages for each row execute function public.limit_rate(
  '(customer_id::text = $1 and sender <> ''freelancer'') or (freelancer_id = $1 and sender <> ''customer'')', '30', '1 minute');
drop trigger if exists messages_rate_day on public.messages;
create trigger messages_rate_day before insert on public.messages for each row execute function public.limit_rate(
  '(customer_id::text = $1 and sender <> ''freelancer'') or (freelancer_id = $1 and sender <> ''customer'')', '500', '1 day');
drop trigger if exists jobs_rate on public.jobs;
create trigger jobs_rate before insert on public.jobs for each row execute function public.limit_rate('owner_id::text = $1', '10', '1 hour');
drop trigger if exists offers_rate on public.offers;
create trigger offers_rate before insert on public.offers for each row execute function public.limit_rate('freelancer_id = $1', '30', '1 hour');
drop trigger if exists orders_rate on public.orders;
create trigger orders_rate before insert on public.orders for each row execute function public.limit_rate('customer_id::text = $1', '20', '1 hour');
drop trigger if exists posts_rate on public.posts;
create trigger posts_rate before insert on public.posts for each row execute function public.limit_rate('freelancer_id = $1', '20', '1 hour');
drop trigger if exists saved_rate on public.saved;
create trigger saved_rate before insert on public.saved for each row execute function public.limit_rate('user_id::text = $1', '500', '100 years');

-- ---------- tabeller fra mapper.sql og kommentarer.sql (bare hvis de finnes) ----------

do $$
begin
  if to_regclass('public.saved_folders') is not null then
    alter table public.saved_folders drop constraint if exists saved_folders_grenser;
    alter table public.saved_folders add constraint saved_folders_grenser check (octet_length(items::text) <= 32768) not valid;
    drop trigger if exists saved_folders_rate on public.saved_folders;
    create trigger saved_folders_rate before insert on public.saved_folders for each row execute function public.limit_rate('user_id::text = $1', '100', '100 years');
  end if;
  if to_regclass('public.post_comments') is not null then
    alter table public.post_comments drop constraint if exists post_comments_grenser;
    alter table public.post_comments add constraint post_comments_grenser check (char_length(author_name) <= 80) not valid;
    drop trigger if exists post_comments_author on public.post_comments;
    create trigger post_comments_author before insert on public.post_comments for each row execute function public.set_author_name();
    drop trigger if exists post_comments_rate_min on public.post_comments;
    create trigger post_comments_rate_min before insert on public.post_comments for each row execute function public.limit_rate('user_id::text = $1', '10', '1 minute');
    drop trigger if exists post_comments_rate_day on public.post_comments;
    create trigger post_comments_rate_day before insert on public.post_comments for each row execute function public.limit_rate('user_id::text = $1', '200', '1 day');
  end if;
  if to_regclass('public.post_likes') is not null then
    drop trigger if exists post_likes_rate on public.post_likes;
    create trigger post_likes_rate before insert on public.post_likes for each row execute function public.limit_rate('user_id::text = $1', '60', '1 minute');
  end if;
end $$;

-- ============================================================
-- Oppdragsavtale og utbetaling
-- Hver bestilling får en avtale som låses når kunden booker. Frilanseren må godta den før
-- leveransen kan sendes. Databasen styrer alt som har med penger og status å gjøre, så ingen
-- kan omgå reglene ved å snakke direkte med databasen:
--   * avtalen kan ikke endres etter booking, og tidspunktene for godkjenning settes av databasen
--   * frilanserens egne vilkår og navnene hentes fra databasen, ikke fra nettleseren
--   * leveransen kan bare sendes når frilanseren har godtatt avtalen
--   * kunden godkjenner, eller leveransen kan godkjennes automatisk 5 dager etter levering
--   * kunden kan melde fra om feil høyst 2 ganger, så pengene ikke kan holdes tilbake for alltid
--   * refusjon ved avbestilling regnes ut av databasen, og frilanseren kan avlyse (full refusjon)
--   * bare frilanseren kan endre selve leveransen (filene)
-- Bestillinger fra før avtalen fantes, fungerer som før.
-- Kjør denne én gang i SQL Editor, etter sikkerhet.sql. Den kan kjøres flere ganger.
-- ============================================================

-- Tidspunkt som tekst (UTC), slik nettsiden leser dem
create or replace function public.now_text()
returns text language sql stable as $$
  select to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
$$;

-- ---------- ny bestilling: avtalen låses ----------

create or replace function public.guard_order_new()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  c jsonb;
  fdata jsonb;
  cname text;
begin
  if auth.uid() is null then
    return new;
  end if;
  c := new.data -> 'contract';
  if c is null or jsonb_typeof(c) <> 'object' or (c ->> 'v') is distinct from '1' then
    raise exception 'Bestillingen mangler avtale. Last siden på nytt og prøv igjen.' using errcode = '42501';
  end if;
  select data into fdata from public.freelancers where id = new.freelancer_id;
  select name into cname from public.profiles where id = new.customer_id;
  -- Avtalen bygges på nytt av databasen. Bare kundens eget tillegg og pakkebeskrivelsen kommer fra nettleseren.
  c := jsonb_build_object(
    'v', 1,
    'title', new.title,
    'price', new.price,
    'date', left(coalesce(new.data ->> 'date', ''), 40),
    'place', left(coalesce(new.data ->> 'place', ''), 200),
    'desc', left(coalesce(c ->> 'desc', ''), 1000),
    'delD', coalesce(fdata -> 'delD', '7'::jsonb),
    'freelancerName', left(coalesce(fdata ->> 'name', ''), 80),
    'customerName', left(coalesce(cname, ''), 80),
    'fTerms', left(coalesce(fdata ->> 'terms', ''), 4000),
    'cTerms', left(coalesce(c ->> 'cTerms', ''), 2000),
    'customerAt', public.now_text(),
    'freelancerAt', null
  );
  new.data := (coalesce(new.data, '{}'::jsonb) - array['deliveredAt', 'disputes', 'refund', 'approvedAt', 'approvedBy', 'cancelledBy'])
    || jsonb_build_object('contract', c);
  return new;
end $$;

drop trigger if exists orders_contract on public.orders;
create trigger orders_contract before insert on public.orders
  for each row execute function public.guard_order_new();

-- ---------- endring av bestilling: status, penger og avtale ----------
-- Erstatter guard_order fra sikkerhet.sql.

create or replace function public.guard_order()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  me uuid;
  is_c boolean;
  is_f boolean;
  dm boolean;
  legacy boolean;
  c jsonb;
  srv jsonb;
  n integer;
  d date;
  refund integer;
begin
  me := auth.uid();
  if me is null then
    return new;
  end if;
  is_c := old.customer_id = me;
  is_f := old.freelancer_id in (select public.my_freelancer_ids());
  dm := public.is_demo_freelancer(old.freelancer_id);

  if new.customer_id is distinct from old.customer_id
     or new.freelancer_id is distinct from old.freelancer_id
     or (new.job_id is distinct from old.job_id and new.job_id is not null)
     or new.price is distinct from old.price
     or new.title is distinct from old.title
     or new.created_at is distinct from old.created_at then
    raise exception 'Bestillingen kan ikke endres på den måten.' using errcode = '42501';
  end if;

  -- Bestillinger fra før avtalen fantes, har ingen avtale og følger de gamle reglene for levering
  c := old.data -> 'contract';
  legacy := c is null or jsonb_typeof(c) <> 'object';

  -- Feltene databasen eier, starter med verdiene som var lagret
  srv := jsonb_build_object(
    'contract', c,
    'deliveredAt', old.data -> 'deliveredAt',
    'disputes', old.data -> 'disputes',
    'refund', old.data -> 'refund',
    'approvedAt', old.data -> 'approvedAt',
    'approvedBy', old.data -> 'approvedBy',
    'cancelledBy', old.data -> 'cancelledBy'
  );

  -- Frilanseren godtar avtalen. Tidspunktet settes her, og kan ikke endres eller fjernes senere.
  if not legacy and is_f and (c ->> 'freelancerAt') is null
     and (new.data -> 'contract' ->> 'freelancerAt') is not null then
    c := jsonb_set(c, '{freelancerAt}', to_jsonb(public.now_text()));
    srv := jsonb_set(srv, '{contract}', c);
  end if;

  if new.status is distinct from old.status then
    if new.status = 'delivered' and old.status in ('paid', 'dispute') and (is_f or (is_c and dm)) then
      if not legacy and not dm and (c ->> 'freelancerAt') is null then
        raise exception 'Du må godta avtalen før du kan sende leveransen.' using errcode = '42501';
      end if;
      srv := srv || jsonb_build_object('deliveredAt', public.now_text());
    elsif new.status = 'approved' and old.status = 'delivered' and (
          is_c
          or (is_f and (old.data ->> 'deliveredAt') is not null
              and (old.data ->> 'deliveredAt')::timestamptz + interval '5 days' <= now())) then
      srv := srv || jsonb_build_object('approvedAt', public.now_text(), 'approvedBy', case when is_c then 'kunde' else 'automatisk' end);
    elsif new.status = 'dispute' and old.status = 'delivered' and is_c then
      n := coalesce((old.data ->> 'disputes')::integer, 0);
      if n >= 2 then
        raise exception 'Du har meldt fra om feil to ganger. Kontakt Freelio, så avgjør vi saken.' using errcode = '42501';
      end if;
      srv := srv || jsonb_build_object('disputes', n + 1);
    elsif new.status = 'cancelled' and old.status = 'paid' and (is_c or is_f) then
      if is_f then
        refund := old.price;
      else
        begin
          d := to_date(old.data ->> 'date', 'DD.MM.YYYY');
        exception when others then
          d := null;
        end;
        refund := case when d is null or d - current_date > 7 then old.price else round(old.price / 2.0)::integer end;
      end if;
      srv := srv || jsonb_build_object('refund', refund, 'cancelledBy', case when is_f then 'frilanser' else 'kunde' end);
    else
      raise exception 'Bestillingen kan ikke flyttes til denne statusen nå.' using errcode = '42501';
    end if;
  end if;

  if new.reviewed is distinct from old.reviewed and not (is_c and new.reviewed and new.status = 'approved') then
    raise exception 'Omtalen på bestillingen kan ikke endres slik.' using errcode = '42501';
  end if;

  -- Feltene databasen eier, kan ikke settes fra nettleseren
  new.data := (coalesce(new.data, '{}'::jsonb) - array['contract', 'deliveredAt', 'disputes', 'refund', 'approvedAt', 'approvedBy', 'cancelledBy'])
    || jsonb_strip_nulls(srv);
  -- Selve leveransen (filene og meldingen) kan bare frilanseren endre
  if not (is_f or dm) then
    new.data := (new.data - array['files', 'delivered', 'deliveryNote'])
      || jsonb_strip_nulls(jsonb_build_object('files', old.data -> 'files', 'delivered', old.data -> 'delivered', 'deliveryNote', old.data -> 'deliveryNote'));
  end if;
  return new;
end $$;

drop trigger if exists orders_guard on public.orders;
create trigger orders_guard before update on public.orders
  for each row execute function public.guard_order();

-- ---------- frilanserens egne vilkår ----------

alter table public.freelancers drop constraint if exists freelancers_vilkar;
alter table public.freelancers add constraint freelancers_vilkar check (
  demo or char_length(coalesce(data ->> 'terms', '')) <= 4000
) not valid;

-- ============================================================
-- Vedlegg i meldinger (samme som database/vedlegg.sql)
-- ============================================================
-- Filene sendes over HTTPS og lagres i en privat mappe (Supabase krypterer lagrede data på disken).
-- Bare kunden og frilanseren i samtalen kan åpne dem. Uten denne filen virker meldinger som før, bare uten vedlegg.

alter table public.messages add column if not exists files jsonb;
alter table public.messages drop constraint if exists messages_files;
alter table public.messages add constraint messages_files check (
  files is null or (jsonb_typeof(files) = 'array' and jsonb_array_length(files) between 1 and 5 and octet_length(files::text) <= 8000)
);

-- Privat lagring, høyst 25 MB per fil. Bare bilder, video, lyd, PDF, tekst, zip og Office-filer
-- (ikke HTML eller SVG, som kan inneholde kode). Samme liste som i js/vedlegg.js.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('vedlegg', 'vedlegg', false, 26214400, array[
  'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic', 'image/heif', 'image/avif',
  'video/mp4', 'video/quicktime', 'video/webm', 'audio/mpeg', 'audio/mp4', 'audio/wav', 'audio/x-m4a',
  'application/pdf', 'text/plain', 'text/csv', 'application/zip', 'application/x-zip-compressed',
  'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-powerpoint', 'application/vnd.openxmlformats-officedocument.presentationml.presentation'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- Stien er kunde-id/frilanser-id/fil-id. Bare kunden og frilanseren i samtalen kan lese filene.
create or replace function public.can_read_attachment(path text)
returns boolean language sql stable security definer set search_path = public as $$
  select split_part(path, '/', 1) = auth.uid()::text
      or split_part(path, '/', 2) in (select public.my_freelancer_ids())
$$;

-- Laste opp: kunden i sine egne samtaler, frilanseren bare til kunder de allerede har kontakt med.
-- Høyst 300 vedlegg per bruker.
create or replace function public.can_write_attachment(path text)
returns boolean language plpgsql stable security definer set search_path = public, storage as $$
declare
  cid uuid;
  fid text := split_part(path, '/', 2);
begin
  if split_part(path, '/', 3) = '' or split_part(path, '/', 4) <> '' then return false; end if;
  begin
    cid := split_part(path, '/', 1)::uuid;
  exception when others then
    return false;
  end;
  if (select count(*) from storage.objects where bucket_id = 'vedlegg' and owner = auth.uid()) >= 300 then return false; end if;
  return (cid = auth.uid() and exists (select 1 from public.freelancers f where f.id = fid))
      or (fid in (select public.my_freelancer_ids()) and public.can_message(cid, fid));
end $$;

drop policy if exists "vedlegg les" on storage.objects;
create policy "vedlegg les" on storage.objects for select to authenticated
  using (bucket_id = 'vedlegg' and public.can_read_attachment(name));
drop policy if exists "vedlegg last opp" on storage.objects;
create policy "vedlegg last opp" on storage.objects for insert to authenticated
  with check (bucket_id = 'vedlegg' and public.can_write_attachment(name));
drop policy if exists "vedlegg slett" on storage.objects;
create policy "vedlegg slett" on storage.objects for delete to authenticated
  using (bucket_id = 'vedlegg' and owner = auth.uid());

-- ============================================================
-- Push-varsler (samme som database/push.sql). Krever funksjonen «varsle» i Supabase.
-- ============================================================

-- Enhetene som skal få varsel. Hver nettleser eller telefon som har slått på varsler, har én rad.
create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  endpoint text not null unique check (endpoint ~ '^https://' and char_length(endpoint) <= 1000),
  p256dh text not null check (char_length(p256dh) between 40 and 200),
  auth text not null check (char_length(auth) between 10 and 100),
  ua text not null default '' check (char_length(ua) <= 300),
  created_at timestamptz not null default now()
);
create index if not exists push_subscriptions_user on public.push_subscriptions (user_id);
alter table public.push_subscriptions enable row level security;
revoke all on public.push_subscriptions from anon;

-- Du ser og sletter bare dine egne. Nye lagres med save_push (under), så en enhet som bytter konto flyttes riktig.
drop policy if exists "push les" on public.push_subscriptions;
create policy "push les" on public.push_subscriptions for select to authenticated using (user_id = auth.uid());
drop policy if exists "push slett" on public.push_subscriptions;
create policy "push slett" on public.push_subscriptions for delete to authenticated using (user_id = auth.uid());

create or replace function public.save_push(p_endpoint text, p_p256dh text, p_auth text, p_ua text default '')
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Logg inn først' using errcode = '42501'; end if;
  -- Høyst 20 enheter per bruker. Den eldste fjernes.
  delete from public.push_subscriptions where id in (
    select id from public.push_subscriptions where user_id = auth.uid() and endpoint <> p_endpoint order by created_at desc offset 19);
  insert into public.push_subscriptions (user_id, endpoint, p256dh, auth, ua)
  values (auth.uid(), p_endpoint, p_p256dh, p_auth, left(coalesce(p_ua, ''), 300))
  on conflict (endpoint) do update set user_id = excluded.user_id, p256dh = excluded.p256dh, auth = excluded.auth, ua = excluded.ua, created_at = now();
end $$;
revoke all on function public.save_push(text, text, text, text) from public, anon;
grant execute on function public.save_push(text, text, text, text) to authenticated;

-- Når du logger ut eller slår av varsler på en enhet
create or replace function public.forget_push(p_endpoint text)
returns void language sql security definer set search_path = public as $$
  delete from public.push_subscriptions where endpoint = p_endpoint and user_id = auth.uid();
$$;
revoke all on function public.forget_push(text) from public, anon;
grant execute on function public.forget_push(text) to authenticated;

-- Hva som er varslet, så hver hendelse bare varsles én gang. Bare funksjonen (service role) bruker tabellen.
create table if not exists public.push_log (
  kind text not null,
  ref uuid not null,
  created_at timestamptz not null default now(),
  primary key (kind, ref)
);
alter table public.push_log enable row level security;
revoke all on public.push_log from anon, authenticated;

-- Databasen sier fra til funksjonen når det kommer et nytt tilbud eller en ny melding.
-- pg_net sender kallet etter at raden er lagret, så det sinker ikke den som sender.
create extension if not exists pg_net;

create or replace function public.push_notify()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform net.http_post(
    url := 'https://hweftjtulzjripkkbdeb.supabase.co/functions/v1/varsle',
    body := jsonb_build_object('type', tg_argv[0], 'id', new.id),
    headers := '{"Content-Type": "application/json"}'::jsonb
  );
  return null;
exception when others then
  -- Et varsel som ikke går, skal aldri stoppe selve tilbudet eller meldingen
  return null;
end $$;

drop trigger if exists offers_push on public.offers;
create trigger offers_push after insert on public.offers
  for each row execute function public.push_notify('offer');
drop trigger if exists messages_push on public.messages;
create trigger messages_push after insert on public.messages
  for each row when (new.sender <> 'system') execute function public.push_notify('message');

-- ============================================================
-- Grenser: makspris 1 000 000 kr og lengde på tekst (samme som database/grenser.sql)
-- ============================================================
-- Samme grenser som skjemaene på nettsiden, så de ikke kan omgås ved å snakke direkte med databasen.
-- «not valid» betyr at reglene gjelder alt som lagres fra nå av. Det som allerede ligger der, blir stående.

-- Oppdrag: budsjett mellom 1 og 1 000 000 kr, og korte felt
alter table public.jobs drop constraint if exists jobs_grenser;
alter table public.jobs add constraint jobs_grenser check (
  demo or (
    octet_length(data::text) <= 16384
    and char_length(coalesce(data ->> 'title', '')) <= 80
    and char_length(coalesce(data ->> 'desc', '')) <= 3000
    and char_length(coalesce(data ->> 'date', '')) <= 40
    and char_length(coalesce(data ->> 'area', '')) <= 60
    and char_length(coalesce(data ->> 'scope', '')) <= 120
    and char_length(coalesce(data ->> 'delivery', '')) <= 200
    and (case when jsonb_typeof(data -> 'budget') = 'number' then (data ->> 'budget')::numeric between 1 and 1000000 else false end)
  )
) not valid;

-- Tilbud: pris mellom 1 og 1 000 000 kr, melding høyst 1000 tegn
alter table public.offers drop constraint if exists offers_grenser;
alter table public.offers add constraint offers_grenser check (
  char_length(msg) <= 1000 and price between 1 and 1000000
) not valid;

-- Bestillinger: høyst 1 000 000 kr
alter table public.orders drop constraint if exists orders_grenser;
alter table public.orders add constraint orders_grenser check (
  char_length(title) <= 200 and price between 0 and 1000000 and octet_length(data::text) <= 131072
) not valid;

-- Frilansere: høyst 4 pakker, hver høyst 1 000 000 kr, korte navn og beskrivelser
alter table public.freelancers drop constraint if exists freelancers_priser;
alter table public.freelancers add constraint freelancers_priser check (
  demo or (
    (case when jsonb_typeof(data -> 'pk') = 'array' then jsonb_array_length(data -> 'pk') <= 4 else true end)
    and not jsonb_path_exists(data, '$.pk[*][1] ? (@ > 1000000 || @ < 0)')
    and not jsonb_path_exists(data, '$.pk[*][0] ? (@ like_regex ".{41}")')
    and not jsonb_path_exists(data, '$.pk[*][2] ? (@ like_regex ".{201}")')
    and (case when jsonb_typeof(data -> 'from') = 'number' then (data ->> 'from')::numeric <= 1000000 else true end)
    and char_length(coalesce(data ->> 'terms', '')) <= 4000
  )
) not valid;

-- Meldinger: høyst 2000 tegn (det samme som skrivefeltet)
alter table public.messages drop constraint if exists messages_lengde;
alter table public.messages add constraint messages_lengde check (char_length(text) <= 2000) not valid;

-- ============================================================
-- Admin: fjerne annonser (samme som database/admin.sql)
-- ============================================================
-- Bare kontoer i tabellen admins kan fjerne andres annonser. Alt som fjernes, logges i admin_log.
-- Ingen kan lese eller endre tabellene fra nettsiden. Du ser loggen i Supabase (Table Editor -> admin_log).

create table if not exists public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admins enable row level security;
revoke all on public.admins from anon, authenticated;

create table if not exists public.admin_log (
  id bigint generated always as identity primary key,
  admin_id uuid not null,
  action text not null,
  ref text not null,
  note text not null default '',
  created_at timestamptz not null default now()
);
alter table public.admin_log enable row level security;
revoke all on public.admin_log from anon, authenticated;

-- Er den som er logget inn, admin? Nettsiden bruker dette bare for å vise knappen.
-- Selve slettingen sjekker det på nytt i databasen.
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid())
$$;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- Fjerner en annonse (og tilbudene på den). Bestillinger blir stående, uten kobling til annonsen.
create or replace function public.admin_delete_job(p_id uuid, p_reason text default '')
returns void language plpgsql security definer set search_path = public as $$
declare
  t text;
begin
  if not public.is_admin() then
    raise exception 'Bare admin kan fjerne andres annonser.' using errcode = '42501';
  end if;
  delete from public.jobs where id = p_id returning data ->> 'title' into t;
  if not found then
    raise exception 'Fant ikke annonsen. Den kan allerede være fjernet.';
  end if;
  insert into public.admin_log (admin_id, action, ref, note)
  values (auth.uid(), 'fjernet oppdrag', p_id::text, left(coalesce(t, '') || case when coalesce(p_reason, '') <> '' then ' | Grunn: ' || p_reason else '' end, 500));
end $$;
revoke all on function public.admin_delete_job(uuid, text) from public, anon;
grant execute on function public.admin_delete_job(uuid, text) to authenticated;

-- Gjør kontoen din til admin. Bytt ut e-posten med den du logger inn på Freelio med, og kjør linjen.
-- insert into public.admins (user_id) select id from auth.users where email = 'DIN-EPOST@eksempel.no' on conflict do nothing;
