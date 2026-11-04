-- Freelio: alle oppdateringer samlet. Kjør hele filen én gang i SQL Editor.
-- Den kan kjøres flere ganger uten å ødelegge noe.

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
-- Video i porteføljen
-- Lar frilansere laste opp video (MP4, MOV, WebM) på opptil 50 MB.
-- Kjør denne én gang i SQL Editor. Den kan kjøres flere ganger.
-- ============================================================

update storage.buckets
set file_size_limit = 52428800,
    allowed_mime_types = array['image/webp', 'image/jpeg', 'image/png', 'video/mp4', 'video/quicktime', 'video/webm']
where id = 'profiles';

-- ============================================================
-- Behold samtaler når en kunde sletter kontoen
-- Kjør denne én gang i SQL Editor. Den kan kjøres flere ganger.
-- ============================================================

-- Samtaler, bestillinger og omtaler blir stående når en kunde sletter kontoen sin.
-- Frilanseren ser dem fortsatt, med navnet «Slettet bruker».
alter table public.orders drop constraint if exists orders_customer_id_fkey;
alter table public.messages drop constraint if exists messages_customer_id_fkey;
alter table public.reviews drop constraint if exists reviews_author_id_fkey;

create or replace function public.delete_my_account()
returns void language sql security definer set search_path = public as $$
  update public.reviews set author_name = 'Tidligere kunde' where author_id = auth.uid();
  delete from auth.users where id = auth.uid();
$$;

-- ============================================================
-- Innlegg på Utforsk
-- Frilansere legger selv ut bilder og videoer. Alle kan se dem.
-- Bare frilanseren som eier innlegget kan lage og slette det.
-- Kjør denne én gang i SQL Editor. Den kan kjøres flere ganger.
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
-- Fjern demo-frilansere og demo-oppdrag
-- Sletter alt som ble lagt inn som eksempel (demo = true), med tilbud,
-- bestillinger, meldinger og omtaler som hører til dem.
-- Ekte brukere og deres data blir ikke rørt.
-- ============================================================

delete from public.jobs where demo = true;
delete from public.freelancers where demo = true;

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

-- ---------- bestillinger: riktig rekkefølge, og pris og parter kan ikke endres ----------
-- Frilanseren leverer (betalt eller reklamert -> levert). Kunden godkjenner eller reklamerer (levert ->
-- godkjent eller reklamert), og kan avbestille før levering (betalt -> avbestilt).

create or replace function public.guard_order()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  me uuid;
  is_c boolean;
  is_f boolean;
  dm boolean;
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
  if new.status is distinct from old.status and not (
       ((is_f or (is_c and dm)) and old.status in ('paid', 'dispute') and new.status = 'delivered')
    or (is_c and old.status = 'delivered' and new.status in ('approved', 'dispute'))
    or (is_c and old.status = 'paid' and new.status = 'cancelled')
  ) then
    raise exception 'Bestillingen kan ikke flyttes til denne statusen nå.' using errcode = '42501';
  end if;
  if new.reviewed is distinct from old.reviewed and not (is_c and new.reviewed and new.status = 'approved') then
    raise exception 'Omtalen på bestillingen kan ikke endres slik.' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists orders_guard on public.orders;
create trigger orders_guard before update on public.orders
  for each row execute function public.guard_order();

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
