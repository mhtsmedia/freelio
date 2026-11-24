-- ============================================================
-- Sikkerhetssjekkliste (november 2026): det som manglet etter gjennomgangen av vanlige angrep
-- Kjør denne én gang i SQL Editor, etter de andre filene (eller hele database/oppdatering.sql).
-- Den kan kjøres flere ganger.
-- ============================================================
-- Dette endres:
--   * indekser på kolonnene som tilgangsreglene, fartsgrensene og listene slår opp i (raskere og billigere spørringer)
--   * GraphQL slås av. Nettsiden bruker det ikke, og med «aliaser» kan én forespørsel gjøre hundre oppslag
--   * navn renses: usynlige tegn og tegn som snur teksten fjernes, Unicode gjøres om til én fast form (NFKC),
--     og ingen kan kalle seg «Freelio», «Admin» eller «Kundeservice», eller blande alfabeter for å etterligne andre
--   * leveranser: høyst 50 MB per fil (nettsiden deler større filer i biter) og bare bilder, video og biter av dem
--   * fartsgrense for «Hent fra portefølje»: høyst 30 sider og 300 bilder i timen per bruker
-- ============================================================

-- ---------- indekser ----------
-- Tilgangsreglene og fartsgrensene (sikkerhet.sql) teller rader per bruker de siste minuttene.
-- Uten indeks må databasen lese hele tabellen hver gang.
create index if not exists offers_freelancer_time_idx on public.offers (freelancer_id, created_at);
create index if not exists orders_job_idx on public.orders (job_id) where job_id is not null;
create index if not exists orders_status_idx on public.orders (status);
create index if not exists orders_customer_time_idx on public.orders (customer_id, created_at);
create index if not exists messages_thread_idx on public.messages (customer_id, freelancer_id, created_at);
create index if not exists messages_freelancer_time_idx on public.messages (freelancer_id, created_at);
create index if not exists reviews_freelancer_idx on public.reviews (freelancer_id, created_at desc);
create index if not exists reviews_author_idx on public.reviews (author_id);
create index if not exists jobs_status_time_idx on public.jobs (status, created_at desc);
create index if not exists jobs_owner_time_idx on public.jobs (owner_id, created_at);
create index if not exists posts_freelancer_idx on public.posts (freelancer_id, created_at desc);

do $$
begin
  if to_regclass('public.post_likes') is not null then
    create index if not exists post_likes_user_time_idx on public.post_likes (user_id, created_at);
  end if;
  if to_regclass('public.post_comments') is not null then
    create index if not exists post_comments_user_time_idx on public.post_comments (user_id, created_at);
  end if;
  if to_regclass('public.saved_folders') is not null then
    create index if not exists saved_folders_user_time_idx on public.saved_folders (user_id, created_at);
  end if;
  if to_regclass('public.bug_reports') is not null then
    create index if not exists bug_reports_user_time_idx on public.bug_reports (user_id, created_at);
  end if;
end $$;

-- ---------- GraphQL av ----------
-- Nettsiden snakker bare med databasen gjennom REST (supabase-js). GraphQL er en ekstra dør inn som ingen bruker.
-- Tilgangsreglene gjelder der også, men med «aliaser» kan én forespørsel be om det samme hundre ganger.
-- Går det ikke herfra (mangler rettighet), slå det av under Database -> Extensions -> pg_graphql.
do $$
begin
  drop extension if exists pg_graphql;
exception when others then
  begin
    revoke usage on schema graphql_public from anon, authenticated;
  exception when others then
    raise notice 'Fikk ikke slått av GraphQL herfra. Slå av pg_graphql under Database -> Extensions.';
  end;
end $$;

-- ---------- navn: ingen usynlige tegn og ingen etterligning ----------
-- Spotify (2013): to brukernavn som så like ut, ble til samme konto etter Unicode-omforming.
-- Her gjøres navnet om til én fast form med en gang det lagres, så det som vises er det som er lagret.

-- Fjerner kontrolltegn, usynlige tegn (zero width) og tegn som snur retningen på teksten, og samler mellomrom
create or replace function public.clean_name(t text)
returns text language sql immutable set search_path = public as $$
  select btrim(regexp_replace(
    regexp_replace(normalize(coalesce(t, ''), NFKC), '[\u0001-\u001F\u007F-\u009F­͏؜ᅟᅠ឴឵᠎​-‏‪-‮⁠-⁯ㅤ︀-️﻿ﾠ]', '', 'g'),
    '\s+', ' ', 'g'))
