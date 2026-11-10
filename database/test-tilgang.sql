-- ============================================================
-- Test av tilgangsreglene med falske brukere
-- Kjør i Supabase: SQL Editor -> New query -> lim inn HELE filen -> Run.
--
-- Hva skjer:
--   1. Lager tre testbrukere: kunde A, frilanser B og en «nysgjerrig tester» C,
--      pluss et oppdrag, et tilbud, en bestilling og en melding mellom A og B.
--   2. Later som om C er logget inn og prøver å lese og endre A og B sine data,
--      akkurat det en tester kan prøve fra nettleserkonsollen.
--   3. Later som om A og B er logget inn og prøver ting de ikke skal få lov til.
--   4. Sletter alle testdataene igjen.
-- Går noe galt underveis, rulles alt tilbake automatisk. Ingen ekte data røres.
--
-- Svaret er én rad per test:
--   OK          = blir stoppet, slik det skal
--   ÅPEN        = slipper gjennom. Må fikses før betatesterne slippes inn.
--   FEIL: ...   = testen fikk en uventet feil. Send meg teksten.
--   SJEKK       = forventet data mangler (testoppsettet fungerte ikke som tenkt)
-- Kjør database/sjekk-sikkerhet.sql først, så du vet at alle reglene er installert.
-- ============================================================

create temp table if not exists tilgangstest (nr integer, hvem text, test text, resultat text);
truncate tilgangstest;

do $$
declare
  a uuid := '00000000-0000-4000-8000-0000000000a1';   -- kunde A
  b uuid := '00000000-0000-4000-8000-0000000000b2';   -- frilanser B
  c uuid := '00000000-0000-4000-8000-0000000000c3';   -- nysgjerrig tester C
  j uuid := '00000000-0000-4000-8000-0000000000d4';   -- oppdraget til A
  o uuid := '00000000-0000-4000-8000-0000000000e5';   -- bestillingen A har hos B
  j2 uuid := '00000000-0000-4000-8000-0000000000f6';  -- et oppdrag som B selv har lagt ut
  n integer;
  v text;
  res text[] := '{}';
  hvem text;

  -- Logger inn som en av testbrukerne (samme som nettsiden gjør med innloggingen)
  -- Merk: rollen settes for resten av transaksjonen, og nullstilles til slutt.
