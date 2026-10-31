-- Freelio: database for Supabase.
-- Lim inn hele filen i Supabase: SQL Editor -> New query -> Run.
-- Skriptet kan kjøres flere ganger. Det sletter ikke data som finnes.

create extension if not exists pgcrypto;

-- ============================================================
-- Tabeller
-- ============================================================

-- Én rad per bruker. Lages automatisk når noen oppretter konto.
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null default '',
  created_at timestamptz not null default now()
);

-- Frilanserprofiler. Demo-frilansere har ingen bruker (user_id er tom).
-- Ekte frilansere har id lik bruker-id-en sin.
create table if not exists public.freelancers (
  id text primary key,
  user_id uuid unique references public.profiles (id) on delete cascade,
  demo boolean not null default false,
  published boolean not null default true,
  data jsonb not null,
  created_at timestamptz not null default now()
);

-- Oppdrag som kunder legger ut
create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles (id) on delete cascade,
  demo boolean not null default false,
  status text not null default 'open' check (status in ('open', 'booked', 'closed')),
  data jsonb not null,
  created_at timestamptz not null default now()
);

-- Tilbud fra frilansere på oppdrag
create table if not exists public.offers (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs (id) on delete cascade,
  freelancer_id text not null references public.freelancers (id) on delete cascade,
  price integer not null check (price > 0),
  msg text not null default '',
  visible_at timestamptz not null default now(),
  seen boolean not null default false,
  created_at timestamptz not null default now(),
  unique (job_id, freelancer_id)
);

-- Bestillinger med trygg betaling
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null,
  freelancer_id text not null references public.freelancers (id) on delete cascade,
  job_id uuid references public.jobs (id) on delete set null,
  status text not null default 'paid' check (status in ('paid', 'delivered', 'approved', 'dispute', 'cancelled')),
  title text not null,
  price integer not null check (price > 0),
  reviewed boolean not null default false,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Meldinger mellom kunde og frilanser
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null,
  freelancer_id text not null references public.freelancers (id) on delete cascade,
  sender text not null check (sender in ('customer', 'freelancer', 'system')),
  text text not null check (char_length(text) between 1 and 4000),
  created_at timestamptz not null default now()
);

-- Omtaler. Bare kunden på en godkjent bestilling kan skrive én omtale.
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders (id) on delete cascade,
  author_id uuid not null,
  freelancer_id text not null references public.freelancers (id) on delete cascade,
  author_name text not null default '',
  stars integer not null check (stars between 1 and 5),
  text text not null default '',
  job_label text not null default '',
  created_at timestamptz not null default now()
);

-- Lagrede frilansere
create table if not exists public.saved (
  user_id uuid not null references public.profiles (id) on delete cascade,
  freelancer_id text not null references public.freelancers (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, freelancer_id)
);

create index if not exists orders_customer_idx on public.orders (customer_id);
create index if not exists orders_freelancer_idx on public.orders (freelancer_id);
create index if not exists messages_customer_idx on public.messages (customer_id);
create index if not exists messages_freelancer_idx on public.messages (freelancer_id);
create index if not exists offers_job_idx on public.offers (job_id);
create index if not exists jobs_owner_idx on public.jobs (owner_id);

-- ============================================================
-- Funksjoner
-- ============================================================

-- Lager profil når en ny bruker registrerer seg
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(nullif(new.raw_user_meta_data ->> 'name', ''), split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Frilanser-id-ene som tilhører innlogget bruker
create or replace function public.my_freelancer_ids()
returns setof text language sql stable security definer set search_path = public as $$
  select id from public.freelancers where user_id = auth.uid()
$$;

create or replace function public.is_demo_freelancer(fid text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select demo from public.freelancers where id = fid), false)
$$;

create or replace function public.owns_job(jid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.jobs where id = jid and owner_id = auth.uid())
$$;

-- Samtaler, bestillinger og omtaler blir stående når en kunde sletter kontoen sin.
-- Frilanseren ser dem fortsatt, med navnet «Slettet bruker».
alter table public.orders drop constraint if exists orders_customer_id_fkey;
alter table public.messages drop constraint if exists messages_customer_id_fkey;
alter table public.reviews drop constraint if exists reviews_author_id_fkey;

