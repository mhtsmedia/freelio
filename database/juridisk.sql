-- ============================================================
-- Juridisk gjennomgang (november 2026): regler som tetter smutthullene i bestillingsflyten
-- Kjør denne én gang i SQL Editor, etter avtale.sql, admin.sql og feil.sql. Den kan kjøres flere ganger.
-- ============================================================
-- Dette endres:
--   * prisen på en ny bestilling må være prisen på pakken eller på tilbudet frilanseren ga (S2)
--   * dato og sted låses ved booking, og refusjon regnes fra den låste datoen (S3)
--   * avbestilling for nye avtaler (versjon 2): gratis til og med 30 dager før, 50 % fra 29 til 7 dager før,
--     ingenting etter det, og ingen avbestilling etter avtalt dato (S6). 14 dagers angrerett gir full refusjon.
--   * ny status «case» (Sak hos Freelio). Den stopper automatisk godkjenning til en admin har avgjort saken (S4)
--   * leverer ikke frilanseren på nytt innen 3 dager etter en klage, kan kunden sende saken til Freelio (S5)
--   * admin kan lese og avgjøre saker (saker.html). Alt logges i admin_log.
--   * «Meld bilde» lagres sammen med feilmeldingene, og frilansere kan oppgi om de er næringsdrivende
-- Dette venter til betaling er koblet på: at bare betalingsleverandøren kan sette en bestilling til «betalt» (S1),
-- og at unntaket for demo-frilansere fjernes (S7).

-- ---------- ny status ----------

alter table public.orders drop constraint if exists orders_status_check;
alter table public.orders add constraint orders_status_check
  check (status in ('paid', 'delivered', 'approved', 'dispute', 'case', 'cancelled'));

-- Avtalt dato som dato. Teksten må være på formen DD.MM.ÅÅÅÅ, ellers regnes oppdraget som uten fast dato.
create or replace function public.order_date(p text)
returns date language plpgsql immutable as $$
begin
  if p is null or p !~ '^\d{2}\.\d{2}\.\d{4}$' then
    return null;
  end if;
  return to_date(p, 'DD.MM.YYYY');
exception when others then
  return null;
end $$;

-- ---------- ny bestilling: pris og avtale låses ----------

create or replace function public.guard_order_new()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  c jsonb;
  fdata jsonb;
  cname text;
  ver integer;
  pk jsonb;
  usage text;
begin
  if auth.uid() is null then
    return new;
  end if;
  c := new.data -> 'contract';
  if c is null or jsonb_typeof(c) <> 'object' or coalesce(c ->> 'v', '') not in ('1', '2') then
    raise exception 'Bestillingen mangler avtale. Last siden på nytt og prøv igjen.' using errcode = '42501';
  end if;
  ver := (c ->> 'v')::integer;
  select data into fdata from public.freelancers where id = new.freelancer_id;
  select name into cname from public.profiles where id = new.customer_id;

  -- Prisen bestemmes av pakken eller tilbudet, ikke av nettleseren
  usage := case when c ->> 'usage' = 'k' then 'k' else 'p' end;
  if not public.is_demo_freelancer(new.freelancer_id) then
    if new.job_id is not null then
      if not exists (select 1 from public.offers o where o.job_id = new.job_id and o.freelancer_id = new.freelancer_id and o.price = new.price) then
        raise exception 'Prisen stemmer ikke med tilbudet. Last siden på nytt og prøv igjen.' using errcode = '42501';
      end if;
    else
      select e into pk from jsonb_array_elements(case when jsonb_typeof(fdata -> 'pk') = 'array' then fdata -> 'pk' else '[]'::jsonb end) e
        where jsonb_typeof(e) = 'array' and e ->> 0 = new.title and (e ->> 1) ~ '^\d+(\.\d+)?$' and round((e ->> 1)::numeric) = new.price
        limit 1;
      if pk is null then
        raise exception 'Pakken eller prisen er endret. Last siden på nytt og prøv igjen.' using errcode = '42501';
      end if;
      usage := case when pk ->> 3 = 'k' then 'k' else 'p' end;
    end if;
  end if;

  -- Avtalen bygges på nytt av databasen. Bare kundens egne valg og pakkebeskrivelsen kommer fra nettleseren.
  c := jsonb_build_object(
    'v', ver,
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
  ) || case when ver = 2 then jsonb_build_object(
    'usage', usage,
    'portfolio', coalesce(c ->> 'portfolio', '') = 'true',
    'early', coalesce(c ->> 'early', '') = 'true' and coalesce(fdata ->> 'seller', '') <> 'privat',
    'seller', case when fdata ->> 'seller' in ('naering', 'privat') then fdata ->> 'seller' else '' end,
    'orgnr', case when fdata ->> 'seller' = 'naering' and coalesce(fdata ->> 'orgnr', '') ~ '^\d{9}$' then fdata ->> 'orgnr' else '' end,
    'mva', coalesce(fdata ->> 'seller', '') = 'naering' and coalesce(fdata ->> 'mva', '') = 'true'
  ) else '{}'::jsonb end;
  new.data := (coalesce(new.data, '{}'::jsonb) - array['deliveredAt', 'disputes', 'disputeAt', 'refund', 'approvedAt', 'approvedBy', 'cancelledBy', 'caseAt', 'caseBy', 'caseNote', 'caseDoneAt'])
    || jsonb_build_object('contract', c, 'date', c ->> 'date', 'place', c ->> 'place');
  return new;
