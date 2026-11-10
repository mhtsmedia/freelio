-- ============================================================
-- Sjekk at sikkerhetsreglene er på plass i databasen
-- Endrer INGENTING, bare leser. Kjør i Supabase: SQL Editor -> New query -> lim inn -> Run.
-- Svaret er én rad per sjekk. Alt som ikke er «OK», står øverst.
--   MANGLER = regelen finnes ikke. Kjør database/oppdatering.sql (eller filen som står i detalj).
--   ÅPEN    = noe som skal være stengt, er åpent.
--   AV      = Row Level Security er slått av for tabellen.
-- ============================================================

with
forventet_rls(tabell) as (values
  ('public.profiles'), ('public.freelancers'), ('public.jobs'), ('public.offers'), ('public.orders'),
  ('public.messages'), ('public.reviews'), ('public.saved'), ('public.posts'), ('public.saved_folders'),
  ('public.post_likes'), ('public.post_comments'), ('public.push_subscriptions'), ('public.push_log'),
  ('public.admins'), ('public.admin_log'), ('public.bug_reports')
),
rls as (
  select 'Row Level Security'::text as omraade, f.tabell::text as sjekk,
    case
      when to_regclass(f.tabell) is null then 'MANGLER'
      when (select c.relrowsecurity from pg_class c where c.oid = to_regclass(f.tabell)) then 'OK'
      else 'AV'
    end::text as status,
    ''::text as detalj
  from forventet_rls f
),

forventet_pol(tabell, navn) as (values
  ('profiles', 'profiler les'), ('profiles', 'profiler endre egen'),
  ('freelancers', 'frilansere les'), ('freelancers', 'frilansere lag egen'), ('freelancers', 'frilansere endre egen'), ('freelancers', 'frilansere slett egen'),
  ('jobs', 'oppdrag les'), ('jobs', 'oppdrag lag'), ('jobs', 'oppdrag endre'), ('jobs', 'oppdrag slett'),
  ('offers', 'tilbud les'), ('offers', 'tilbud lag'), ('offers', 'tilbud endre'), ('offers', 'tilbud slett'),
  ('orders', 'bestillinger les'), ('orders', 'bestillinger lag'), ('orders', 'bestillinger endre'),
  ('messages', 'meldinger les'), ('messages', 'meldinger send'),
  ('reviews', 'omtaler les'), ('reviews', 'omtaler skriv'),
  ('saved', 'lagrede egne'), ('saved_folders', 'mapper egne'),
  ('posts', 'innlegg les'), ('posts', 'innlegg lag'), ('posts', 'innlegg slett'),
  ('post_likes', 'liker les'), ('post_likes', 'liker lag'), ('post_likes', 'liker fjern'),
  ('post_comments', 'kommentarer les'), ('post_comments', 'kommentarer skriv'), ('post_comments', 'kommentarer slett'),
  ('push_subscriptions', 'push les'), ('push_subscriptions', 'push slett'),
  ('bug_reports', 'feil send'), ('bug_reports', 'feil les admin'), ('bug_reports', 'feil endre admin')
),
pol as (
  select 'Tilgangsregel', 'public.' || f.tabell || ': ' || f.navn,
    case when exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = f.tabell and p.policyname = f.navn)
      then 'OK' else 'MANGLER' end,
    ''
  from forventet_pol f
),

forventet_lagring(navn) as (values
  ('profilbilder last opp'), ('profilbilder endre'), ('profilbilder slett'),
  ('leveranser les'), ('leveranser last opp'), ('leveranser slett'),
  ('vedlegg les'), ('vedlegg last opp'), ('vedlegg slett')
),
lagring_pol as (
  select 'Tilgangsregel (filer)', 'storage.objects: ' || f.navn,
    case when exists (select 1 from pg_policies p where p.schemaname = 'storage' and p.tablename = 'objects' and p.policyname = f.navn)
      then 'OK' else 'MANGLER' end,
    ''
  from forventet_lagring f
),

