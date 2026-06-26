-- 01_problems.sql — Theme 1 (SQL & query optimization), Netflix streaming-metrics accent.
-- Work top to bottom; they escalate. Attempt cold, THEN check 02_solutions.sql.
-- Tables (built by 00_generate.sql): playback_events(profile_id, title_id, country,
--   device, event_type ∈ {start,heartbeat,pause,resume,stop}, event_ts, position_sec),
--   titles(title_id, title_name, content_type, release_date, runtime_sec),
--   profiles(profile_id, country, join_date, retention_p).
-- Convention: each 'heartbeat' ≈ 5 minutes watched.


-- ── P1 · warm-up · window ranking ───────────────────────────────────────────────
-- For each country, the top 3 titles by total watch-minutes.
-- Output: country, title_id, watch_min, rnk (1..3).
-- Skills: aggregate + RANK/QUALIFY.



-- ── P2 · core · window frame ─────────────────────────────────────────────────────
-- For each title and day, the number of plays (a "play" = a 'start' event) AND a
-- 7-day trailing rolling sum of plays (today + previous 6 days).
-- Output: title_id, d, plays, plays_7d.
-- Skills: ROWS BETWEEN 6 PRECEDING AND CURRENT ROW.



-- ── P3 · core · LAG ──────────────────────────────────────────────────────────────
-- For each title, daily unique viewers and the day-over-day change vs the prior day.
-- Output: title_id, d, viewers, dod_change (NULL on the first day).
-- Skills: LAG over an ordered partition.



-- ── P4 · hard · sessionization (gap-and-islands) ─────────────────────────────────
-- A viewing session = consecutive events for the same (profile_id, title_id) where
-- each event is within 30 minutes of the previous one; a gap > 30 min starts a new
-- session. For the 20 profiles with the most sessions, return session count and the
-- average session length in minutes (last event ts − first event ts within a session).
-- Output: profile_id, sessions, avg_session_min.
-- Skills: LAG to flag gaps, cumulative SUM to build session ids, then aggregate.



-- ── P5 · hard · cohort retention ─────────────────────────────────────────────────
-- Assign each profile a cohort = the ISO week of its FIRST event. For each cohort,
-- report how many were active in week+0, +1, +2, +3 (a profile is "active in week W"
-- if it has any event that week), and the % of the cohort that represents.
-- Output: cohort_week, cohort_size, wk_offset (0..3), active, pct.
-- Skills: date_trunc('week'), date_diff, CTEs, DISTINCT counting.



-- ── P6 · capstone · optimization + modeling ──────────────────────────────────────
-- (a) The query below is deliberately slow (two correlated scalar subqueries per
--     title, casting event_ts::date which blocks range pruning). Rewrite it to a
--     single set-based pass over a sargable timestamp range, returning identical rows.
-- (b) In a comment, answer: at what GRAIN would you store playback_events, and how
--     would you PARTITION it at Netflix scale (think Iceberg / date partitioning)?
--     What does that buy the query in (a)?

-- SLOW (rewrite this):
SELECT t.title_id, t.title_name,
  (SELECT count(*) FROM playback_events e
     WHERE e.title_id = t.title_id AND e.event_type = 'start'
       AND e.event_ts::date BETWEEN DATE '2026-05-01' AND DATE '2026-05-07') AS plays_wk1,
  (SELECT count(DISTINCT e.profile_id) FROM playback_events e
     WHERE e.title_id = t.title_id
       AND e.event_ts::date BETWEEN DATE '2026-05-01' AND DATE '2026-05-07') AS viewers_wk1
FROM titles t
ORDER BY plays_wk1 DESC;

-- YOUR REWRITE:


