-- ============================================================================
-- AIM Assessments — patient date-of-birth corrections (Item 63)
-- Paste this whole file into the Supabase SQL editor and run once.
-- Safe to re-run: the statement is idempotent.
--
-- Sequencing is forgiving: the app retries without this column wherever it
-- writes it, so nothing breaks before this runs — but DOB corrections only
-- persist to the appointment record (and reach other devices / future loads)
-- once the column exists.
-- ============================================================================

-- Authoritative corrected date of birth. Bookings do not collect a DOB (the
-- PEMA patient enters it in the questionnaire; FCE/PEFA clinicians type it on
-- screen), so this column is populated only by clinician corrections and the
-- FCE/PEFA finalise write-back. When present, it wins over the questionnaire
-- response's original entry on load.
alter table public.appointments
  add column if not exists patient_dob date;
