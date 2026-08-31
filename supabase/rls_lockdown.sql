-- ============================================================================
-- AIM Assessments — full RLS lockdown (PEMA + FCE + PEFA)
-- Paste this whole file into the Supabase SQL editor and run once.
-- Safe to re-run: every statement is guarded (drop if exists / create or replace).
--
-- !! SEQUENCING: run this AFTER the matching app version is live on
-- pema.absoluteim.com.au (the app must contain the patient_* RPC calls —
-- check that "Loading your questionnaire" still works on a token URL after
-- deploy, then run this). Running it against the OLD app breaks the patient
-- questionnaire flow until the deploy lands.
--
-- Access model implemented:
--   anon (patient token URLs, PEMA only)
--     - NO direct table access at all. The two patient operations go through
--       SECURITY DEFINER functions that take the token as a parameter,
--       validate it server-side, and expose only the columns/writes the
--       questionnaire needs.
--   authenticated (logged-in clinicians)
--     - appointments / clients / fce_tasks / clinician_progress: full CRUD
--     - questionnaire_responses: SELECT + DELETE (the only writes the portal
--       performs; INSERT happens via the patient RPC)
--     - storage bucket pema-reports: read / upload / overwrite / delete
-- ============================================================================


-- ─── 1. Patient RPCs (SECURITY DEFINER — the only anon surface) ──────────────
-- Serves: initTokenMode() — loads the questionnaire header for a token URL.
-- Returns only the columns the questionnaire pre-fill uses; NULL for an
-- unknown token or a non-PEMA appointment (FCE/PEFA have no patient flow).
create or replace function public.patient_get_appointment(p_token text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'patient_first_name',    a.patient_first_name,
    'patient_last_name',     a.patient_last_name,
    'appointment_date',      a.appointment_date,
    'appointment_time',      a.appointment_time,
    'position_applied_for',  a.position_applied_for,
    'site',                  a.site,
    'client_name',           a.client_name,
    'client_classification', a.client_classification,
    'status',                a.status,
    'expires_at',            a.expires_at
  )
  from appointments a
  where a.token = p_token
    and coalesce(a.assessment_type, 'pema') = 'pema';
$$;

-- Serves: submitTokenQuestionnaire() — one-shot submit: stores the response
-- and moves the appointment to 'complete'. Refuses unknown tokens and
-- appointments that are already past the questionnaire stage, so the anon key
-- can never touch any other status or any other row/column.
create or replace function public.patient_submit_questionnaire(p_token text, p_response jsonb)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
begin
  select status into v_status
  from appointments
  where token = p_token
    and coalesce(assessment_type, 'pema') = 'pema';

  if v_status is null then
    raise exception 'invalid token';
  end if;
  if v_status in ('complete', 'finalised', 'exported', 'expired') then
    raise exception 'questionnaire already submitted';
  end if;

  -- one response per token: replace any partial earlier attempt
  delete from questionnaire_responses where token = p_token;
  insert into questionnaire_responses (token, response_data)
  values (p_token, p_response);

  update appointments set status = 'complete' where token = p_token;
  return true;
end;
$$;

-- Functions default to EXECUTE for public — restrict to exactly the roles used.
revoke all on function public.patient_get_appointment(text) from public;
revoke all on function public.patient_submit_questionnaire(text, jsonb) from public;
grant execute on function public.patient_get_appointment(text) to anon, authenticated;
grant execute on function public.patient_submit_questionnaire(text, jsonb) to anon, authenticated;


-- ─── 2. Drop every existing permissive / temporary policy (exact names) ──────
-- Names verified against live pg_policies on 2026-08-31.
-- Original PEMA build ("using (true)" for role public = anon AND authenticated):
drop policy if exists "anon access" on public.appointments;
drop policy if exists "anon access" on public.questionnaire_responses;
drop policy if exists "anon access" on public.clinician_progress;
-- FCE Phase 1 temporary policies:
drop policy if exists "clients_authenticated_all_TEMP" on public.clients;
drop policy if exists "fce_tasks_authenticated_all_TEMP" on public.fce_tasks;
-- The half-applied token-header lockdown (checks request.headers x-pema-token;
-- superseded by the patient RPCs — dead once this file runs):
drop policy if exists "authenticated full access" on public.appointments;
drop policy if exists "authenticated full access" on public.questionnaire_responses;
drop policy if exists "authenticated full access" on public.clinician_progress;
drop policy if exists "anon select own appointment by token" on public.appointments;
drop policy if exists "anon update own appointment by token" on public.appointments;
drop policy if exists "anon insert own response by token" on public.questionnaire_responses;
-- The 2026-08-31 emergency permissive layer (added to restore service after
-- the half-applied lockdown broke the patient flow — the reason the patient
-- tables are currently wide open):
drop policy if exists "anon_select_appointments" on public.appointments;
drop policy if exists "anon_update_appointments" on public.appointments;
drop policy if exists "anon_insert_questionnaire" on public.questionnaire_responses;
drop policy if exists "anon_select_questionnaire" on public.questionnaire_responses;
drop policy if exists "anon_update_questionnaire" on public.questionnaire_responses;


