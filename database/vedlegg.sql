-- ============================================================
-- Vedlegg i meldinger
-- Kjør denne én gang i SQL Editor. Den kan kjøres flere ganger.
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