-- Lar en bruker slette sin egen konto og alt som hører til den
create or replace function public.delete_my_account()
returns void language sql security definer set search_path = public as $$
  update public.reviews set author_name = 'Tidligere kunde' where author_id = auth.uid();
  delete from auth.users where id = auth.uid();
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- ============================================================
-- Tilgangsregler (Row Level Security)
-- ============================================================

alter table public.profiles enable row level security;
alter table public.freelancers enable row level security;
alter table public.jobs enable row level security;
alter table public.offers enable row level security;
alter table public.orders enable row level security;
alter table public.messages enable row level security;
alter table public.reviews enable row level security;
alter table public.saved enable row level security;

-- Profiler: navn kan leses av innloggede, bare egen profil kan endres
drop policy if exists "profiler les" on public.profiles;
create policy "profiler les" on public.profiles for select to authenticated using (true);
drop policy if exists "profiler endre egen" on public.profiles;
create policy "profiler endre egen" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Frilansere: publiserte er offentlige, bare eier kan endre sin egen
drop policy if exists "frilansere les" on public.freelancers;
create policy "frilansere les" on public.freelancers for select using (published or user_id = auth.uid());
drop policy if exists "frilansere lag egen" on public.freelancers;
create policy "frilansere lag egen" on public.freelancers for insert to authenticated
  with check (user_id = auth.uid() and id = auth.uid()::text and not demo);
drop policy if exists "frilansere endre egen" on public.freelancers;
create policy "frilansere endre egen" on public.freelancers for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid() and id = auth.uid()::text and not demo);
drop policy if exists "frilansere slett egen" on public.freelancers;
create policy "frilansere slett egen" on public.freelancers for delete to authenticated using (user_id = auth.uid());

-- Oppdrag: alle kan lese, bare eier kan lage, endre og slette
drop policy if exists "oppdrag les" on public.jobs;
create policy "oppdrag les" on public.jobs for select using (true);
drop policy if exists "oppdrag lag" on public.jobs;
create policy "oppdrag lag" on public.jobs for insert to authenticated with check (owner_id = auth.uid() and not demo);
drop policy if exists "oppdrag endre" on public.jobs;
create policy "oppdrag endre" on public.jobs for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid() and not demo);
drop policy if exists "oppdrag slett" on public.jobs;
create policy "oppdrag slett" on public.jobs for delete to authenticated using (owner_id = auth.uid());

-- Tilbud: synlige for eieren av oppdraget og frilanseren som sendte dem
drop policy if exists "tilbud les" on public.offers;
create policy "tilbud les" on public.offers for select to authenticated
  using (public.owns_job(job_id) or freelancer_id in (select public.my_freelancer_ids()));
drop policy if exists "tilbud lag" on public.offers;
create policy "tilbud lag" on public.offers for insert to authenticated
  with check (
    (freelancer_id in (select public.my_freelancer_ids()) and not public.owns_job(job_id))
    or (public.is_demo_freelancer(freelancer_id) and public.owns_job(job_id))
  );
drop policy if exists "tilbud endre" on public.offers;
create policy "tilbud endre" on public.offers for update to authenticated
  using (public.owns_job(job_id) or freelancer_id in (select public.my_freelancer_ids()));
drop policy if exists "tilbud slett" on public.offers;
create policy "tilbud slett" on public.offers for delete to authenticated
  using (freelancer_id in (select public.my_freelancer_ids()) or public.owns_job(job_id));

-- Bestillinger: bare kunden og frilanseren ser og endrer dem
drop policy if exists "bestillinger les" on public.orders;
create policy "bestillinger les" on public.orders for select to authenticated
  using (customer_id = auth.uid() or freelancer_id in (select public.my_freelancer_ids()));
drop policy if exists "bestillinger lag" on public.orders;
create policy "bestillinger lag" on public.orders for insert to authenticated
  with check (customer_id = auth.uid() and status = 'paid' and freelancer_id not in (select public.my_freelancer_ids()));
drop policy if exists "bestillinger endre" on public.orders;
create policy "bestillinger endre" on public.orders for update to authenticated
  using (customer_id = auth.uid() or freelancer_id in (select public.my_freelancer_ids()))
  with check (customer_id = auth.uid() or freelancer_id in (select public.my_freelancer_ids()));

-- Meldinger: bare de to i samtalen
drop policy if exists "meldinger les" on public.messages;
create policy "meldinger les" on public.messages for select to authenticated
  using (customer_id = auth.uid() or freelancer_id in (select public.my_freelancer_ids()));
