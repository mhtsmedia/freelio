-- ============================================================
-- Admin: fjerne frilansere, innlegg, kommentarer og omtaler
-- Krever database/admin.sql. Kjør denne én gang i SQL Editor. Den kan kjøres flere ganger.
-- ============================================================
-- Hver handling sjekker selv at du er admin, og skrives i admin_log (hvem, hva, når og hvorfor).
-- En frilanser med bestillinger kan bare skjules, ikke slettes, så bestillinger, avtaler og betalinger
-- blir stående for kundene.

-- Admin kan se skjulte frilanserprofiler (for å kunne vise dem igjen)
drop policy if exists "frilansere les admin" on public.freelancers;
create policy "frilansere les admin" on public.freelancers for select to authenticated using (public.is_admin());

-- Hjelpere som bare brukes inne i funksjonene under
create or replace function public.admin_require()
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Bare admin kan gjøre dette.' using errcode = '42501'; end if;
end $$;
revoke all on function public.admin_require() from public, anon, authenticated;

create or replace function public.admin_note(p_action text, p_ref text, p_note text)
returns void language sql security definer set search_path = public as $$
  insert into public.admin_log (admin_id, action, ref, note) values (auth.uid(), p_action, p_ref, left(coalesce(p_note, ''), 500));
$$;
revoke all on function public.admin_note(text, text, text) from public, anon, authenticated;

create or replace function public.admin_why(p_reason text)
returns text language sql immutable as $$
  select case when coalesce(trim(p_reason), '') <> '' then ' | Grunn: ' || left(trim(p_reason), 200) else '' end
$$;

-- ---------- innlegg på Utforsk ----------
create or replace function public.admin_delete_post(p_id uuid, p_reason text default '')
returns void language plpgsql security definer set search_path = public as $$
declare t text;
begin
  perform public.admin_require();
  delete from public.posts where id = p_id returning coalesce(data ->> 'cap', '') into t;
  if not found then raise exception 'Fant ikke innlegget. Det kan allerede være fjernet.'; end if;
  perform public.admin_note('fjernet innlegg', p_id::text, left(t, 200) || public.admin_why(p_reason));
end $$;

-- ---------- kommentarer ----------
create or replace function public.admin_delete_comment(p_id uuid, p_reason text default '')
returns void language plpgsql security definer set search_path = public as $$
declare t text;
begin
  perform public.admin_require();
  delete from public.post_comments where id = p_id returning author_name || ': ' || left(text, 150) into t;
  if not found then raise exception 'Fant ikke kommentaren. Den kan allerede være fjernet.'; end if;
  perform public.admin_note('fjernet kommentar', p_id::text, t || public.admin_why(p_reason));
end $$;

-- ---------- omtaler ----------
create or replace function public.admin_delete_review(p_id uuid, p_reason text default '')
returns void language plpgsql security definer set search_path = public as $$
declare t text;
begin
  perform public.admin_require();
  delete from public.reviews where id = p_id returning author_name || ' (' || stars || ' stjerner): ' || left(text, 150) into t;
  if not found then raise exception 'Fant ikke omtalen. Den kan allerede være fjernet.'; end if;
  perform public.admin_note('fjernet omtale', p_id::text, t || public.admin_why(p_reason));
end $$;

-- ---------- frilansere ----------
-- Status til admin-kortet på profilen
create or replace function public.admin_freelancer_info(p_id text)
returns jsonb language plpgsql stable security definer set search_path = public, auth as $$
declare r jsonb;
begin
  perform public.admin_require();
  select jsonb_build_object(
    'hidden', coalesce(f.data ->> 'adminHidden', '') = 'true',
    'published', f.published,
    'banned', coalesce(u.banned_until > now(), false),
    'isAdmin', exists (select 1 from public.admins a where a.user_id = f.user_id),
    'orders', (select count(*) from public.orders o where o.freelancer_id = f.id),
    'active', (select count(*) from public.orders o where o.freelancer_id = f.id and o.status in ('paid', 'delivered', 'dispute'))
  ) into r
  from public.freelancers f left join auth.users u on u.id = f.user_id
  where f.id = p_id;
  if r is null then raise exception 'Fant ikke frilanseren.'; end if;
  return r;
end $$;

-- Skjul fra søk, eller vis igjen. Mens profilen er skjult av admin, kan ikke frilanseren publisere den selv.
create or replace function public.admin_hide_freelancer(p_id text, p_hide boolean, p_reason text default '')
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.admin_require();
  update public.freelancers
     set published = not p_hide,
         data = case when p_hide then coalesce(data, '{}'::jsonb) || '{"adminHidden": true}'::jsonb else coalesce(data, '{}'::jsonb) - 'adminHidden' end
   where id = p_id;
  if not found then raise exception 'Fant ikke frilanseren.'; end if;
  perform public.admin_note(case when p_hide then 'skjulte frilanser' else 'viste frilanser igjen' end, p_id, public.admin_why(p_reason));