-- De strammere versjonene fra sikkerhet.sql erstatter eldre regler med samme navn. Sjekk innholdet, ikke bare navnet.
strammere as (
  select 'Strammere regel', 'profiler les: bare deg selv og dine kunder',
    case when exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'profiler les' and qual like '%is_my_customer%')
      then 'OK' else 'MANGLER' end,
    'Den gamle regelen lar alle innloggede lese alle profiler. Kjør database/sikkerhet.sql.'
  union all
  select 'Strammere regel', 'meldinger send: frilansere bare til egne kunder',
    case when exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'messages' and policyname = 'meldinger send' and with_check like '%can_message%')
      then 'OK' else 'MANGLER' end,
    'Kjør database/sikkerhet.sql.'
  union all
  select 'Strammere regel', 'profilbilder last opp: høyst 1000 filer',
    case when exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'profilbilder last opp' and with_check like '%my_file_count%')
      then 'OK' else 'MANGLER' end,
    'Kjør database/sikkerhet.sql.'
),

forventet_trg(tabell, navn) as (values
  ('auth.users', 'on_auth_user_created'),
  ('public.freelancers', 'freelancers_guard'),
  ('public.offers', 'offers_guard'), ('public.offers', 'offers_rate'),
  ('public.orders', 'orders_contract'), ('public.orders', 'orders_guard'), ('public.orders', 'orders_rate'),
  ('public.reviews', 'reviews_author'),
  ('public.messages', 'messages_rate_min'), ('public.messages', 'messages_rate_day'),
  ('public.jobs', 'jobs_rate'), ('public.posts', 'posts_rate'), ('public.saved', 'saved_rate'),
  ('public.saved_folders', 'saved_folders_rate'),
  ('public.post_comments', 'post_comments_author'), ('public.post_comments', 'post_comments_rate_min'), ('public.post_comments', 'post_comments_rate_day'),
  ('public.post_likes', 'post_likes_rate'),
  ('public.bug_reports', 'bug_reports_rate')
),
trg as (
  select 'Trigger (vakt eller fartsgrense)', f.tabell || ': ' || f.navn,
    case when exists (select 1 from pg_trigger t where t.tgrelid = to_regclass(f.tabell) and t.tgname = f.navn and not t.tgisinternal and t.tgenabled <> 'D')
      then 'OK' else 'MANGLER' end,
    ''
  from forventet_trg f
),

forventet_con(tabell, navn) as (values
  ('public.profiles', 'profiles_grenser'), ('public.freelancers', 'freelancers_grenser'),
  ('public.freelancers', 'freelancers_priser'), ('public.freelancers', 'freelancers_vilkar'),
  ('public.jobs', 'jobs_grenser'), ('public.offers', 'offers_grenser'), ('public.orders', 'orders_grenser'),
  ('public.reviews', 'reviews_grenser'), ('public.posts', 'posts_grenser'),
  ('public.messages', 'messages_lengde'), ('public.messages', 'messages_files'),
  ('public.saved_folders', 'saved_folders_grenser'), ('public.post_comments', 'post_comments_grenser')
),
con as (
  select 'Grense (lengde, pris, størrelse)', f.tabell || ': ' || f.navn,
    case when exists (select 1 from pg_constraint c where c.conrelid = to_regclass(f.tabell) and c.conname = f.navn)
      then 'OK' else 'MANGLER' end,
    ''
  from forventet_con f
),