drop policy if exists "meldinger send" on public.messages;
create policy "meldinger send" on public.messages for insert to authenticated
  with check (
    (customer_id = auth.uid() and (sender in ('customer', 'system') or (sender = 'freelancer' and public.is_demo_freelancer(freelancer_id))))
    or (freelancer_id in (select public.my_freelancer_ids()) and sender in ('freelancer', 'system'))
  );

-- Omtaler: alle kan lese, bare kunden på en godkjent bestilling kan skrive
drop policy if exists "omtaler les" on public.reviews;
create policy "omtaler les" on public.reviews for select using (true);
drop policy if exists "omtaler skriv" on public.reviews;
create policy "omtaler skriv" on public.reviews for insert to authenticated
  with check (
    author_id = auth.uid()
    and exists (select 1 from public.orders o where o.id = order_id and o.customer_id = auth.uid() and o.status = 'approved' and o.freelancer_id = reviews.freelancer_id)
  );

-- Lagrede: bare egne
drop policy if exists "lagrede egne" on public.saved;
create policy "lagrede egne" on public.saved for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Tilgang for nettsiden (reglene over bestemmer hvilke rader)
grant usage on schema public to anon, authenticated;
grant select on public.freelancers, public.jobs, public.reviews to anon;
grant select, insert, update, delete on all tables in schema public to authenticated;

-- ============================================================
-- Fillagring for leveranser
-- Sti: <bestillings-id>/<fil-id>/original | preview | thumb
-- Kunden kan bare hente originalen når bestillingen er godkjent.
-- ============================================================

insert into storage.buckets (id, name, public)
values ('deliveries', 'deliveries', false)
on conflict (id) do nothing;

create or replace function public.can_read_delivery(path text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.orders o
    where o.id::text = split_part(path, '/', 1)
      and (
        o.freelancer_id in (select public.my_freelancer_ids())
        or (o.customer_id = auth.uid() and (split_part(path, '/', 3) <> 'original' or o.status = 'approved'))
      )
  )
$$;

create or replace function public.can_write_delivery(path text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.orders o
    where o.id::text = split_part(path, '/', 1)
      and o.status in ('paid', 'dispute')
      and (
        o.freelancer_id in (select public.my_freelancer_ids())
        or (o.customer_id = auth.uid() and public.is_demo_freelancer(o.freelancer_id))
      )
  )
$$;

drop policy if exists "leveranser les" on storage.objects;
create policy "leveranser les" on storage.objects for select to authenticated
  using (bucket_id = 'deliveries' and public.can_read_delivery(name));
drop policy if exists "leveranser last opp" on storage.objects;
create policy "leveranser last opp" on storage.objects for insert to authenticated
  with check (bucket_id = 'deliveries' and public.can_write_delivery(name));
drop policy if exists "leveranser slett" on storage.objects;
create policy "leveranser slett" on storage.objects for delete to authenticated
  using (bucket_id = 'deliveries' and public.can_write_delivery(name));

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

-- ============================================================
-- Demo-data: 10 frilansere og 9 oppdrag, så siden ikke er tom ved lansering.
-- Kan kjøres flere ganger. Slett demo-radene når dere har nok ekte frilansere:
--   delete from public.jobs where demo; delete from public.freelancers where demo;

insert into public.freelancers (id, demo, published, data) values ('ingrid', true, true, '{"name":"Ingrid Solberg","ini":"IS","col":"#3D5A80","role":"Bryllupsfotograf","cat":"bryllup","niches":["bryllup","portrett"],"tags":["Foto","Bryllup","Portrett"],"area":"Sandvika","km":2,"mx":56,"my":40,"rating":4.9,"reviews":64,"jobs":92,"from":6500,"unit":"","respH":2,"resp":"2 timer","delD":14,"years":8,"free":true,"verified":true,"cap":"Bryllup på Holmen, juni","pal":0,"joined":"2023","bio":"Jeg fotograferer bryllup og portretter med naturlig lys. Rolig stil og lite oppstilling. Jeg reiser i hele Oslo og Viken uten tillegg.","pk":[["Vielse",6500,"2 timer. Vielse og gruppebilder. 80 redigerte bilder."],["Halv dag",9500,"5 timer fra forberedelser til middag. 250 redigerte bilder."],["Hel dag",15000,"10 timer, hele dagen. 500 redigerte bilder og galleri på nett."]],"sum":"Kundene trekker frem rolig væremåte, naturlig lys og rask levering. To nevner at hun ble lenger enn avtalt uten ekstra kostnad.","rv":[["Kari og Even",5,"Bryllup, halv dag · august","Hun fikk oss til å slappe av foran kamera. Bildene kom etter 10 dager."],["Marte L.",5,"Portrett · mai","Tydelig avtale på forhånd og akkurat det vi ba om."],["Jon P.",4,"Vielse · juni","Flotte bilder. Litt treg å svare i starten."]]}'::jsonb)
  on conflict (id) do update set data = excluded.data where public.freelancers.demo;