end $$;

create or replace function public.guard_admin_hidden()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if coalesce(old.data ->> 'adminHidden', '') = 'true' and not public.is_admin() then
    new.published := false;
    new.data := coalesce(new.data, '{}'::jsonb) || '{"adminHidden": true}'::jsonb;
  end if;
  return new;
end $$;
drop trigger if exists freelancers_admin_hidden on public.freelancers;
create trigger freelancers_admin_hidden before update on public.freelancers
  for each row execute function public.guard_admin_hidden();

-- Steng kontoen (kan ikke logge inn), eller åpne den igjen. Stengt profil skjules også fra søk.
create or replace function public.admin_ban_freelancer(p_id text, p_ban boolean, p_reason text default '')
returns void language plpgsql security definer set search_path = public, auth as $$
declare uid uuid;
begin
  perform public.admin_require();
  select user_id into uid from public.freelancers where id = p_id;
  if uid is null then raise exception 'Fant ikke kontoen til frilanseren.'; end if;
  if uid = auth.uid() then raise exception 'Du kan ikke stenge din egen konto.'; end if;
  if exists (select 1 from public.admins a where a.user_id = uid) then raise exception 'Kontoen er admin og kan ikke stenges her.'; end if;
  update auth.users set banned_until = case when p_ban then 'infinity'::timestamptz else null end where id = uid;
  if p_ban then
    update public.freelancers set published = false, data = coalesce(data, '{}'::jsonb) || '{"adminHidden": true}'::jsonb where id = p_id;
  end if;
  perform public.admin_note(case when p_ban then 'stengte konto' else 'åpnet konto' end, p_id, public.admin_why(p_reason));
end $$;

-- Slett frilanserprofilen for godt. Bare når frilanseren ikke har bestillinger (ellers: skjul).
-- Tilbud, meldinger, omtaler, innlegg og lagringer hos andre forsvinner sammen med profilen.
create or replace function public.admin_delete_freelancer(p_id text, p_reason text default '')
returns void language plpgsql security definer set search_path = public as $$
declare n text; uid uuid;
begin
  perform public.admin_require();
  select data ->> 'name', user_id into n, uid from public.freelancers where id = p_id;
  if not found then raise exception 'Fant ikke frilanseren.'; end if;
  if uid = auth.uid() then raise exception 'Du kan ikke slette din egen profil herfra.'; end if;
  if exists (select 1 from public.admins a where a.user_id = uid) then raise exception 'Profilen tilhører en admin og kan ikke slettes her.'; end if;
  if exists (select 1 from public.orders o where o.freelancer_id = p_id) then
    raise exception 'Frilanseren har bestillinger. Skjul profilen i stedet, så blir bestillingene stående for kundene.';
  end if;
  delete from public.freelancers where id = p_id;
  perform public.admin_note('slettet frilanser', p_id, coalesce(n, '') || public.admin_why(p_reason));
end $$;

-- ---------- oversikt til admin-siden ----------
create or replace function public.admin_overview()
returns jsonb language plpgsql stable security definer set search_path = public, auth as $$
begin
  perform public.admin_require();
  return jsonb_build_object(
    'hidden', coalesce((select jsonb_agg(jsonb_build_object('id', f.id, 'name', coalesce(f.data ->> 'name', 'Uten navn'), 'banned', coalesce(u.banned_until > now(), false)) order by f.created_at desc)
      from public.freelancers f left join auth.users u on u.id = f.user_id
      where not f.demo and (coalesce(f.data ->> 'adminHidden', '') = 'true' or u.banned_until > now())), '[]'::jsonb),
    'log', coalesce((select jsonb_agg(x order by x.created_at desc) from (
      select l.action, l.ref, l.note, l.created_at, coalesce(p.name, 'Admin') as admin
      from public.admin_log l left join public.profiles p on p.id = l.admin_id
      order by l.created_at desc limit 40) x), '[]'::jsonb),
    'bugs', (select count(*) from public.bug_reports where status = 'ny')
  );
end $$;

-- Funksjonene kan kalles av innloggede (de sjekker selv at du er admin), ikke av uinnloggede
do $$
declare f text;
begin
  foreach f in array array[
    'admin_delete_post(uuid, text)', 'admin_delete_comment(uuid, text)', 'admin_delete_review(uuid, text)',
    'admin_freelancer_info(text)', 'admin_hide_freelancer(text, boolean, text)', 'admin_ban_freelancer(text, boolean, text)',
    'admin_delete_freelancer(text, text)', 'admin_overview()'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