-- Hva en uinnlogget besøkende (rollen anon) får gjøre
uinnlogget as (
  select 'Uinnlogget', 'Kan ikke lese brukerprofiler',
    case when to_regclass('public.profiles') is null then 'MANGLER'
         when has_table_privilege('anon', 'public.profiles', 'SELECT') then 'ÅPEN' else 'OK' end, ''
  union all
  select 'Uinnlogget', 'Ser ikke hvem som eier et oppdrag (jobs.owner_id)',
    case when to_regclass('public.jobs') is null then 'MANGLER'
         when has_column_privilege('anon', 'public.jobs', 'owner_id', 'SELECT') then 'ÅPEN' else 'OK' end, ''
  union all
  select 'Uinnlogget', 'Ser ikke hvem som skrev en omtale (reviews.author_id)',
    case when to_regclass('public.reviews') is null then 'MANGLER'
         when has_column_privilege('anon', 'public.reviews', 'author_id', 'SELECT') then 'ÅPEN' else 'OK' end, ''
  union all
  select 'Uinnlogget', 'Kan ikke lese meldinger',
    case when to_regclass('public.messages') is null then 'MANGLER'
         when has_table_privilege('anon', 'public.messages', 'SELECT') then 'ÅPEN' else 'OK' end, ''
  union all
  select 'Uinnlogget', 'Kan ikke lese bestillinger',
    case when to_regclass('public.orders') is null then 'MANGLER'
         when has_table_privilege('anon', 'public.orders', 'SELECT') then 'ÅPEN' else 'OK' end, ''
  union all
  select 'Uinnlogget', 'Kan ikke slette kontoer (delete_my_account)',
    case when to_regprocedure('public.delete_my_account()') is null then 'MANGLER'
         when has_function_privilege('anon', 'public.delete_my_account()', 'EXECUTE') then 'ÅPEN' else 'OK' end, ''
),

-- Admin-tabellene skal ingen nå fra nettsiden
admin as (
  select 'Admin', t || ': stengt for nettsiden',
    case when to_regclass(t) is null then 'MANGLER'
         when has_table_privilege('anon', t, 'SELECT') or has_table_privilege('authenticated', t, 'SELECT') then 'ÅPEN'
         else 'OK' end,
    case when to_regclass(t) is null then 'Kjør database/admin.sql (og push.sql for push_log).' else '' end
  from unnest(array['public.admins', 'public.admin_log', 'public.push_log']) as t
  union all
  select 'Admin', 'admin_delete_job: bare for innloggede (og sjekker admin selv)',
    case when to_regprocedure('public.admin_delete_job(uuid,text)') is null then 'MANGLER'
         when has_function_privilege('anon', 'public.admin_delete_job(uuid,text)', 'EXECUTE') then 'ÅPEN' else 'OK' end, ''
),

filer as (
  select 'Fillagring', 'profiles: offentlig, høyst 50 MB, faste filtyper',
    case when not exists (select 1 from storage.buckets where id = 'profiles') then 'MANGLER'
         when exists (select 1 from storage.buckets where id = 'profiles' and file_size_limit <= 52428800 and allowed_mime_types is not null) then 'OK'
         else 'ÅPEN' end,
    'ÅPEN betyr at størrelsesgrense eller filtyper mangler. Kjør database/bilder.sql.'
  union all
  select 'Fillagring', 'deliveries (leveranser): privat',
    case when not exists (select 1 from storage.buckets where id = 'deliveries') then 'MANGLER'
         when exists (select 1 from storage.buckets where id = 'deliveries' and not public) then 'OK' else 'ÅPEN' end, ''
  union all
  select 'Fillagring', 'vedlegg: privat, høyst 25 MB, ingen HTML eller SVG',
    case when not exists (select 1 from storage.buckets where id = 'vedlegg') then 'MANGLER'
         when exists (select 1 from storage.buckets where id = 'vedlegg' and not public and file_size_limit <= 26214400
                        and allowed_mime_types is not null
                        and not ('text/html' = any (allowed_mime_types)) and not ('image/svg+xml' = any (allowed_mime_types))) then 'OK'
         else 'ÅPEN' end, ''
),

alle as (
  select * from rls
  union all select * from pol
  union all select * from lagring_pol
  union all select * from strammere
  union all select * from trg
  union all select * from con
  union all select * from uinnlogget
  union all select * from admin
  union all select * from filer
)
select
  (select count(*) from alle where status <> 'OK') as problemer,
  omraade, sjekk, status,
  case when status = 'OK' then '' else detalj end as detalj
from alle
order by (status = 'OK'), omraade, sjekk;