insert into public.freelancers (id, demo, published, data) values ('sofie', true, true, '{"name":"Sofie Nyhus","ini":"SN","col":"#7A4E3B","role":"Portrett- og familiefotograf","cat":"portrett","niches":["portrett","bryllup"],"tags":["Foto","Familie","Studio"],"area":"Stabekk","km":4,"mx":72,"my":30,"rating":4.8,"reviews":37,"jobs":51,"from":2500,"unit":"","respH":1,"resp":"1 time","delD":21,"years":5,"free":true,"verified":true,"cap":"Familieportrett i studio","pal":6,"joined":"2024","bio":"Varme farger og ekte øyeblikk. Jeg har eget studio på Stabekk og er vant til å fotografere barn.","pk":[["Portrett",2500,"1 time i studio. 15 redigerte bilder."],["Familie ute",3900,"1,5 time på stedet dere velger. 30 redigerte bilder."],["Bryllup, halv dag",8000,"5 timer. 200 redigerte bilder."]],"sum":"Kundene skriver at hun svarer raskt og er god med barn. Noen synes leveringstiden er lang i høysesong.","rv":[["Emilie B.",5,"Familieportrett · april","Ungene elsket henne. Nydelige bilder."],["Tobias og Lin",5,"Bryllup · september","Rask på chat og veldig fleksibel."],["Anne K.",4,"Portrett · mars","Fine bilder, men tok tre uker."]]}'::jsonb)
  on conflict (id) do update set data = excluded.data where public.freelancers.demo;
insert into public.freelancers (id, demo, published, data) values ('maja', true, true, '{"name":"Maja Strand","ini":"MS","col":"#4F6B3A","role":"Bryllupsfotograf og videograf","cat":"bryllup","niches":["bryllup","event"],"tags":["Foto","Video","Bryllupsfilm"],"area":"Oslo","km":14,"mx":88,"my":14,"rating":4.9,"reviews":88,"jobs":140,"from":9000,"unit":"","respH":24,"resp":"1 dag","delD":10,"years":11,"free":false,"verified":true,"cap":"Bryllup i Nordmarka","pal":3,"joined":"2022","bio":"Jeg leverer både foto og film fra samme dag. Mye erfaring med store bryllup og bedriftsarrangement.","pk":[["Halv dag foto",9000,"5 timer. 250 bilder."],["Foto og film",18000,"8 timer. 400 bilder og 3 minutters film."],["Hel dag",22000,"12 timer. Foto, film og drone."]],"sum":"Svært erfaren og leverer raskt. Flere nevner at hun er vanskelig å få tak i på kort varsel.","rv":[["Ida og Sander",5,"Bryllup · juli","Filmen fikk alle til å gråte. Verdt hver krone."],["Vestby Bygg AS",5,"Event · mai","Profesjonell fra start til slutt."]]}'::jsonb)
  on conflict (id) do update set data = excluded.data where public.freelancers.demo;
insert into public.freelancers (id, demo, published, data) values ('henrik', true, true, '{"name":"Henrik Aas","ini":"HA","col":"#5B5F97","role":"Event- og bedriftsfotograf","cat":"event","niches":["event","portrett","produkt"],"tags":["Foto","Konferanse","Ansattbilder"],"area":"Bekkestua","km":5,"mx":34,"my":24,"rating":4.6,"reviews":21,"jobs":30,"from":3000,"unit":"","respH":3,"resp":"3 timer","delD":5,"years":3,"free":true,"verified":true,"cap":"Konferanse på Fornebu","pal":8,"joined":"2024","bio":"Eventfoto og ansattbilder for bedrifter. Leverer innen fem dager.","pk":[["Ansattbilder",3000,"Opptil 10 personer. Bakgrunn medbrakt."],["Event 3 timer",5500,"150 redigerte bilder."],["Event hel dag",9500,"8 timer. 350 redigerte bilder."]],"sum":"Rask levering og ryddig. Noen ønsker mer variasjon i bildene.","rv":[["Nordvik Eiendom",5,"Ansattbilder · juni","Effektiv og hyggelig."],["Lars M.",4,"Event · april","Bra bilder, litt like."]]}'::jsonb)
  on conflict (id) do update set data = excluded.data where public.freelancers.demo;
