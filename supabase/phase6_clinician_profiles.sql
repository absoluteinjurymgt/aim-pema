-- ============================================================================
-- AIM Assessments — Phase 6: clinician profiles (prefilled sign-off)
-- Paste into the Supabase SQL editor and run once (safe to re-run).
-- ============================================================================

create table if not exists public.clinician_profiles (
  user_id uuid primary key references auth.users(id),
  full_name text not null,
  qualification text not null default 'Physiotherapist',
  provider_number text,
  created_at timestamptz default now()
);

alter table public.clinician_profiles enable row level security;

-- All authenticated clinicians can read every profile (admin list); each user
-- can insert/update only their own row.
do $$ begin
  create policy "clinician_profiles_read_all" on public.clinician_profiles
    for select to authenticated using (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "clinician_profiles_insert_own" on public.clinician_profiles
    for insert to authenticated with check (user_id = auth.uid());
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "clinician_profiles_update_own" on public.clinician_profiles
    for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
exception when duplicate_object then null; end $$;

-- ─── Seed template (optional) ────────────────────────────────────────────────
-- To set up existing clinicians in one go, look up their auth user ids:
--   select id, email from auth.users order by email;
-- then insert a row per clinician (runs as the table owner, so RLS does not
-- block seeding from the SQL editor):
--
-- insert into public.clinician_profiles (user_id, full_name, qualification, provider_number)
-- values
--   ('<auth-user-uuid>', 'Devon Soutar', 'Physiotherapist', 'PHY0012345')
-- on conflict (user_id) do update
--   set full_name = excluded.full_name,
--       qualification = excluded.qualification,
--       provider_number = excluded.provider_number;
