-- ============================================================
-- Admin: fjerne annonser som bryter reglene
-- Kjør denne én gang i SQL Editor. Den kan kjøres flere ganger.
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