insert into public.freelancers (id, demo, published, data) values ('jonas', true, true, '{"name":"Jonas Berg","ini":"JB","col":"#2F3A40","role":"Videograf og dronepilot","cat":"reklamefilm","niches":["reklamefilm","drone","some"],"tags":["Video","Drone","Reklame"],"area":"Asker","km":6,"mx":22,"my":62,"rating":4.8,"reviews":29,"jobs":47,"from":4500,"unit":"","respH":2,"resp":"2 timer","delD":10,"years":6,"free":true,"verified":true,"cap":"Reklamefilm for padelhall","pal":9,"joined":"2023","bio":"Reklamefilm og dronefilm for bedrifter. Jeg leverer i 16:9 og 9:16. Godkjent dronepilot (A2).","pk":[["Dronefilm",4500,"1 time flyging. 60 sekunder ferdig film."],["SoMe-pakke",7000,"3 korte filmer til sosiale medier."],["Reklamefilm",12000,"30 sekunder. Manus, opptak og klipp."]],"sum":"Kundene roser bildeutsnitt og fart i klippen. Én nevner at musikkvalg tok flere runder.","rv":[["Sandvika Padel",5,"Reklamefilm · mai","Filmen ga oss flere bookinger samme uke."],["Fjordhotellet",5,"Dronefilm · juni","Fantastiske bilder fra lufta."]]}'::jsonb)
  on conflict (id) do update set data = excluded.data where public.freelancers.demo;
insert into public.freelancers (id, demo, published, data) values ('oskar', true, true, '{"name":"Oskar Dahl","ini":"OD","col":"#6B4F2A","role":"Eiendomsfotograf og drone","cat":"eiendom","niches":["eiendom","drone"],"tags":["Foto","Bolig","Luftfoto"],"area":"Billingstad","km":7,"mx":44,"my":58,"rating":4.7,"reviews":112,"jobs":310,"from":2900,"unit":"","respH":2,"resp":"2 timer","delD":2,"years":6,"free":true,"verified":true,"cap":"Enebolig på Høvik","pal":7,"joined":"2022","bio":"Bilder til boligannonser, levert innen 48 timer. Dronebilder og plantegning kan legges til.","pk":[["Leilighet",2900,"Opptil 20 bilder. Levert innen 48 timer."],["Enebolig",4200,"30 bilder og 5 dronebilder."],["Bolig med film",7500,"30 bilder, dronebilder og 60 sekunders film."]],"sum":"Meglerne roser rask levering og jevn kvalitet. Noen ønsker flere kveldsbilder.","rv":[["Megler Bærum",5,"Enebolig · september","Alltid levert til avtalt tid."],["Hanne T.",4,"Leilighet · mai","Fine bilder, men mørkt bad."]]}'::jsonb)
  on conflict (id) do update set data = excluded.data where public.freelancers.demo;
insert into public.freelancers (id, demo, published, data) values ('line', true, true, '{"name":"Line Myhre","ini":"LM","col":"#2E6E6A","role":"Produkt- og matfotograf","cat":"produkt","niches":["produkt","some"],"tags":["Foto","Nettbutikk","Mat"],"area":"Lysaker","km":7,"mx":76,"my":66,"rating":4.9,"reviews":26,"jobs":60,"from":3500,"unit":"","respH":3,"resp":"3 timer","delD":5,"years":9,"free":true,"verified":true,"cap":"Smykker til nettbutikk","pal":5,"joined":"2023","bio":"Produktbilder til nettbutikk og meny. Eget studio med hvit bakgrunn og lysoppsett.","pk":[["10 produkter",3500,"Hvit bakgrunn. To vinkler per produkt."],["30 produkter",8500,"Hvit bakgrunn og 5 bilder i bruk."],["Meny og mat",6000,"Inntil 15 retter, tatt hos dere."]],"sum":"Kundene skriver at bildene øker salget og at hun gir gode råd om oppsett.","rv":[["Lys Smykker",5,"Produktbilder · august","Salget økte merkbart etter nye bilder."]]}'::jsonb)
  on conflict (id) do update set data = excluded.data where public.freelancers.demo;
