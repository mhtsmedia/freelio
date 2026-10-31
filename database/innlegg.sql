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
