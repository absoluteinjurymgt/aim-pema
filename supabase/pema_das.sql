-- ============================================================================
-- AIM Assessments — PEMA Drug & Alcohol Screen (Item 37)
-- Paste this whole file into the Supabase SQL editor and run once.
-- Safe to re-run: both statements are idempotent.
--
-- !! SEQUENCING: run this BEFORE (or immediately with) the matching deploy.
-- Creating a PEMA booking in the new app writes appointments.pema_config, so
-- booking a PEMA fails loudly until this column exists. (Opening an existing
-- PEMA is safe either way — the app falls back and treats DAS as off.)
-- ============================================================================

-- Per-booking PEMA configuration, mirroring fce_config / pefa_config.
-- Shape: { "das": true | false } — resolved at booking creation from the
-- client's default, immutable afterwards. Bookings created before this
-- column existed read as DAS off.
alter table public.appointments
  add column if not exists pema_config jsonb;

-- Enable the DAS default for Foundation Civil & Mining specifically.
-- (default_config is the same jsonb that already carries the FCE/PEFA
-- section defaults; every other client stays off by default.)
update public.clients
set default_config = jsonb_set(
      coalesce(default_config, '{}'::jsonb),
      '{pema}',
      coalesce(default_config -> 'pema', '{}'::jsonb) || '{"das": true}'::jsonb,
      true)
where name ilike '%foundation civil%mining%';

-- Verify: should return one row with pema_das = true
select name, default_config -> 'pema' ->> 'das' as pema_das
from public.clients
where name ilike '%foundation civil%mining%';
