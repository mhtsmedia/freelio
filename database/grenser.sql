-- ============================================================
-- Grenser for det brukerne skriver: makspris 1 000 000 kr og lengde på tekst
-- Kjør denne én gang i SQL Editor. Den kan kjøres flere ganger.
-- ============================================================
-- Samme grenser som skjemaene på nettsiden, så de ikke kan omgås ved å snakke direkte med databasen.
-- «not valid» betyr at reglene gjelder alt som lagres fra nå av. Det som allerede ligger der, blir stående.

-- Oppdrag: budsjett mellom 1 og 1 000 000 kr, og korte felt
alter table public.jobs drop constraint if exists jobs_grenser;
alter table public.jobs add constraint jobs_grenser check (
  demo or (
    octet_length(data::text) <= 16384
    and char_length(coalesce(data ->> 'title', '')) <= 80
    and char_length(coalesce(data ->> 'desc', '')) <= 3000
    and char_length(coalesce(data ->> 'date', '')) <= 40
    and char_length(coalesce(data ->> 'area', '')) <= 60
    and char_length(coalesce(data ->> 'scope', '')) <= 120
    and char_length(coalesce(data ->> 'delivery', '')) <= 200
    and (case when jsonb_typeof(data -> 'budget') = 'number' then (data ->> 'budget')::numeric between 1 and 1000000 else false end)
  )
) not valid;

-- Tilbud: pris mellom 1 og 1 000 000 kr, melding høyst 1000 tegn
alter table public.offers drop constraint if exists offers_grenser;
alter table public.offers add constraint offers_grenser check (
  char_length(msg) <= 1000 and price between 1 and 1000000
) not valid;

-- Bestillinger: høyst 1 000 000 kr
alter table public.orders drop constraint if exists orders_grenser;
alter table public.orders add constraint orders_grenser check (
  char_length(title) <= 200 and price between 0 and 1000000 and octet_length(data::text) <= 131072
) not valid;

-- Frilansere: høyst 4 pakker, hver høyst 1 000 000 kr, korte navn og beskrivelser
alter table public.freelancers drop constraint if exists freelancers_priser;
alter table public.freelancers add constraint freelancers_priser check (
  demo or (
    (case when jsonb_typeof(data -> 'pk') = 'array' then jsonb_array_length(data -> 'pk') <= 4 else true end)
    and not jsonb_path_exists(data, '$.pk[*][1] ? (@ > 1000000 || @ < 0)')
    and not jsonb_path_exists(data, '$.pk[*][0] ? (@ like_regex ".{41}")')
    and not jsonb_path_exists(data, '$.pk[*][2] ? (@ like_regex ".{201}")')
    and (case when jsonb_typeof(data -> 'from') = 'number' then (data ->> 'from')::numeric <= 1000000 else true end)
    and char_length(coalesce(data ->> 'terms', '')) <= 4000
  )
) not valid;

-- Meldinger: høyst 2000 tegn (det samme som skrivefeltet)
alter table public.messages drop constraint if exists messages_lengde;
alter table public.messages add constraint messages_lengde check (char_length(text) <= 2000) not valid;
