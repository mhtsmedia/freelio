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
