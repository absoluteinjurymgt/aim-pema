-- ============================================================================
-- AIM Assessments — FCE Module Phase 2: classification model
-- Paste into the Supabase SQL editor and run once (safe to re-run).
-- ============================================================================

-- ─── 1. clients.classification_config ───────────────────────────────────────
-- {
--   "<Classification>": {
--     "max_weight_kg": <int>,           -- applies to BOTH Lifting and Carrying
--     "task_overrides": {
--       "<task name>": { "protocol": "...", "hr_count": <int>, "hr_labels": [..] }
--     }
--   }
-- }
-- Anything not overridden falls back to the task's base fce_tasks values.
alter table public.clients
  add column if not exists classification_config jsonb;

-- ─── 2. RTL: Medium + Heavy ──────────────────────────────────────────────────
update public.clients set
  classifications = '["Medium","Heavy"]'::jsonb,
  classification_config = '{
    "Medium": {
      "max_weight_kg": 19,
      "task_overrides": {
        "Walking – Even Terrain":           {"protocol": "3 repetitions of 100m (500m total)", "hr_count": 3},
        "Walking – Uneven/Sloped Terrain":  {"protocol": "3 repetitions over 60m coal terrain (300m)", "hr_count": 3},
        "Climbing + Stepping":              {"protocol": "3 repetitions of 24 steps – flight of stairs", "hr_count": 3},
        "Machinery + Plant Access/Egress":  {"protocol": "3 repetitions of machine/plant access/egress", "hr_count": 3},
        "Digging + Shoveling":              {"protocol": "2 minutes of digging/shoveling", "hr_count": 2, "hr_labels": ["1 min HR", "2 min HR"]},
        "Hosing + Washing":                 {"protocol": "2 minutes of hosing @ various flow rates"},
        "Pushing + Pulling":                {"protocol": "grasping/pulling/pushing small hoses/joystick control"},
        "Lifting":                          {"protocol": "lifting increasing weight up to max 19kgs"},
        "Carrying":                         {"protocol": "carrying increasing weight up to max 19kgs"}
      }
    },
    "Heavy": {
      "max_weight_kg": 32,
      "task_overrides": {
        "Walking – Even Terrain":           {"protocol": "5 repetitions of 100m (500m total)", "hr_count": 5},
        "Walking – Uneven/Sloped Terrain":  {"protocol": "5 repetitions over 60m coal terrain (300m)", "hr_count": 5},
        "Climbing + Stepping":              {"protocol": "5 repetitions of 24 steps – flight of stairs", "hr_count": 5},
        "Machinery + Plant Access/Egress":  {"protocol": "5 repetitions of machine/plant access/egress", "hr_count": 5},
        "Digging + Shoveling":              {"protocol": "3 minutes of digging/shoveling", "hr_count": 3, "hr_labels": ["1 min HR", "2 min HR", "3 min HR"]},
        "Hosing + Washing":                 {"protocol": "3 minutes of hosing @ various flow rates"},
        "Pushing + Pulling":                {"protocol": "grasping + pulling hoses/valve | pushing vehicle tyre/valve"},
        "Lifting":                          {"protocol": "lifting increasing weight up to max 32kgs"},
        "Carrying":                         {"protocol": "carrying increasing weight up to max 32kgs"}
      }
    }
  }'::jsonb
where name = 'RTL';

-- ─── 3. Generic / Ad Hoc: RTL config cloned, standard tasks only ─────────────
-- (Machinery + Plant Access/Egress, Digging + Shoveling and Hosing + Washing
--  are RTL-specific tasks, so their overrides are dropped here.)
update public.clients set
  classifications = '["Medium","Heavy"]'::jsonb,
  classification_config = '{
    "Medium": {
      "max_weight_kg": 19,
      "task_overrides": {
        "Walking – Even Terrain":           {"protocol": "3 repetitions of 100m (500m total)", "hr_count": 3},
        "Walking – Uneven/Sloped Terrain":  {"protocol": "3 repetitions over 60m coal terrain (300m)", "hr_count": 3},
        "Climbing + Stepping":              {"protocol": "3 repetitions of 24 steps – flight of stairs", "hr_count": 3},
        "Pushing + Pulling":                {"protocol": "grasping/pulling/pushing small hoses/joystick control"},
        "Lifting":                          {"protocol": "lifting increasing weight up to max 19kgs"},
        "Carrying":                         {"protocol": "carrying increasing weight up to max 19kgs"}
      }
    },
    "Heavy": {
      "max_weight_kg": 32,
      "task_overrides": {
        "Walking – Even Terrain":           {"protocol": "5 repetitions of 100m (500m total)", "hr_count": 5},
        "Walking – Uneven/Sloped Terrain":  {"protocol": "5 repetitions over 60m coal terrain (300m)", "hr_count": 5},
        "Climbing + Stepping":              {"protocol": "5 repetitions of 24 steps – flight of stairs", "hr_count": 5},
        "Pushing + Pulling":                {"protocol": "grasping + pulling hoses/valve | pushing vehicle tyre/valve"},
        "Lifting":                          {"protocol": "lifting increasing weight up to max 32kgs"},
        "Carrying":                         {"protocol": "carrying increasing weight up to max 32kgs"}
      }
    }
  }'::jsonb
where name = 'Generic / Ad Hoc';
