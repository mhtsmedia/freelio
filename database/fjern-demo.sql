-- ============================================================
-- Fjern demo-frilansere og demo-oppdrag
-- Sletter alt som ble lagt inn som eksempel (demo = true), med tilbud,
-- bestillinger, meldinger og omtaler som hører til dem.
-- Ekte brukere og deres data blir ikke rørt.
-- ============================================================

delete from public.jobs where demo = true;
delete from public.freelancers where demo = true;
