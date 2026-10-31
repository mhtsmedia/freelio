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
