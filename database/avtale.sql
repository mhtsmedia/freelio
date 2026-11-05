-- ============================================================
-- Oppdragsavtale og utbetaling
-- Hver bestilling får en avtale som låses når kunden booker. Frilanseren må godta den før
-- leveransen kan sendes. Databasen styrer alt som har med penger og status å gjøre, så ingen
-- kan omgå reglene ved å snakke direkte med databasen:
--   * avtalen kan ikke endres etter booking, og tidspunktene for godkjenning settes av databasen
--   * frilanserens egne vilkår og navnene hentes fra databasen, ikke fra nettleseren
--   * leveransen kan bare sendes når frilanseren har godtatt avtalen
--   * kunden godkjenner, eller leveransen kan godkjennes automatisk 5 dager etter levering
--   * kunden kan melde fra om feil høyst 2 ganger, så pengene ikke kan holdes tilbake for alltid
--   * refusjon ved avbestilling regnes ut av databasen, og frilanseren kan avlyse (full refusjon)
--   * bare frilanseren kan endre selve leveransen (filene)
-- Bestillinger fra før avtalen fantes, fungerer som før.
-- Kjør denne én gang i SQL Editor, etter sikkerhet.sql. Den kan kjøres flere ganger.
-- ============================================================

-- Tidspunkt som tekst (UTC), slik nettsiden leser dem
create or replace function public.now_text()
returns text language sql stable as $$
  select to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
$$;

-- ---------- ny bestilling: avtalen låses ----------

create or replace function public.guard_order_new()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  c jsonb;
  fdata jsonb;
  cname text;
begin
  if auth.uid() is null then
    return new;
  end if;
  c := new.data -> 'contract';
  if c is null or jsonb_typeof(c) <> 'object' or (c ->> 'v') is distinct from '1' then
    raise exception 'Bestillingen mangler avtale. Last siden på nytt og prøv igjen.' using errcode = '42501';
  end if;
  select data into fdata from public.freelancers where id = new.freelancer_id;
  select name into cname from public.profiles where id = new.customer_id;
  -- Avtalen bygges på nytt av databasen. Bare kundens eget tillegg og pakkebeskrivelsen kommer fra nettleseren.
  c := jsonb_build_object(
    'v', 1,
    'title', new.title,
    'price', new.price,
    'date', left(coalesce(new.data ->> 'date', ''), 40),
    'place', left(coalesce(new.data ->> 'place', ''), 200),
    'desc', left(coalesce(c ->> 'desc', ''), 1000),
    'delD', coalesce(fdata -> 'delD', '7'::jsonb),
    'freelancerName', left(coalesce(fdata ->> 'name', ''), 80),
    'customerName', left(coalesce(cname, ''), 80),
    'fTerms', left(coalesce(fdata ->> 'terms', ''), 4000),
    'cTerms', left(coalesce(c ->> 'cTerms', ''), 2000),
    'customerAt', public.now_text(),
    'freelancerAt', null
  );
  new.data := (coalesce(new.data, '{}'::jsonb) - array['deliveredAt', 'disputes', 'refund', 'approvedAt', 'approvedBy', 'cancelledBy'])
    || jsonb_build_object('contract', c);
  return new;
end $$;

drop trigger if exists orders_contract on public.orders;
create trigger orders_contract before insert on public.orders
  for each row execute function public.guard_order_new();

-- ---------- endring av bestilling: status, penger og avtale ----------
-- Erstatter guard_order fra sikkerhet.sql.

create or replace function public.guard_order()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  me uuid;
  is_c boolean;
  is_f boolean;
  dm boolean;
  legacy boolean;
  c jsonb;
  srv jsonb;
  n integer;
  d date;
  refund integer;