$$;

-- Sant hvis navnet ser ut som Freelio selv, eller blander latinske og greske eller kyrilliske bokstaver
-- (for eksempel «Frееlio» med kyrilliske е-er, som ser helt likt ut)
create or replace function public.bad_name(t text)
returns boolean language sql immutable set search_path = public as $$
  with n as (select public.clean_name(t) as v)
  select
    (v ~ '[A-Za-z]' and v ~ '[Ͱ-ϿЀ-ԯ]')
    or regexp_replace(lower(v), '[^a-z0-9æøå]', '', 'g') ~ 'freelio'
    or regexp_replace(lower(v), '[^a-z0-9æøå]', '', 'g') in
       ('admin', 'administrator', 'moderator', 'support', 'kundeservice', 'kundestøtte', 'kundestotte', 'hjelp', 'system')
  from n
$$;

-- Profiler (navnet kunder og frilansere ser i meldinger, omtaler og kommentarer)
create or replace function public.guard_profile_name()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.name := left(public.clean_name(new.name), 80);
  if public.bad_name(new.name) and not public.is_admin() then
    if tg_op = 'INSERT' then
      -- Ny konto (også med Google eller telefon): kontoen lages, men brukeren blir bedt om å velge et annet navn
      new.name := 'Ny bruker';
    else
      raise exception 'Navnet kan ikke brukes. Velg navnet ditt, uten «Freelio», «Admin» eller tegn fra flere alfabeter.' using errcode = 'P0001';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists profiles_navn on public.profiles;
create trigger profiles_navn before insert or update of name on public.profiles
  for each row execute function public.guard_profile_name();

-- Frilanserprofiler (navnet ligger i data -> name)
create or replace function public.guard_freelancer_name()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  n text;
begin
  if new.data ? 'name' and jsonb_typeof(new.data -> 'name') = 'string' then
    n := left(public.clean_name(new.data ->> 'name'), 80);
    if public.bad_name(n) and not new.demo and not public.is_admin()
       and (tg_op = 'INSERT' or public.clean_name(old.data ->> 'name') is distinct from n) then
      raise exception 'Navnet kan ikke brukes. Velg navnet ditt, uten «Freelio», «Admin» eller tegn fra flere alfabeter.' using errcode = 'P0001';
    end if;
    new.data := jsonb_set(new.data, '{name}', to_jsonb(n));
  end if;
  return new;
end $$;
drop trigger if exists freelancers_navn on public.freelancers;
create trigger freelancers_navn before insert or update of data on public.freelancers
  for each row execute function public.guard_freelancer_name();

-- ---------- leveranser: størrelse og filtyper ----------
-- Nettsiden laster opp originaler i biter på 45 MB (js/media.js), så ingen fil skal være større enn 50 MB.
-- Bare bilder og video (og bitene, som er application/octet-stream). Stopper HTML, skript og programfiler.
update storage.buckets
  set file_size_limit = 52428800,
      allowed_mime_types = array['image/*', 'video/*', 'application/octet-stream']
  where id = 'deliveries';

-- ---------- fartsgrense for «Hent fra portefølje» ----------
-- Funksjonen supabase/functions/hent-portefolje spør her før den henter noe.
create table if not exists public.fetch_log (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('side', 'bilde')),
  created_at timestamptz not null default now()
);
create index if not exists fetch_log_user_idx on public.fetch_log (user_id, kind, created_at);
alter table public.fetch_log enable row level security;
revoke all on public.fetch_log from anon, authenticated;

create or replace function public.portfolio_fetch_allowed(p_kind text default 'side')
returns boolean language plpgsql security definer set search_path = public as $$
declare
  k text := case when p_kind = 'bilde' then 'bilde' else 'side' end;
  n integer;
begin
  if auth.uid() is null then
    return false;
  end if;
  delete from public.fetch_log where user_id = auth.uid() and created_at < now() - interval '1 day';
  select count(*) into n from public.fetch_log
    where user_id = auth.uid() and kind = k and created_at > now() - interval '1 hour';
  if n >= (case when k = 'bilde' then 300 else 30 end) then
    return false;
  end if;
  insert into public.fetch_log (user_id, kind) values (auth.uid(), k);
  return true;
end $$;
revoke all on function public.portfolio_fetch_allowed(text) from public, anon;
grant execute on function public.portfolio_fetch_allowed(text) to authenticated;
