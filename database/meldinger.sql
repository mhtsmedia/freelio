-- ============================================================
-- Behold samtaler når en kunde sletter kontoen
-- Kjør denne én gang i SQL Editor. Den kan kjøres flere ganger.
-- ============================================================

-- Samtaler, bestillinger og omtaler blir stående når en kunde sletter kontoen sin.
-- Frilanseren ser dem fortsatt, med navnet «Slettet bruker».
alter table public.orders drop constraint if exists orders_customer_id_fkey;
alter table public.messages drop constraint if exists messages_customer_id_fkey;
alter table public.reviews drop constraint if exists reviews_author_id_fkey;

create or replace function public.delete_my_account()
returns void language sql security definer set search_path = public as $$
  update public.reviews set author_name = 'Tidligere kunde' where author_id = auth.uid();
  delete from auth.users where id = auth.uid();
$$;