insert into public.freelancers (id, demo, published, data) values ('adrian', true, true, '{"name":"Adrian Kvam","ini":"AK","col":"#8A3B5C","role":"Bryllupsvideograf","cat":"bryllup","niches":["bryllup","event"],"tags":["Video","Bryllupsfilm","Taler"],"area":"Asker","km":6,"mx":30,"my":44,"rating":5,"reviews":19,"jobs":33,"from":12000,"unit":"","respH":4,"resp":"4 timer","delD":30,"years":5,"free":true,"verified":true,"cap":"Bryllupsfilm på Støtvig","pal":4,"joined":"2024","bio":"Bryllupsfilm med fokus på ekte øyeblikk og god lyd fra taler og løfter.","pk":[["Vielse",12000,"3 minutters film fra vielsen."],["Halv dag",18000,"5 minutters film og hele talene."],["Hel dag",26000,"8 minutters film, taler og en kort film til sosiale medier."]],"sum":"Alle omtaler har fem stjerner. Kundene nevner lyden fra talene og at filmen føles personlig.","rv":[["Nora og Even",5,"Bryllup · august","Vi ser filmen hver måned."]]}'::jsonb)
  on conflict (id) do update set data = excluded.data where public.freelancers.demo;
insert into public.freelancers (id, demo, published, data) values ('thea', true, true, '{"name":"Thea Lund","ini":"TL","col":"#9A5B2E","role":"Innholdsprodusent for sosiale medier","cat":"some","niches":["some","reklamefilm","produkt"],"tags":["Video","Reels","TikTok"],"area":"Sandvika","km":1,"mx":52,"my":70,"rating":4.8,"reviews":54,"jobs":140,"from":3000,"unit":"","respH":1,"resp":"1 time","delD":4,"years":4,"free":true,"verified":true,"cap":"Reels for kafé","pal":11,"joined":"2023","bio":"Korte filmer i 9:16 for Instagram og TikTok. Jeg planlegger, filmer og klipper samme uke.","pk":[["3 korte filmer",3000,"Opptil 20 sekunder hver. Musikk og tekst."],["Månedspakke",9000,"10 filmer i måneden og en plan for innhold."]],"sum":"Kundene liker at hun kommer med idéer og leverer raskt.","rv":[["Kafé Torget",5,"Reels · hele våren","Følgerne økte jevnt hver måned."]]}'::jsonb)
  on conflict (id) do update set data = excluded.data where public.freelancers.demo;
insert into public.freelancers (id, demo, published, data) values ('mats', true, true, '{"name":"Mats Berge","ini":"MB","col":"#35507A","role":"Konsert- og eventfotograf","cat":"event","niches":["event","portrett"],"tags":["Foto","Konsert","Fest"],"area":"Oslo","km":12,"mx":82,"my":50,"rating":4.7,"reviews":15,"jobs":22,"from":2500,"unit":"","respH":5,"resp":"5 timer","delD":3,"years":4,"free":true,"verified":true,"cap":"Konsert på Rockefeller","pal":1,"joined":"2024","bio":"Konsert, utdrikningslag og 50-årslag. Gode bilder i lite lys er min styrke.","pk":[["2 timer",2500,"80 redigerte bilder."],["Kveld 4 timer",4500,"200 redigerte bilder."]],"sum":"Kundene liker at han er diskré og får gode bilder i mørke lokaler.","rv":[["Lise R.",5,"50-årslag · mars","Fanget stemningen perfekt."]]}'::jsonb)
  on conflict (id) do update set data = excluded.data where public.freelancers.demo;

insert into public.jobs (id, demo, status, data) values (md5('freelio-j101')::uuid, true, 'open', '{"cat":"event","title":"Fotograf til 50-årslag","desc":"Middag for 40 gjester i selskapslokale på Høvik. Ønsker bilder av gjester, taler og stemning. Ca. 3 timer.","budget":6000,"date":"21.11.2026","area":"Høvik","km":4,"posted":"i dag","by":"Tone R.","offers":3,"delivery":"100 redigerte bilder"}'::jsonb)
  on conflict (id) do update set data = excluded.data where public.jobs.demo;
