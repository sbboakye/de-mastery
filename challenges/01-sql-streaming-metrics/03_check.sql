-- 03_check.sql — sanity + self-grading. Run after 00_generate.sql.
-- These check STRUCTURE/SHAPE, not exact magnitudes (random() can differ slightly by
-- DuckDB version even with setseed). If shapes match, your generation is good.

-- 1. Volumes — expect: titles=40, profiles=3000, events ≈ 130k–150k.
SELECT 'titles' AS t, count(*) AS n FROM titles
UNION ALL SELECT 'profiles', count(*) FROM profiles
UNION ALL SELECT 'playback_events', count(*) FROM playback_events;

-- 2. Integrity — expect: 8 countries, exactly these 5 event types, NO NULL country.
SELECT count(DISTINCT country) AS countries,
       count(DISTINCT event_type) AS event_types,
       count(*) FILTER (WHERE country IS NULL) AS null_country
FROM playback_events;

-- 3. Every session starts and ends cleanly — expect start_cnt ≈ stop_cnt (within ~5%).
SELECT count(*) FILTER (WHERE event_type='start') AS starts,
       count(*) FILTER (WHERE event_type='stop')  AS stops,
       count(*) FILTER (WHERE event_type='pause') AS pauses,
       count(*) FILTER (WHERE event_type='resume') AS resumes
FROM playback_events;

-- 4. Window span — expect ~35 days starting 2026-05-01.
SELECT min(event_ts) AS lo, max(event_ts) AS hi FROM playback_events;

-- ── Self-grade: the SHAPE each problem's answer should have ──────────────────────
-- P1  → exactly 24 rows (8 countries × top 3), rnk ∈ {1,2,3}.
-- P2  → plays_7d is non-decreasing for the first 7 days of each title, then slides.
-- P3  → dod_change is NULL on each title's first day, integer elsewhere.
-- P4  → 20 rows; avg_session_min is a small double (tens of minutes), sessions ~15–25.
-- P5  → pct = 100 at wk_offset 0 and DECREASES monotonically across 1,2,3 per cohort
--        (a healthy retention curve, roughly 100 → ~85 → ~60 → ~45).
-- P6  → 40 rows; your rewrite must equal the slow query exactly. Verify:
--        (paste slow as q_slow, rewrite as q_fast)
--        SELECT count(*) FROM (q_slow EXCEPT q_fast) ;  -- expect 0
--        SELECT count(*) FROM (q_fast EXCEPT q_slow) ;  -- expect 0
