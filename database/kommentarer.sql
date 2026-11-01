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
