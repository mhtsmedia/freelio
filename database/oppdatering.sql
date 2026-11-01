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
