-- ============================================================================
-- AIM Assessments — Phase 5: PEFA (Pre-Employment Functional Assessment)
-- Paste into the Supabase SQL editor and run once (safe to re-run).
-- Run BEFORE deploying the matching app version (PEFA bookings write
-- assessment_type='pefa' and pefa_config).
-- ============================================================================

-- ─── 1. assessment_type gains 'pefa' ─────────────────────────────────────────
alter table public.appointments
  drop constraint if exists appointments_assessment_type_check;
alter table public.appointments
  add constraint appointments_assessment_type_check
  check (assessment_type in ('pema', 'fce', 'pefa'));

-- ─── 2. Resolved per-booking PEFA config (same pattern as fce_config) ────────
-- { "classification": "Medium", "max_weight_kg": 19,
--   "sections": { "rom": true, "postural_analysis": true, "special_msk": true,
--                 "grip_strength": true, "climbing": true, "step_test": true,
--                 "postural_tolerances": true, "manual_handling": true } }
-- The always-on spine (consent, history questionnaire, baseline vitals,
-- outcome, sign-off) has no toggle keys. PEFA classifications reuse
-- clients.classification_config weights; only max_weight_kg applies (FCE task
-- protocol overrides are ignored).
alter table public.appointments
  add column if not exists pefa_config jsonb;

-- ─── 3. Seed PEFA defaults on clients.default_config (everything on) ─────────
-- jsonb || merges at the top level: the existing FCE keys (e.g. RTL's
-- step_test:false) are preserved; only the "pefa" branch is added/replaced.
-- Missing section key = enabled, so {} means ALL eight optional sections on
-- (rom, postural_analysis, special_msk, grip_strength, climbing, step_test,
-- postural_tolerances, manual_handling).
update public.clients
  set default_config = coalesce(default_config, '{}'::jsonb) || '{"pefa": {"sections": {}}}'::jsonb
  where name in ('RTL', 'Generic / Ad Hoc');