end $$;

drop trigger if exists orders_contract on public.orders;
create trigger orders_contract before insert on public.orders
  for each row execute function public.guard_order_new();

-- ---------- endring av bestilling: status, penger og avtale ----------
-- Erstatter guard_order fra avtale.sql.

create or replace function public.guard_order()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  me uuid;
  is_c boolean;
  is_f boolean;
  dm boolean;
  legacy boolean;
  v2 boolean;
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
  -- En admin som avgjør en sak, går gjennom admin_resolve_case. Den funksjonen sjekker og logger selv.
  if coalesce(current_setting('freelio.admin_case', true), '') = '1' and public.is_admin() then
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
  v2 := not legacy and c ->> 'v' = '2';

  -- Feltene databasen eier, starter med verdiene som var lagret
  srv := jsonb_build_object(
    'contract', c,
    'deliveredAt', old.data -> 'deliveredAt',
    'disputes', old.data -> 'disputes',
    'disputeAt', old.data -> 'disputeAt',
    'refund', old.data -> 'refund',
    'approvedAt', old.data -> 'approvedAt',
    'approvedBy', old.data -> 'approvedBy',
    'cancelledBy', old.data -> 'cancelledBy',
    'caseAt', old.data -> 'caseAt',
    'caseBy', old.data -> 'caseBy',
    'caseNote', old.data -> 'caseNote',
    'caseDoneAt', old.data -> 'caseDoneAt',
    -- Dato og sted er låst ved booking
    'date', case when legacy then old.data -> 'date' else c -> 'date' end,
    'place', case when legacy then old.data -> 'place' else c -> 'place' end
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
        raise exception 'Du har meldt fra om feil to ganger. Send saken til Freelio, så avgjør vi den.' using errcode = '42501';
      end if;
      srv := srv || jsonb_build_object('disputes', n + 1, 'disputeAt', public.now_text());
    elsif new.status = 'case' and (
          -- kunden: etter to runder med feil, eller når frilanseren ikke har levert på nytt innen 3 dager
          (is_c and old.status = 'delivered' and coalesce((old.data ->> 'disputes')::integer, 0) >= 2)
          or (is_c and old.status = 'dispute' and ((old.data ->> 'disputeAt') is null
              or (old.data ->> 'disputeAt')::timestamptz + interval '3 days' <= now()))
          -- frilanseren: mener leveransen er som avtalt
          or (is_f and old.status = 'dispute')) then
      srv := srv || jsonb_build_object('caseAt', public.now_text(), 'caseBy', case when is_c then 'kunde' else 'frilanser' end);
    elsif new.status = 'cancelled' and old.status = 'paid' and (is_c or is_f) then
      if is_f then
        refund := old.price;
      else
        -- Datoen hentes fra den låste avtalen, ikke fra feltet kunden kan skrive til
        d := public.order_date(case when legacy then old.data ->> 'date' else c ->> 'date' end);
        if not v2 then
          -- Avtaler fra før november 2026: gratis frem til 7 dager før, ellers 50 %
          refund := case when d is null or d - current_date > 7 then old.price else round(old.price / 2.0)::integer end;
        elsif d is not null and d < current_date then
          raise exception 'Avtalt dato er passert, så oppdraget kan ikke avbestilles. Meld fra om feil hvis noe ikke er som avtalt.' using errcode = '42501';
        elsif coalesce(c ->> 'seller', '') <> 'privat' and coalesce(c ->> 'early', '') <> 'true'
              and old.created_at + interval '14 days' > now() then
          -- Angrerett: 14 dager fra booking, når kunden ikke har bedt om at oppdraget starter før fristen er ute
          refund := old.price;
        elsif d is null then
          refund := case when (c ->> 'freelancerAt') is null then old.price else round(old.price / 2.0)::integer end;
        elsif d - current_date >= 30 then
          refund := old.price;
        elsif d - current_date >= 7 then
          refund := round(old.price / 2.0)::integer;
        else
          refund := 0;
        end if;
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
  new.data := (coalesce(new.data, '{}'::jsonb) - array['contract', 'deliveredAt', 'disputes', 'disputeAt', 'refund', 'approvedAt', 'approvedBy', 'cancelledBy', 'caseAt', 'caseBy', 'caseNote', 'caseDoneAt', 'date', 'place'])
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

-- ---------- sak hos Freelio: admin leser og avgjør ----------

-- Åpne saker, og de siste som er avgjort
create or replace function public.admin_cases()
returns table (id uuid, status text, title text, price integer, created_at timestamptz, data jsonb,
               customer_id uuid, customer_name text, freelancer_id text, freelancer_name text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Bare admin kan se saker.' using errcode = '42501';
  end if;
  return query
    select o.id, o.status, o.title, o.price, o.created_at,
           o.data - array['files'] as data,
           o.customer_id, coalesce(p.name, 'Slettet bruker'), o.freelancer_id, coalesce(f.data ->> 'name', '')
    from public.orders o
    left join public.profiles p on p.id = o.customer_id
    left join public.freelancers f on f.id = o.freelancer_id
    where o.status = 'case' or (o.data ->> 'caseDoneAt') is not null
    order by (o.status = 'case') desc, o.data ->> 'caseAt' desc
    limit 100;
end $$;
revoke all on function public.admin_cases() from public, anon;
grant execute on function public.admin_cases() to authenticated;

-- Meldingene mellom partene i en sak. Bare for bestillinger som har vært sendt til Freelio. Lesingen logges.
create or replace function public.admin_case_messages(p_id uuid)
returns table (sender text, body text, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare
  o public.orders;
begin
  if not public.is_admin() then
    raise exception 'Bare admin kan se saker.' using errcode = '42501';
  end if;
  select * into o from public.orders where id = p_id;
  if not found or (o.data ->> 'caseAt') is null then
    raise exception 'Fant ikke saken.';
  end if;
  insert into public.admin_log (admin_id, action, ref, note) values (auth.uid(), 'leste sak', p_id::text, '');
  return query
    select m.sender, m.text, m.created_at from public.messages m
    where m.customer_id = o.customer_id and m.freelancer_id = o.freelancer_id
    order by m.created_at;
end $$;
revoke all on function public.admin_case_messages(uuid) from public, anon;
grant execute on function public.admin_case_messages(uuid) to authenticated;

-- Avgjør en sak. p_refund er beløpet kunden får tilbake (0 = frilanseren får alt, hele prisen = kunden får alt).
-- Avgjørelsen gjelder bare beløpet som holdes. Begrunnelsen vises til begge parter.
create or replace function public.admin_resolve_case(p_id uuid, p_refund integer, p_note text)
returns void language plpgsql security definer set search_path = public as $$
declare
  o public.orders;
  note text;
  whole boolean;
begin
  if not public.is_admin() then
    raise exception 'Bare admin kan avgjøre saker.' using errcode = '42501';
  end if;
  select * into o from public.orders where id = p_id for update;
  if not found or o.status <> 'case' then
    raise exception 'Fant ingen åpen sak på denne bestillingen.';
  end if;
  if p_refund is null or p_refund < 0 or p_refund > o.price then
    raise exception 'Beløpet må være mellom 0 og prisen på oppdraget.';
  end if;
  note := left(btrim(coalesce(p_note, '')), 1000);
  if char_length(note) < 10 then
    raise exception 'Skriv en begrunnelse på minst 10 tegn. Den vises til begge parter.';
  end if;
  whole := p_refund = o.price;
  perform set_config('freelio.admin_case', '1', true);
  update public.orders set
    status = case when whole then 'cancelled' else 'approved' end,
    data = data || jsonb_build_object('refund', p_refund, 'caseNote', note, 'caseDoneAt', public.now_text())
      || case when whole then jsonb_build_object('cancelledBy', 'freelio')
              else jsonb_build_object('approvedBy', 'freelio', 'approvedAt', public.now_text()) end
    where id = p_id;
  perform set_config('freelio.admin_case', '', true);
  insert into public.messages (customer_id, freelancer_id, sender, text)
  values (o.customer_id, o.freelancer_id, 'system',
    left('Freelio har avgjort saken om «' || o.title || '». Kunden får ' || p_refund || ' kr tilbake av ' || o.price || ' kr. Begrunnelse: ' || note, 2000));
  insert into public.admin_log (admin_id, action, ref, note)
  values (auth.uid(), 'avgjorde sak', p_id::text, left('Refusjon ' || p_refund || ' av ' || o.price || ' | ' || note, 500));
end $$;
revoke all on function public.admin_resolve_case(uuid, integer, text) from public, anon;
grant execute on function public.admin_resolve_case(uuid, integer, text) to authenticated;

-- ---------- frilansere: næringsdrivende eller privatperson ----------
-- Vises til kunden på profilen og i avtalen. Organisasjonsnummer er 9 sifre eller tomt.

alter table public.freelancers drop constraint if exists freelancers_selger;
alter table public.freelancers add constraint freelancers_selger check (
  demo or (
    coalesce(data ->> 'seller', '') in ('', 'naering', 'privat')
    and coalesce(data ->> 'orgnr', '') ~ '^(\d{9})?$'
  )
) not valid;

-- ---------- Meld bilde ----------
-- Lagres sammen med feilmeldingene (database/feil.sql). Hoppes over hvis den tabellen ikke finnes.

do $$
begin
  if to_regclass('public.bug_reports') is not null then
    alter table public.bug_reports drop constraint if exists bug_reports_kind_check;
    alter table public.bug_reports add constraint bug_reports_kind_check
      check (kind in ('liten', 'virker-ikke', 'stopper', 'bilde'));
  end if;
end $$;
