-- 00_generate.sql
-- Reproducible synthetic "Netflix-style" playback dataset, pure DuckDB (no Python).
-- Rebuilds titles / profiles / playback_events from scratch every run (idempotent).
--
-- Run from the repo root, using your existing DuckDB container:
--   docker compose run --rm -v "$PWD/challenges:/challenges" duckdb \
--     /data/warehouse.duckdb -c ".read /challenges/01-sql-streaming-metrics/00_generate.sql"
--
-- ...or, with the DuckDB CLI on the host:
--   duckdb data/warehouse.duckdb -c ".read challenges/01-sql-streaming-metrics/00_generate.sql"
--
-- Window: 2026-05-01 + 35 days (5 weeks) so weekly retention cohorts exist.
-- NOTE: DuckDB casts DOUBLE->INT by ROUNDING, so floor() is used for bucket indexes.

SELECT setseed(0.42);

-- ---------------------------------------------------------------- titles (dim)
CREATE OR REPLACE TABLE titles AS
WITH base AS (
  SELECT t AS title_id, random() AS r_type, random() AS r_rt, random() AS r_rel
  FROM range(1, 41) AS g(t)
)
SELECT
  title_id,
  'Title ' || lpad(title_id::VARCHAR, 3, '0')                       AS title_name,
  CASE WHEN r_type < 0.5 THEN 'film' ELSE 'series' END              AS content_type,
  (DATE '2024-01-01' + floor(r_rel * 760)::INT)                     AS release_date,
  CASE WHEN r_type < 0.5 THEN floor(4800 + r_rt * 4800)::INT        -- films 80–160 min
                         ELSE floor(1500 + r_rt * 1800)::INT END    -- episodes 25–55 min
    AS runtime_sec
FROM base;

-- -------------------------------------------------------------- profiles (dim)
CREATE OR REPLACE TABLE profiles AS
WITH base AS (
  SELECT p AS profile_id, random() AS r_c, random() AS r_join, random() AS r_ret
  FROM range(1, 3001) AS g(p)
)
SELECT
  profile_id,
  (['US','US','US','GB','DE','BR','IN','JP','FR','CA'])[floor(r_c*10)::INT + 1] AS country,
  (DATE '2026-05-01' + floor(r_join*28)::INT)                                   AS join_date,
  0.30 + r_ret*0.65                                                             AS retention_p
FROM base;

-- ----------------------------------------------- which weeks each profile is active
CREATE OR REPLACE TEMP TABLE active_weeks AS
WITH wk AS (
  SELECT pr.profile_id, pr.retention_p,
         floor((pr.join_date - DATE '2026-05-01')/7.0)::INT AS join_week,
         w AS week_offset, random() AS r
  FROM profiles pr, range(0,5) AS g(w)
)
SELECT profile_id, retention_p, (join_week + week_offset) AS active_week
FROM wk
WHERE (join_week + week_offset) <= 4
  AND (week_offset = 0 OR r < pow(retention_p, week_offset));

-- ------------------------------------------------------ sessions (one "view" each)
CREATE OR REPLACE TEMP TABLE views AS
WITH s AS (
  SELECT aw.profile_id, aw.active_week, k AS sess_k,
         random() AS r_keep, random() AS r_day, random() AS r_title, random() AS r_frac,
         random() AS r_hour, random() AS r_split, random() AS r_gap, random() AS r_dev,
         random() AS r_cut
  FROM active_weeks aw, range(1,4) AS g(k)            -- up to 3 sessions / active week
), kept AS (
  SELECT * FROM s WHERE r_keep < 0.8
), withtitle AS (
  SELECT
    row_number() OVER () AS session_id,
    profile_id,
    floor(r_title*40)::INT + 1                                       AS title_id,
    (DATE '2026-05-01' + (active_week*7 + floor(r_day*7)::INT)::INT)  AS sess_date,
    (8 + floor(r_hour*14)::INT)                                       AS start_hour,   -- 08:00–21:00
    least(1.0, 0.15 + r_frac*1.05)                                    AS watch_frac,
    CASE WHEN r_split < 0.35 THEN 2 ELSE 1 END                        AS n_sittings,
    (35 + floor(r_gap*85)::INT)                                       AS gap_min,      -- 35–120 min
    (['tv','mobile','web','tablet'])[floor(r_dev*4)::INT + 1]         AS device,
    r_cut
  FROM kept
)
SELECT
  v.session_id, v.profile_id, v.title_id, v.sess_date, v.start_hour, v.device,
  v.n_sittings, v.gap_min,
  ti.runtime_sec, ti.content_type,
  greatest(60, round(v.watch_frac * ti.runtime_sec)::INT)  AS watch_sec,
  (v.watch_frac >= 0.9)                                     AS completed,
  CASE WHEN v.n_sittings = 2
       THEN greatest(300, round(greatest(60, round(v.watch_frac*ti.runtime_sec)::INT)
                                 * (0.4 + 0.2*v.r_cut))::INT)
  END                                                       AS cut_sec
FROM withtitle v JOIN titles ti USING (title_id);

-- --------------------------------------------------- expand to heartbeat events
CREATE OR REPLACE TABLE playback_events AS
WITH sit AS (
  SELECT v.session_id, v.profile_id, v.title_id, v.device, v.gap_min,
         v.watch_sec, v.cut_sec, v.n_sittings,
         (v.sess_date + to_hours(v.start_hour))::TIMESTAMP AS session_start,
         s AS sitting_idx
  FROM views v, range(1,3) AS g(s)
  WHERE s <= v.n_sittings
), sit2 AS (
  SELECT *,
    CASE WHEN n_sittings=1 OR sitting_idx=1 THEN 0 ELSE cut_sec END        AS pos_start,
    CASE WHEN n_sittings=1 THEN watch_sec
         WHEN sitting_idx=1 THEN cut_sec
         ELSE watch_sec - cut_sec END                                      AS sitting_sec,
    CASE WHEN sitting_idx=1 THEN session_start
         ELSE session_start + to_seconds(cut_sec + gap_min*60) END         AS sitting_wall_start
  FROM sit
), hb AS (
  SELECT session_id, profile_id, title_id, device, sitting_idx, n_sittings,
         pos_start + i*300                                AS position_sec,
         sitting_wall_start + to_seconds(i*300)           AS event_ts
  FROM sit2,
       UNNEST(range(0, (floor(sitting_sec/300))::BIGINT + 1)) AS u(i)
), ev AS (
  SELECT *,
    row_number() OVER (PARTITION BY session_id ORDER BY sitting_idx, position_sec) AS rn_g,
    count(*)     OVER (PARTITION BY session_id)                                     AS n_g,
    row_number() OVER (PARTITION BY session_id, sitting_idx ORDER BY position_sec)  AS rn_s,
    count(*)     OVER (PARTITION BY session_id, sitting_idx)                        AS n_s
  FROM hb
)
SELECT
  row_number() OVER (ORDER BY event_ts, session_id, position_sec) AS event_id,
  ev.profile_id,
  ev.title_id,
  pr.country,
  ev.device,
  CASE
    WHEN rn_g = 1                                          THEN 'start'
    WHEN rn_g = n_g                                        THEN 'stop'
    WHEN n_sittings = 2 AND sitting_idx = 1 AND rn_s = n_s THEN 'pause'
    WHEN n_sittings = 2 AND sitting_idx = 2 AND rn_s = 1   THEN 'resume'
    ELSE 'heartbeat'
  END                                                     AS event_type,
  ev.event_ts,
  ev.position_sec
FROM ev JOIN profiles pr USING (profile_id);
