-- ============================================================
-- Hvem som har lagt ut oppdraget: navn, profilbilde, medlem siden og antall oppdrag
-- Kjør denne én gang i SQL Editor. Den kan kjøres flere ganger.
-- ============================================================
-- Navnet hentes fra profilen i databasen, så ingen kan skrive inn et falskt navn på oppdraget.
-- Bare det som vises på siden, deles: navn, profilbilde, når kontoen ble laget, antall oppdrag og
-- frilanserprofilen hvis personen har en. Ikke e-post eller interne id-er for kontoen.

create or replace function public.job_posters()
returns table (job_id uuid, name text, photo text, since timestamptz, jobs integer, fid text)
language sql stable security definer set search_path = public as $$
  select
    j.id,
    case when p.id is null then 'Slettet bruker' else coalesce(nullif(p.name, ''), 'Bruker') end,
    p.avatar_url,
    p.created_at,
    (select count(*)::integer from public.jobs x where x.owner_id = j.owner_id and not x.demo),
    (select f.id from public.freelancers f where f.user_id = j.owner_id and f.published and not f.demo limit 1)
  from public.jobs j
  left join public.profiles p on p.id = j.owner_id
  where not j.demo
$$;
revoke all on function public.job_posters() from public;
grant execute on function public.job_posters() to anon, authenticated;