begin
  -- ---------- 1. testdata (som eier av databasen) ----------
  insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values
    (a, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tilgangstest-a@freelio.invalid', '{}', '{"name":"Testkunde A"}', now(), now()),
    (b, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tilgangstest-b@freelio.invalid', '{}', '{"name":"Testfrilanser B"}', now(), now()),
    (c, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tilgangstest-c@freelio.invalid', '{}', '{"name":"Nysgjerrig C"}', now(), now());
  -- Profilene lages av triggeren on_auth_user_created. Sikrer at de finnes uansett.
  insert into public.profiles (id, name) values (a, 'Testkunde A'), (b, 'Testfrilanser B'), (c, 'Nysgjerrig C') on conflict (id) do nothing;

  insert into public.freelancers (id, user_id, data) values (b::text, b, '{"name":"Testfrilanser B","role":"Fotograf"}');
  insert into public.jobs (id, owner_id, status, data) values
    (j, a, 'open', '{"title":"Testoppdrag","desc":"Bare en test","budget":1000}'),
    (j2, b, 'open', '{"title":"Oppdrag fra B","desc":"Bare en test","budget":1000}');
  insert into public.offers (job_id, freelancer_id, price, msg) values (j, b::text, 1000, 'Testtilbud');
  insert into public.orders (id, customer_id, freelancer_id, job_id, status, title, price) values (o, a, b::text, j, 'paid', 'Testbestilling', 1000);
  insert into public.messages (customer_id, freelancer_id, sender, text) values (a, b::text, 'customer', 'Hemmelig testmelding');

  -- ---------- 2. C er logget inn og prøver seg ----------
  hvem := 'C (fremmed)';
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  set local role authenticated;

  select count(*) into n from public.profiles where id = a;
  res := res || array[hvem, 'Lese profilen til A', case when n = 0 then 'OK' else 'ÅPEN' end];

  select count(*) into n from public.messages where customer_id = a;
  res := res || array[hvem, 'Lese meldingene mellom A og B', case when n = 0 then 'OK' else 'ÅPEN' end];

  select count(*) into n from public.orders where id = o;
  res := res || array[hvem, 'Lese bestillingen til A', case when n = 0 then 'OK' else 'ÅPEN' end];

  select count(*) into n from public.offers where job_id = j;
  res := res || array[hvem, 'Lese tilbudet B sendte til A', case when n = 0 then 'OK' else 'ÅPEN' end];

  begin
    with u as (update public.orders set price = 1 where id = o returning 1) select count(*) into n from u;
    res := res || array[hvem, 'Endre prisen på bestillingen til A', case when n = 0 then 'OK' else 'ÅPEN' end];
  exception when insufficient_privilege then res := res || array[hvem, 'Endre prisen på bestillingen til A', 'OK'];
            when others then res := res || array[hvem, 'Endre prisen på bestillingen til A', 'FEIL: ' || sqlerrm];
  end;

  begin
    with u as (update public.jobs set data = data || '{"title":"Endret av C"}' where id = j returning 1) select count(*) into n from u;
    res := res || array[hvem, 'Endre oppdraget til A', case when n = 0 then 'OK' else 'ÅPEN' end];
  exception when insufficient_privilege then res := res || array[hvem, 'Endre oppdraget til A', 'OK'];
            when others then res := res || array[hvem, 'Endre oppdraget til A', 'FEIL: ' || sqlerrm];
  end;

  begin
    with d as (delete from public.jobs where id = j returning 1) select count(*) into n from d;
    res := res || array[hvem, 'Slette oppdraget til A', case when n = 0 then 'OK' else 'ÅPEN' end];
  exception when insufficient_privilege then res := res || array[hvem, 'Slette oppdraget til A', 'OK'];
            when others then res := res || array[hvem, 'Slette oppdraget til A', 'FEIL: ' || sqlerrm];
  end;

  begin
    with d as (delete from public.messages where customer_id = a returning 1) select count(*) into n from d;
    res := res || array[hvem, 'Slette meldingene mellom A og B', case when n = 0 then 'OK' else 'ÅPEN' end];
  exception when insufficient_privilege then res := res || array[hvem, 'Slette meldingene mellom A og B', 'OK'];
            when others then res := res || array[hvem, 'Slette meldingene mellom A og B', 'FEIL: ' || sqlerrm];
  end;

  begin
    insert into public.messages (customer_id, freelancer_id, sender, text) values (a, b::text, 'freelancer', 'Falsk melding fra C');
    res := res || array[hvem, 'Sende melding til A som om det var B', 'ÅPEN'];
  exception when insufficient_privilege then res := res || array[hvem, 'Sende melding til A som om det var B', 'OK'];
            when others then res := res || array[hvem, 'Sende melding til A som om det var B', 'FEIL: ' || sqlerrm];
  end;

  begin
    insert into public.freelancers (id, user_id, data) values ('falsk-profil-c', b, '{"name":"Falsk B"}');
    res := res || array[hvem, 'Lage frilanserprofil i navnet til B', 'ÅPEN'];
  exception when insufficient_privilege then res := res || array[hvem, 'Lage frilanserprofil i navnet til B', 'OK'];
            when others then res := res || array[hvem, 'Lage frilanserprofil i navnet til B', 'FEIL: ' || sqlerrm];
  end;

  begin
    insert into public.freelancers (id, user_id, data) values (c::text, c, '{"name":"Nysgjerrig C","verified":true,"rating":5,"reviews":99,"jobs":99}');
    select data ->> 'verified' into v from public.freelancers where id = c::text;
    res := res || array[hvem, 'Gi seg selv «BankID-verifisert» og 5 stjerner', case when v = 'false' then 'OK' else 'ÅPEN' end];
  exception when insufficient_privilege then res := res || array[hvem, 'Gi seg selv «BankID-verifisert» og 5 stjerner', 'OK'];
            when others then res := res || array[hvem, 'Gi seg selv «BankID-verifisert» og 5 stjerner', 'FEIL: ' || sqlerrm];
  end;

  begin
    insert into public.reviews (order_id, author_id, freelancer_id, stars, text) values (o, c, b::text, 1, 'Falsk omtale');
    res := res || array[hvem, 'Skrive omtale uten å ha bestilt', 'ÅPEN'];
  exception when insufficient_privilege then res := res || array[hvem, 'Skrive omtale uten å ha bestilt', 'OK'];
            when others then res := res || array[hvem, 'Skrive omtale uten å ha bestilt', 'FEIL: ' || sqlerrm];
  end;

  begin
    select count(*) into n from public.bug_reports;
    res := res || array[hvem, 'Lese feilmeldingene andre har sendt', case when n = 0 then 'OK' else 'ÅPEN' end];
  exception when insufficient_privilege then res := res || array[hvem, 'Lese feilmeldingene andre har sendt', 'OK'];
            when undefined_table then res := res || array[hvem, 'Lese feilmeldingene andre har sendt', 'OK (tabellen finnes ikke)'];
            when others then res := res || array[hvem, 'Lese feilmeldingene andre har sendt', 'FEIL: ' || sqlerrm];
  end;

  begin
    select count(*) into n from public.admins;
    res := res || array[hvem, 'Lese admin-listen', 'ÅPEN'];
  exception when insufficient_privilege then res := res || array[hvem, 'Lese admin-listen', 'OK'];
            when undefined_table then res := res || array[hvem, 'Lese admin-listen', 'OK (tabellen finnes ikke)'];
            when others then res := res || array[hvem, 'Lese admin-listen', 'FEIL: ' || sqlerrm];
  end;

  begin
    perform public.admin_delete_job(j, 'test');
    res := res || array[hvem, 'Fjerne oppdraget til A med admin-funksjonen', 'ÅPEN'];
  exception when insufficient_privilege then res := res || array[hvem, 'Fjerne oppdraget til A med admin-funksjonen', 'OK'];
            when undefined_function then res := res || array[hvem, 'Fjerne oppdraget til A med admin-funksjonen', 'OK (funksjonen finnes ikke)'];
            when others then res := res || array[hvem, 'Fjerne oppdraget til A med admin-funksjonen', 'FEIL: ' || sqlerrm];
  end;

  -- ---------- 3. A (kunden) er logget inn ----------
  hvem := 'A (kunde)';
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);

  select count(*) into n from public.messages where customer_id = a;
  res := res || array[hvem, 'Ser sin egen melding (skal gå)', case when n = 1 then 'OK' else 'SJEKK' end];

  begin
    update public.orders set price = 1 where id = o;
    res := res || array[hvem, 'Endre prisen på sin egen bestilling', 'ÅPEN'];
  exception when insufficient_privilege then res := res || array[hvem, 'Endre prisen på sin egen bestilling', 'OK'];
            when others then res := res || array[hvem, 'Endre prisen på sin egen bestilling', 'FEIL: ' || sqlerrm];
  end;

  begin
    update public.orders set status = 'approved' where id = o;
    res := res || array[hvem, 'Godkjenne en leveranse som ikke er levert', 'ÅPEN'];
  exception when insufficient_privilege then res := res || array[hvem, 'Godkjenne en leveranse som ikke er levert', 'OK'];
            when others then res := res || array[hvem, 'Godkjenne en leveranse som ikke er levert', 'FEIL: ' || sqlerrm];
  end;

  -- ---------- 4. B (frilanseren) er logget inn ----------
  hvem := 'B (frilanser)';
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);

  begin
    update public.offers set price = 5 where job_id = j;
    res := res || array[hvem, 'Endre et tilbud etter at det er sendt', 'ÅPEN'];
  exception when insufficient_privilege then res := res || array[hvem, 'Endre et tilbud etter at det er sendt', 'OK'];
            when others then res := res || array[hvem, 'Endre et tilbud etter at det er sendt', 'FEIL: ' || sqlerrm];
  end;

  begin
    insert into public.messages (customer_id, freelancer_id, sender, text) values (c, b::text, 'freelancer', 'Reklame til en fremmed');
    res := res || array[hvem, 'Sende melding til en fremmed kunde (C)', 'ÅPEN'];
  exception when insufficient_privilege then res := res || array[hvem, 'Sende melding til en fremmed kunde (C)', 'OK'];
            when others then res := res || array[hvem, 'Sende melding til en fremmed kunde (C)', 'FEIL: ' || sqlerrm];
  end;

  begin
    insert into public.offers (job_id, freelancer_id, price, msg) values (j2, b::text, 500, 'Tilbud på eget oppdrag');
    res := res || array[hvem, 'Sende tilbud på sitt eget oppdrag', 'ÅPEN'];
  exception when insufficient_privilege then res := res || array[hvem, 'Sende tilbud på sitt eget oppdrag', 'OK'];
            when others then res := res || array[hvem, 'Sende tilbud på sitt eget oppdrag', 'FEIL: ' || sqlerrm];
  end;

  begin
    update public.orders set status = 'approved' where id = o;
    res := res || array[hvem, 'Godkjenne sin egen bestilling', 'ÅPEN'];
  exception when insufficient_privilege then res := res || array[hvem, 'Godkjenne sin egen bestilling', 'OK'];
            when others then res := res || array[hvem, 'Godkjenne sin egen bestilling', 'FEIL: ' || sqlerrm];
  end;

  -- ---------- 5. rydd opp (som eier av databasen) ----------
  reset role;
  perform set_config('request.jwt.claims', '', true);
  delete from public.messages where customer_id in (a, b, c) or freelancer_id in (a::text, b::text, c::text);
  delete from public.reviews where order_id = o;
  delete from public.orders where id = o;
  delete from public.offers where job_id in (j, j2);
  delete from public.jobs where id in (j, j2);
  delete from public.freelancers where id in (b::text, c::text, 'falsk-profil-c');
  delete from public.profiles where id in (a, b, c);
  delete from auth.users where id in (a, b, c);

  for i in 1 .. array_length(res, 1) / 3 loop
    insert into tilgangstest values (i, res[i * 3 - 2], res[i * 3 - 1], res[i * 3]);
  end loop;
end $$;

select
  (select count(*) from tilgangstest where resultat not like 'OK%') as problemer,
  hvem, test, resultat
from tilgangstest
order by (resultat like 'OK%'), nr;
