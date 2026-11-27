-- ============================================================
-- Herding etter Security Advisor (november 2026)
-- Kjør i Supabase: SQL Editor -> New query -> lim inn -> Run. Kan kjøres flere ganger.
--
-- 1. Fast search_path på funksjonene som manglet det (ingen kan lure dem til å bruke andre tabeller).
-- 2. Triggerfunksjoner kan ikke kalles direkte av noen. Triggerne virker som før,
--    fordi Postgres ikke sjekker EXECUTE når en trigger fyrer.
-- 3. Hjelpefunksjoner med SECURITY DEFINER kan bare kalles av innloggede.
--    Unntak: funksjoner som tilgangsregler for uinnloggede bruker, og job_posters()
--    (forsiden viser hvem som har lagt ut et oppdrag, også uten innlogging).
-- ============================================================

-- 1. Fast search_path
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and p.proname in ('admin_why', 'now_text', 'order_date', 'own_media')
      and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c ilike 'search_path=%')
  loop
    execute format('alter function %s set search_path = public', r.sig);
  end loop;
end $$;

-- 2. Triggerfunksjoner: ingen skal kalle dem direkte
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef and p.prorettype = 'trigger'::regtype
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', r.sig);
  end loop;
end $$;

-- 3. SECURITY DEFINER-hjelpere: bare innloggede (de som hadde tilgang fra før, beholder den)
do $$
declare r record;
begin
  for r in
    select p.oid, p.oid::regprocedure as sig, has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_x
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef and p.prokind = 'f'
      and p.prorettype <> 'trigger'::regtype
      and p.proname not in ('job_posters')
      and has_function_privilege('anon', p.oid, 'EXECUTE')
      and not exists (
        select 1 from pg_policies pp
        where (coalesce(pp.qual, '') || coalesce(pp.with_check, '')) ilike '%' || p.proname || '(%'
          and pp.roles && array['anon', 'public']::name[]
      )
  loop
    execute format('revoke execute on function %s from public, anon', r.sig);
    if r.auth_x then execute format('grant execute on function %s to authenticated', r.sig); end if;
    execute format('grant execute on function %s to service_role', r.sig);
  end loop;
end $$;

-- Sjekk: skal gi bare job_posters (og eventuelle funksjoner som regler for uinnloggede trenger)
select p.oid::regprocedure as kan_kalles_uten_innlogging
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.prosecdef and has_function_privilege('anon', p.oid, 'EXECUTE');
