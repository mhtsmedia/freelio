-- ============================================================
-- Innlogging med Google og telefon
-- Nye brukere får navn fra Google, eller «Ny bruker» når de logger inn med telefon
-- (telefonbrukere har ingen e-post). Siden ber dem skrive navnet sitt etterpå.
-- Kjør denne én gang i SQL Editor. Den kan kjøres flere ganger.
-- ============================================================

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name)
  values (new.id, left(coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'Ny bruker'), 60))
  on conflict (id) do nothing;
  return new;
end $$;
