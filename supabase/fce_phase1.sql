-- ============================================================================
-- AIM Assessments — FCE Module Phase 1
-- Paste this whole file into the Supabase SQL editor and run once.
-- Safe to re-run: columns/tables use IF NOT EXISTS, seeds are guarded.
-- ============================================================================

-- ─── 1. appointments: assessment type + per-referral FCE config ─────────────
alter table public.appointments
  add column if not exists assessment_type text not null default 'pema';

alter table public.appointments
  add column if not exists fce_config jsonb;

do $$ begin
  alter table public.appointments
    add constraint appointments_assessment_type_check
    check (assessment_type in ('pema','fce'));
exception when duplicate_object then null; end $$;

-- ─── 2. clients (replaces per-device localStorage client profiles) ──────────
-- NOTE: email / invoice_email / classifications are additions beyond the brief:
-- the existing PEMA UI stores these per client, so they must live in the cloud
-- row for PEMA client selection to keep working.
create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  logo_base64 text,                                   -- data URL, synced across devices
  determination_template text default 'standard',
  default_config jsonb,                               -- default FCE section/task toggles
  email text,                                         -- PEMA: default report email
  invoice_email text,                                 -- PEMA: invoicing email
  classifications jsonb default '["Medium (9–23 kg occasional)"]'::jsonb,  -- PEMA classifications offered
  created_at timestamptz default now()
);

-- ─── 3. fce_tasks (task library) ─────────────────────────────────────────────
-- fields jsonb keys:
--   hr_style: "reps" | "intervals"      (omit for tasks with no generic HR block)
--   hr_count: int                        (number of rep/interval HR fields)
--   hr_labels: [text]                    (optional label overrides, e.g. Pull Rep 1)
--   manual_handling_rating: bool         (stance/posture/control 1–4)
--   restriction_rating: bool             (Unrestricted/Minimal/Moderate/Unable)
--   extra_fields: [{key,label,type}]     (task-specific inputs)
-- Every task always renders: baseline HR, pain 0–10, RPE 0–10, comments.
-- Deliberately NO time-to-complete and NO 1-minute-post-HR anywhere.
create table if not exists public.fce_tasks (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references public.clients(id) on delete cascade,  -- null = standard task
  name text not null,
  protocol text,
  sort_order int default 0,
  fields jsonb not null,
  active boolean default true
);

-- ─── 4. RLS ──────────────────────────────────────────────────────────────────
-- !! TEMPORARY policies — mirrors the current permissive clinician-side model
-- used by appointments (any authenticated user, full access). Full RLS
-- lockdown is a separate upcoming task. Patients (anon token URLs) get no
-- access to these tables; the patient flow only reads appointments.
alter table public.clients enable row level security;
alter table public.fce_tasks enable row level security;

do $$ begin
  create policy "clients_authenticated_all_TEMP" on public.clients
    for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "fce_tasks_authenticated_all_TEMP" on public.fce_tasks
    for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;

-- ─── 5. Seed: client rows ─────────────────────────────────────────────────────
insert into public.clients (name, determination_template, default_config, classifications)
values (
  'RTL',
  'standard',
  '{"sections": {"step_test": false}}'::jsonb,
  '["Medium (9–23 kg occasional)","Heavy (23–45 kg occasional)","Very Heavy (45+ kg occasional)"]'::jsonb
)
on conflict (name) do nothing;

insert into public.clients (name, determination_template, default_config, classifications)
values (
  'Generic / Ad Hoc',
  'standard',
  '{}'::jsonb,     -- everything on (missing key = enabled)
  '["Medium (9–23 kg occasional)"]'::jsonb
)
on conflict (name) do nothing;

-- ─── 6. Seed: standard task library (client_id null → all clients) ───────────
insert into public.fce_tasks (client_id, name, protocol, sort_order, fields)
select null, v.name, v.protocol, v.sort_order, v.fields::jsonb
from (values
  ('Walking – Even Terrain',
   '3 repetitions of 100m (500m total)', 10,
   '{"hr_style":"reps","hr_count":3,"restriction_rating":true}'),
  ('Walking – Uneven/Sloped Terrain',
   '3 repetitions over 60m coal terrain (300m)', 20,
   '{"hr_style":"reps","hr_count":3,"restriction_rating":true}'),
  ('Climbing + Stepping',
   '3 repetitions of 24 steps – flight of stairs', 30,
   '{"hr_style":"reps","hr_count":3,"restriction_rating":true}'),
  ('Pushing + Pulling',
   'grasping/pulling/pushing small hoses/joystick control', 40,
   '{"hr_style":"reps","hr_count":4,"hr_labels":["Pull Rep 1 HR","Pull Rep 2 HR","Push Rep 1 HR","Push Rep 2 HR"],"manual_handling_rating":true,"restriction_rating":true,"extra_fields":[{"key":"push_object","label":"Push Object","type":"text"},{"key":"pull_object","label":"Pull Object","type":"text"}]}'),
  ('Lifting',
   'lifting increasing weight up to classification maximum', 50,
   '{"hr_style":"reps","hr_count":4,"manual_handling_rating":true,"restriction_rating":true}'),
  ('Carrying',
   'carrying increasing weight up to classification maximum', 60,
   '{"hr_style":"reps","hr_count":4,"manual_handling_rating":true,"restriction_rating":true}')
) as v(name, protocol, sort_order, fields)
where not exists (
  select 1 from public.fce_tasks t where t.name = v.name and t.client_id is null
);

-- ─── 7. Seed: RTL-specific tasks ─────────────────────────────────────────────
insert into public.fce_tasks (client_id, name, protocol, sort_order, fields)
select c.id, v.name, v.protocol, v.sort_order, v.fields::jsonb
from public.clients c
cross join (values
  ('Machinery + Plant Access/Egress',
   '3 repetitions of machine/plant access/egress', 70,
   '{"hr_style":"reps","hr_count":3,"restriction_rating":true}'),
  ('Digging + Shoveling',
   '2 minutes of digging/shoveling', 80,
   '{"hr_style":"intervals","hr_count":2,"hr_labels":["1 min HR","2 min HR"],"manual_handling_rating":true,"restriction_rating":true,"extra_fields":[{"key":"material_type","label":"Material Type","type":"text"}]}'),
  ('Hosing + Washing',
   '2 minutes of hosing @ various flow rates', 90,
   '{"manual_handling_rating":true,"restriction_rating":true,"extra_fields":[{"key":"low_flow_hr","label":"Low Flow HR","type":"number"},{"key":"mod_flow_hr","label":"Moderate Flow HR","type":"number"},{"key":"high_flow_hr","label":"High Flow HR","type":"number"},{"key":"max_flow_rate_pct","label":"Max Flow Rate (%)","type":"number"}]}')
) as v(name, protocol, sort_order, fields)
where c.name = 'RTL'
and not exists (
  select 1 from public.fce_tasks t where t.name = v.name and t.client_id = c.id
);