-- ─── 3. Enable RLS everywhere (no-op where already enabled) ──────────────────
alter table public.appointments            enable row level security;
alter table public.questionnaire_responses enable row level security;
alter table public.clinician_progress      enable row level security;
alter table public.clients                 enable row level security;
alter table public.fce_tasks               enable row level security;


-- ─── 4. Authenticated (clinician portal) policies ────────────────────────────
-- appointments: create (createAppointment), list (loadUpcomingAppointments),
-- read by token (startPEMA/startFCE/startPEFA/amend/export), update status +
-- pdf_path/finalised_at/exported_at (finalise, fieldwork, expiry, amend).
drop policy if exists "clinicians full access" on public.appointments;
create policy "clinicians full access" on public.appointments
  for all to authenticated using (true) with check (true);

-- questionnaire_responses: read (startPEMA, recovery banner), delete
-- (finalise cleanup). No portal INSERT/UPDATE exists — not granted.
drop policy if exists "clinicians read responses" on public.questionnaire_responses;
create policy "clinicians read responses" on public.questionnaire_responses
  for select to authenticated using (true);
drop policy if exists "clinicians delete responses" on public.questionnaire_responses;
create policy "clinicians delete responses" on public.questionnaire_responses
  for delete to authenticated using (true);

-- clinician_progress: autosave upsert, cross-device restore, cleanup on
-- finalise/expiry/clear-session.
drop policy if exists "clinicians full access" on public.clinician_progress;
create policy "clinicians full access" on public.clinician_progress
  for all to authenticated using (true) with check (true);

-- clients: portal client management (list, create, edit incl. logo_base64,
-- delete) + FCE/PEFA client selection.
drop policy if exists "clinicians full access" on public.clients;
create policy "clinicians full access" on public.clients
  for all to authenticated using (true) with check (true);

-- fce_tasks: task library list, add custom task, remove task.
drop policy if exists "clinicians full access" on public.fce_tasks;
create policy "clinicians full access" on public.fce_tasks
  for all to authenticated using (true) with check (true);

-- anon: NO table policies anywhere. RLS default-deny does the rest — the two
-- patient RPCs above are the entire anonymous surface.


-- ─── 5. Storage ──────────────────────────────────────────────────────────────
-- pema-reports: recreate the three existing authenticated policies unchanged
-- and add the missing UPDATE policy — refinalising an amended assessment
-- re-uploads to the same path with x-upsert, which performs an UPDATE.
drop policy if exists "authenticated read reports" on storage.objects;
create policy "authenticated read reports" on storage.objects
  for select to authenticated using (bucket_id = 'pema-reports');
drop policy if exists "authenticated upload reports" on storage.objects;
create policy "authenticated upload reports" on storage.objects
  for insert to authenticated with check (bucket_id = 'pema-reports');
drop policy if exists "authenticated update reports" on storage.objects;
create policy "authenticated update reports" on storage.objects
  for update to authenticated
  using (bucket_id = 'pema-reports') with check (bucket_id = 'pema-reports');
drop policy if exists "authenticated delete reports" on storage.objects;
create policy "authenticated delete reports" on storage.objects
  for delete to authenticated using (bucket_id = 'pema-reports');

-- client-logos: the app stores logos as base64 in clients.logo_base64 and
-- never references this bucket — the anon policies serve no code path.
-- Dropped as dead attack surface. (The bucket itself is left in place.)
drop policy if exists "anon read client logos"   on storage.objects;
drop policy if exists "anon update client logos" on storage.objects;
drop policy if exists "anon upload client logos" on storage.objects;
