-- ============================================================
-- Push-varsel til admin når noen melder en feil
-- Krever database/push.sql, database/admin.sql og database/feil.sql. Legg inn den nye versjonen av
-- funksjonen «varsle» først (supabase/functions/varsle/index.ts). Kan kjøres flere ganger.
-- ============================================================

-- Feilmeldinger har tall som id, så loggen over sendte varsler må kunne lagre det også
alter table public.push_log alter column ref type text using ref::text;

drop trigger if exists bug_reports_push on public.bug_reports;
create trigger bug_reports_push after insert on public.bug_reports
  for each row execute function public.push_notify('bug');
