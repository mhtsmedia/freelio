-- ============================================================
-- Push-varsler om nye tilbud og nye meldinger
-- Kjør denne én gang i SQL Editor, etter at funksjonen «varsle» er lagt inn (supabase/functions/varsle).
-- Den kan kjøres flere ganger.
-- ============================================================

-- Enhetene som skal få varsel. Hver nettleser eller telefon som har slått på varsler, har én rad.
create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  endpoint text not null unique check (endpoint ~ '^https://' and char_length(endpoint) <= 1000),
  p256dh text not null check (char_length(p256dh) between 40 and 200),
  auth text not null check (char_length(auth) between 10 and 100),
  ua text not null default '' check (char_length(ua) <= 300),
  created_at timestamptz not null default now()
);
create index if not exists push_subscriptions_user on public.push_subscriptions (user_id);
alter table public.push_subscriptions enable row level security;
revoke all on public.push_subscriptions from anon;

-- Du ser og sletter bare dine egne. Nye lagres med save_push (under), så en enhet som bytter konto flyttes riktig.
drop policy if exists "push les" on public.push_subscriptions;
create policy "push les" on public.push_subscriptions for select to authenticated using (user_id = auth.uid());
drop policy if exists "push slett" on public.push_subscriptions;
create policy "push slett" on public.push_subscriptions for delete to authenticated using (user_id = auth.uid());

create or replace function public.save_push(p_endpoint text, p_p256dh text, p_auth text, p_ua text default '')
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Logg inn først' using errcode = '42501'; end if;
  -- Høyst 20 enheter per bruker. Den eldste fjernes.
  delete from public.push_subscriptions where id in (
    select id from public.push_subscriptions where user_id = auth.uid() and endpoint <> p_endpoint order by created_at desc offset 19);
  insert into public.push_subscriptions (user_id, endpoint, p256dh, auth, ua)
  values (auth.uid(), p_endpoint, p_p256dh, p_auth, left(coalesce(p_ua, ''), 300))
  on conflict (endpoint) do update set user_id = excluded.user_id, p256dh = excluded.p256dh, auth = excluded.auth, ua = excluded.ua, created_at = now();
end $$;
revoke all on function public.save_push(text, text, text, text) from public, anon;
grant execute on function public.save_push(text, text, text, text) to authenticated;

-- Når du logger ut eller slår av varsler på en enhet
create or replace function public.forget_push(p_endpoint text)
returns void language sql security definer set search_path = public as $$
  delete from public.push_subscriptions where endpoint = p_endpoint and user_id = auth.uid();
$$;
revoke all on function public.forget_push(text) from public, anon;
grant execute on function public.forget_push(text) to authenticated;

-- Hva som er varslet, så hver hendelse bare varsles én gang. Bare funksjonen (service role) bruker tabellen.
create table if not exists public.push_log (
  kind text not null,
  ref uuid not null,
  created_at timestamptz not null default now(),
  primary key (kind, ref)
);
alter table public.push_log enable row level security;
revoke all on public.push_log from anon, authenticated;

-- Databasen sier fra til funksjonen når det kommer et nytt tilbud eller en ny melding.
-- pg_net sender kallet etter at raden er lagret, så det sinker ikke den som sender.
create extension if not exists pg_net;

create or replace function public.push_notify()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform net.http_post(
    url := 'https://hweftjtulzjripkkbdeb.supabase.co/functions/v1/varsle',
    body := jsonb_build_object('type', tg_argv[0], 'id', new.id),
    headers := '{"Content-Type": "application/json"}'::jsonb
  );
  return null;
exception when others then
  -- Et varsel som ikke går, skal aldri stoppe selve tilbudet eller meldingen
  return null;
end $$;

drop trigger if exists offers_push on public.offers;
create trigger offers_push after insert on public.offers
  for each row execute function public.push_notify('offer');
drop trigger if exists messages_push on public.messages;
create trigger messages_push after insert on public.messages
  for each row when (new.sender <> 'system') execute function public.push_notify('message');
