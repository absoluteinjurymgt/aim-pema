-- ============================================================================
-- AIM Assessments — amend-in-progress tracking (Item 70)
-- Paste this whole file into the Supabase SQL editor and run once.
-- Safe to re-run: the statement is idempotent.
--
-- Sequencing is forgiving: every write that touches this column retries
-- without it, so nothing breaks before this runs — but the queue's
-- "Amend in progress — needs refinalising" badge only appears once the
-- column exists.
-- ============================================================================

-- Stamped when a finalised/exported assessment is reopened for amendment
-- (any type), cleared by the refinalise. While set with status
-- 'fieldwork_complete', the queue shows the distinct mid-amend badge instead
-- of the ordinary fieldwork chip, so a reopened report can no longer sit
-- unnoticed in the wrong state (the 13:24 FCE incident).
alter table public.appointments
  add column if not exists amended_at timestamptz;
