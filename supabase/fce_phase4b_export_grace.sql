-- ============================================================================
-- AIM Assessments — deferred PDF deletion on export (72-hour grace period)
-- Paste into the Supabase SQL editor and run once (safe to re-run).
--
-- !! Run this BEFORE deploying the matching app version: marking a report as
-- exported now writes exported_at, and fails visibly if the column is missing.
-- ============================================================================

alter table public.appointments
  add column if not exists exported_at timestamptz;