begin
  me := auth.uid();
  if me is null then
    return new;
  end if;
  is_c := old.customer_id = me;
  is_f := old.freelancer_id in (select public.my_freelancer_ids());
  dm := public.is_demo_freelancer(old.freelancer_id);

  if new.customer_id is distinct from old.customer_id
     or new.freelancer_id is distinct from old.freelancer_id
     or (new.job_id is distinct from old.job_id and new.job_id is not null)
     or new.price is distinct from old.price
     or new.title is distinct from old.title
     or new.created_at is distinct from old.created_at then
    raise exception 'Bestillingen kan ikke endres på den måten.' using errcode = '42501';
  end if;

  -- Bestillinger fra før avtalen fantes, har ingen avtale og følger de gamle reglene for levering
  c := old.data -> 'contract';
  legacy := c is null or jsonb_typeof(c) <> 'object';

  -- Feltene databasen eier, starter med verdiene som var lagret
  srv := jsonb_build_object(
    'contract', c,
    'deliveredAt', old.data -> 'deliveredAt',
    'disputes', old.data -> 'disputes',
    'refund', old.data -> 'refund',
    'approvedAt', old.data -> 'approvedAt',
    'approvedBy', old.data -> 'approvedBy',
    'cancelledBy', old.data -> 'cancelledBy'
  );

  -- Frilanseren godtar avtalen. Tidspunktet settes her, og kan ikke endres eller fjernes senere.
  if not legacy and is_f and (c ->> 'freelancerAt') is null
     and (new.data -> 'contract' ->> 'freelancerAt') is not null then
    c := jsonb_set(c, '{freelancerAt}', to_jsonb(public.now_text()));
    srv := jsonb_set(srv, '{contract}', c);
  end if;

  if new.status is distinct from old.status then
    if new.status = 'delivered' and old.status in ('paid', 'dispute') and (is_f or (is_c and dm)) then
      if not legacy and not dm and (c ->> 'freelancerAt') is null then
        raise exception 'Du må godta avtalen før du kan sende leveransen.' using errcode = '42501';
      end if;
      srv := srv || jsonb_build_object('deliveredAt', public.now_text());
    elsif new.status = 'approved' and old.status = 'delivered' and (
          is_c
          or (is_f and (old.data ->> 'deliveredAt') is not null
              and (old.data ->> 'deliveredAt')::timestamptz + interval '5 days' <= now())) then
      srv := srv || jsonb_build_object('approvedAt', public.now_text(), 'approvedBy', case when is_c then 'kunde' else 'automatisk' end);
    elsif new.status = 'dispute' and old.status = 'delivered' and is_c then
      n := coalesce((old.data ->> 'disputes')::integer, 0);
      if n >= 2 then
        raise exception 'Du har meldt fra om feil to ganger. Kontakt Freelio, så avgjør vi saken.' using errcode = '42501';
      end if;
      srv := srv || jsonb_build_object('disputes', n + 1);
    elsif new.status = 'cancelled' and old.status = 'paid' and (is_c or is_f) then
      if is_f then
        refund := old.price;
      else
        begin
          d := to_date(old.data ->> 'date', 'DD.MM.YYYY');
        exception when others then
          d := null;
        end;
        refund := case when d is null or d - current_date > 7 then old.price else round(old.price / 2.0)::integer end;
      end if;
      srv := srv || jsonb_build_object('refund', refund, 'cancelledBy', case when is_f then 'frilanser' else 'kunde' end);
    else
      raise exception 'Bestillingen kan ikke flyttes til denne statusen nå.' using errcode = '42501';
    end if;
  end if;

  if new.reviewed is distinct from old.reviewed and not (is_c and new.reviewed and new.status = 'approved') then
    raise exception 'Omtalen på bestillingen kan ikke endres slik.' using errcode = '42501';
  end if;

  -- Feltene databasen eier, kan ikke settes fra nettleseren
  new.data := (coalesce(new.data, '{}'::jsonb) - array['contract', 'deliveredAt', 'disputes', 'refund', 'approvedAt', 'approvedBy', 'cancelledBy'])
    || jsonb_strip_nulls(srv);
  -- Selve leveransen (filene og meldingen) kan bare frilanseren endre
  if not (is_f or dm) then
    new.data := (new.data - array['files', 'delivered', 'deliveryNote'])
      || jsonb_strip_nulls(jsonb_build_object('files', old.data -> 'files', 'delivered', old.data -> 'delivered', 'deliveryNote', old.data -> 'deliveryNote'));
  end if;
  return new;
end $$;

drop trigger if exists orders_guard on public.orders;
create trigger orders_guard before update on public.orders
  for each row execute function public.guard_order();

-- ---------- frilanserens egne vilkår ----------

alter table public.freelancers drop constraint if exists freelancers_vilkar;
alter table public.freelancers add constraint freelancers_vilkar check (
  demo or char_length(coalesce(data ->> 'terms', '')) <= 4000
) not valid;
