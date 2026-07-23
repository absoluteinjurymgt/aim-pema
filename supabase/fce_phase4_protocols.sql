-- ============================================================================
-- AIM Assessments — FCE Module Phase 4: protocol texts (totals, not reps)
-- Paste into the Supabase SQL editor and run once (safe to re-run).
--
-- NOTE: these UPDATEs overwrite classification_config and base task protocols
-- wholesale — any protocol edits made in the admin UI since Phase 2 will be
-- replaced. Wordings are provisional; the owner can edit them in the admin UI
-- afterwards (per-classification overrides) without touching SQL again.
--
-- hr_count sense-check against the new wordings (hr_count = HR checkpoints):
--   OK      Walking Medium 300m / 3 checkpoints (every 100m)
--   OK      Walking Heavy 500m / 5 checkpoints (every 100m)
--   OK      Climbing Medium ~80 steps / 3 · Heavy ~120 steps / 5 (24/checkpoint)
--   OK      Digging 2 min / 2 · 3 min / 3 (per-minute)
--   OK      Pushing + Pulling 4 (labelled pull/push readings)
--   OK      Lifting / Carrying 4 (increasing weights)
--   ⚠ FLAG  Machinery Medium: 'Machine/plant access and egress' with 3 HR
--           checkpoints — wording no longer implies repetitions; confirm 3 is
--           intended or reduce hr_count.
--   ⚠ FLAG  Machinery Heavy: '– repeated' with 5 HR checkpoints — repetition
--           count is unspecified; confirm 5 matches the field protocol.
-- ============================================================================

-- ─── 1. RTL classification_config ────────────────────────────────────────────
update public.clients set
  classification_config = '{
    "Medium": {
      "max_weight_kg": 19,
      "task_overrides": {
        "Walking – Even Terrain":           {"protocol": "Walking 300m on even terrain", "hr_count": 3},
        "Walking – Uneven/Sloped Terrain":  {"protocol": "Walking 300m over uneven/sloped coal terrain", "hr_count": 3},
        "Climbing + Stepping":              {"protocol": "Climbing approx. 80 steps", "hr_count": 3},
        "Machinery + Plant Access/Egress":  {"protocol": "Machine/plant access and egress", "hr_count": 3},
        "Digging + Shoveling":              {"protocol": "2 minutes of digging/shoveling", "hr_count": 2, "hr_labels": ["1 min HR", "2 min HR"]},
        "Hosing + Washing":                 {"protocol": "2 minutes of hosing @ various flow rates"},
        "Pushing + Pulling":                {"protocol": "Grasping/pulling/pushing small hoses/joystick control"},
        "Lifting":                          {"protocol": "Lifting increasing weight up to max 19kgs"},
        "Carrying":                         {"protocol": "Carrying increasing weight up to max 19kgs"}
      }
    },
    "Heavy": {
      "max_weight_kg": 32,
      "task_overrides": {
        "Walking – Even Terrain":           {"protocol": "Walking 500m on even terrain", "hr_count": 5},
        "Walking – Uneven/Sloped Terrain":  {"protocol": "Walking 500m over uneven/sloped coal terrain", "hr_count": 5},
        "Climbing + Stepping":              {"protocol": "Climbing approx. 120 steps", "hr_count": 5},
        "Machinery + Plant Access/Egress":  {"protocol": "Machine/plant access and egress – repeated", "hr_count": 5},
        "Digging + Shoveling":              {"protocol": "3 minutes of digging/shoveling", "hr_count": 3, "hr_labels": ["1 min HR", "2 min HR", "3 min HR"]},
        "Hosing + Washing":                 {"protocol": "3 minutes of hosing @ various flow rates"},
        "Pushing + Pulling":                {"protocol": "Grasping + pulling hoses/valve | pushing vehicle tyre/valve"},
        "Lifting":                          {"protocol": "Lifting increasing weight up to max 32kgs"},
        "Carrying":                         {"protocol": "Carrying increasing weight up to max 32kgs"}
      }
    }
  }'::jsonb
where name = 'RTL';

-- ─── 2. Generic / Ad Hoc classification_config (standard tasks only) ─────────
update public.clients set
  classification_config = '{
    "Medium": {
      "max_weight_kg": 19,
      "task_overrides": {
        "Walking – Even Terrain":           {"protocol": "Walking 300m on even terrain", "hr_count": 3},
        "Walking – Uneven/Sloped Terrain":  {"protocol": "Walking 300m over uneven/sloped coal terrain", "hr_count": 3},
        "Climbing + Stepping":              {"protocol": "Climbing approx. 80 steps", "hr_count": 3},
        "Pushing + Pulling":                {"protocol": "Grasping/pulling/pushing small hoses/joystick control"},
        "Lifting":                          {"protocol": "Lifting increasing weight up to max 19kgs"},
        "Carrying":                         {"protocol": "Carrying increasing weight up to max 19kgs"}
      }
    },
    "Heavy": {
      "max_weight_kg": 32,
      "task_overrides": {
        "Walking – Even Terrain":           {"protocol": "Walking 500m on even terrain", "hr_count": 5},
        "Walking – Uneven/Sloped Terrain":  {"protocol": "Walking 500m over uneven/sloped coal terrain", "hr_count": 5},
        "Climbing + Stepping":              {"protocol": "Climbing approx. 120 steps", "hr_count": 5},
        "Pushing + Pulling":                {"protocol": "Grasping + pulling hoses/valve | pushing vehicle tyre/valve"},
        "Lifting":                          {"protocol": "Lifting increasing weight up to max 32kgs"},
        "Carrying":                         {"protocol": "Carrying increasing weight up to max 32kgs"}
      }
    }
  }'::jsonb
where name = 'Generic / Ad Hoc';

-- ─── 3. Base task protocols (classification-neutral fallbacks) ───────────────
-- Used when a classification has no override for the task.
update public.fce_tasks set protocol = 'Walking on even terrain'
  where name = 'Walking – Even Terrain' and client_id is null;
update public.fce_tasks set protocol = 'Walking over uneven/sloped coal terrain'
  where name = 'Walking – Uneven/Sloped Terrain' and client_id is null;
update public.fce_tasks set protocol = 'Climbing stairs'
  where name = 'Climbing + Stepping' and client_id is null;
update public.fce_tasks set protocol = 'Grasping/pulling/pushing small hoses/joystick control'
  where name = 'Pushing + Pulling' and client_id is null;
update public.fce_tasks set protocol = 'Lifting increasing weight up to classification maximum'
  where name = 'Lifting' and client_id is null;
update public.fce_tasks set protocol = 'Carrying increasing weight up to classification maximum'
  where name = 'Carrying' and client_id is null;
update public.fce_tasks set protocol = 'Machine/plant access and egress'
  where name = 'Machinery + Plant Access/Egress';
update public.fce_tasks set protocol = '2 minutes of digging/shoveling'
  where name = 'Digging + Shoveling';
update public.fce_tasks set protocol = '2 minutes of hosing @ various flow rates'
  where name = 'Hosing + Washing';
