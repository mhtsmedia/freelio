-- ============================================================
-- Ekstra sikring: uinnloggede får ikke engang spørre etter private tabeller
-- Kjør én gang i Supabase: SQL Editor -> New query -> lim inn -> Run. Kan kjøres flere ganger.
--
-- Tilgangsreglene (RLS) stopper allerede uinnloggede: reglene for disse tabellene gjelder bare
-- innloggede, så en uinnlogget får 0 rader. Men Supabase gir rollen anon tillatelse til å spørre
-- på alle tabeller som standard. Fjerner vi den tillatelsen også, lekker ingenting selv om noen
-- en gang legger til en regel og glemmer «to authenticated».
--
-- Nettsiden merker ingen forskjell: den spør bare etter disse tabellene når du er logget inn.
-- Det som fortsatt er åpent for uinnloggede (frilansere, oppdrag, omtaler, innlegg, liker og
-- kommentarer, og å sende inn feilmeldinger), røres ikke.
-- ============================================================

revoke all on public.profiles from anon;
revoke all on public.offers from anon;
revoke all on public.orders from anon;
revoke all on public.messages from anon;
revoke all on public.saved from anon;

do $$
begin
  if to_regclass('public.saved_folders') is not null then
    execute 'revoke all on public.saved_folders from anon';
  end if;
  if to_regclass('public.push_subscriptions') is not null then
    execute 'revoke all on public.push_subscriptions from anon';
  end if;
end $$;
