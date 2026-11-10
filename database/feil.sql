-- ============================================================
-- Meld feil: midlertidig side der alle kan sende inn feil de finner (meld-feil.html)
-- Kjør database/admin.sql først, og så denne én gang i SQL Editor. Den kan kjøres flere ganger.
-- ============================================================
-- Alle kan sende inn, også uten å logge inn. Bare admin kan lese og merke feilene som fikset,
-- på meld-feil.html eller i Supabase (Table Editor -> bug_reports).

create table if not exists public.bug_reports (
  id bigint generated always as identity primary key,
  user_id uuid default auth.uid() references auth.users (id) on delete set null,
  kind text not null default 'virker-ikke' check (kind in ('liten', 'virker-ikke', 'stopper')),
  what text not null check (char_length(what) between 5 and 2000),
  expected text not null default '' check (char_length(expected) <= 1000),
  page text not null default '' check (char_length(page) <= 300),
  email text not null default '' check (char_length(email) <= 254),
  info jsonb not null default '{}'::jsonb check (pg_column_size(info) <= 2000),
  status text not null default 'ny' check (status in ('ny', 'fikset', 'avvist')),
  created_at timestamptz not null default now()
);
create index if not exists bug_reports_created_idx on public.bug_reports (created_at desc);
alter table public.bug_reports enable row level security;

drop policy if exists "feil send" on public.bug_reports;
create policy "feil send" on public.bug_reports for insert to anon, authenticated
  with check (status = 'ny' and (user_id is null or user_id = auth.uid()));
drop policy if exists "feil les admin" on public.bug_reports;
create policy "feil les admin" on public.bug_reports for select to authenticated using (public.is_admin());
drop policy if exists "feil endre admin" on public.bug_reports;
create policy "feil endre admin" on public.bug_reports for update to authenticated using (public.is_admin()) with check (public.is_admin());

revoke all on public.bug_reports from anon, authenticated;
grant insert (kind, what, expected, page, email, info) on public.bug_reports to anon, authenticated;
grant select, update (status) on public.bug_reports to authenticated;

-- Fartsgrense: 10 i timen per innlogget bruker, og 60 i timen til sammen fra alle som ikke er logget inn
create or replace function public.limit_bug_reports()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  n integer;
begin
  if auth.uid() is not null then
    select count(*) into n from public.bug_reports where user_id = auth.uid() and created_at > now() - interval '1 hour';
    if n >= 10 then raise exception 'Du har sendt mange feilmeldinger på kort tid. Vent litt og prøv igjen.' using errcode = 'P0001'; end if;
  else
    select count(*) into n from public.bug_reports where user_id is null and created_at > now() - interval '1 hour';
    if n >= 60 then raise exception 'Det er sendt veldig mange feilmeldinger akkurat nå. Prøv igjen om en stund.' using errcode = 'P0001'; end if;
  end if;
  return new;
end $$;
drop trigger if exists bug_reports_rate on public.bug_reports;
create trigger bug_reports_rate before insert on public.bug_reports for each row execute function public.limit_bug_reports();

-- Når siden ikke trengs lenger: slett meld-feil.html, sett H.BUGS = false i js/app.js, og kjør linjen under hvis du vil fjerne feilene.
-- drop table if exists public.bug_reports;