insert into public.jobs (id, demo, status, data) values (md5('freelio-j102')::uuid, true, 'open', '{"cat":"some","title":"Korte filmer til Instagram for bakeri","desc":"Tre korte filmer fra bakingen tidlig om morgenen. Format 9:16. Vi har musikk selv.","budget":8000,"date":"Fleksibel","area":"Sandvika","km":1,"posted":"i går","by":"Bakeriet Torget","offers":2,"delivery":"3 filmer à 20 sekunder"}'::jsonb)
  on conflict (id) do update set data = excluded.data where public.jobs.demo;
insert into public.jobs (id, demo, status, data) values (md5('freelio-j103')::uuid, true, 'open', '{"cat":"bryllup","title":"Bryllupsfotograf i juni","desc":"Vielse i Haslum kirke og middag på hotell i Sandvika. Rundt 70 gjester. Ønsker naturlige bilder.","budget":14000,"date":"13.06.2027","area":"Bærum","km":3,"posted":"for 2 dager siden","by":"Ali og Sara","offers":5,"delivery":"300 redigerte bilder"}'::jsonb)
  on conflict (id) do update set data = excluded.data where public.jobs.demo;
insert into public.jobs (id, demo, status, data) values (md5('freelio-j104')::uuid, true, 'open', '{"cat":"eiendom","title":"Boligbilder til salg av leilighet","desc":"3-roms leilighet på 74 m². Trenger bilder før visning neste uke. Gjerne dronebilde av utsikten.","budget":4000,"date":"Innen 15.11","area":"Asker","km":6,"posted":"i dag","by":"Martin S.","offers":1,"delivery":"20 bilder og 1 dronebilde"}'::jsonb)
  on conflict (id) do update set data = excluded.data where public.jobs.demo;
insert into public.jobs (id, demo, status, data) values (md5('freelio-j105')::uuid, true, 'open', '{"cat":"portrett","title":"Nye profilbilder til 12 ansatte","desc":"Enkle portretter på kontoret med lys bakgrunn. Skal brukes på nettside og LinkedIn.","budget":5000,"date":"Uke 48","area":"Lysaker","km":7,"posted":"i dag","by":"Regnskap1 AS","offers":4,"delivery":"2 bilder per person"}'::jsonb)
  on conflict (id) do update set data = excluded.data where public.jobs.demo;
insert into public.jobs (id, demo, status, data) values (md5('freelio-j106')::uuid, true, 'open', '{"cat":"reklamefilm","title":"Reklamefilm for treningssenter","desc":"Kort film som viser senteret og stemningen på en gruppetime. Skal brukes i annonser.","budget":15000,"date":"Desember","area":"Bekkestua","km":5,"posted":"for 3 dager siden","by":"Puls Bekkestua","offers":2,"delivery":"30 sekunder i 16:9 og 9:16"}'::jsonb)
  on conflict (id) do update set data = excluded.data where public.jobs.demo;
insert into public.jobs (id, demo, status, data) values (md5('freelio-j107')::uuid, true, 'open', '{"cat":"drone","title":"Dronefilm av hytte og tomt","desc":"Hytte ved sjøen som skal leies ut. Ønsker luftfoto og en kort film i godt vær.","budget":5000,"date":"Fleksibel","area":"Hurum","km":22,"posted":"i går","by":"Jens P.","offers":3,"delivery":"10 bilder og 45 sekunders film"}'::jsonb)
  on conflict (id) do update set data = excluded.data where public.jobs.demo;
insert into public.jobs (id, demo, status, data) values (md5('freelio-j108')::uuid, true, 'open', '{"cat":"produkt","title":"Produktbilder til nettbutikk","desc":"40 produkter, smykker. Hvit bakgrunn og noen bilder i bruk.","budget":5000,"date":"Innen 01.12","area":"Oslo","km":12,"posted":"i dag","by":"Lys Smykker","offers":1,"delivery":"60 bilder"}'::jsonb)
  on conflict (id) do update set data = excluded.data where public.jobs.demo;
insert into public.jobs (id, demo, status, data) values (md5('freelio-j109')::uuid, true, 'open', '{"cat":"bryllup","title":"Videograf til vielse","desc":"Liten vielse i tingretten med 15 gjester og middag etterpå. Ønsker en kort film.","budget":9000,"date":"05.12.2026","area":"Sandvika","km":1,"posted":"for 4 dager siden","by":"Hanna og Ole","offers":2,"delivery":"3 minutters film"}'::jsonb)
  on conflict (id) do update set data = excluded.data where public.jobs.demo;
