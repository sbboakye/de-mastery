-- 02_solutions.sql — reference solutions. Open ONLY after attempting 01_problems.sql.
-- watch-minutes proxy: each 'heartbeat' ≈ 5 minutes watched.

-- ── P1 (warm-up · RANK): top 3 titles per country by watch-minutes ──────────────
WITH wm AS (
  SELECT country, title_id,
         count(*) FILTER (WHERE event_type='heartbeat') * 5 AS watch_min
  FROM playback_events GROUP BY 1,2
)
SELECT country, title_id, watch_min,
       RANK() OVER (PARTITION BY country ORDER BY watch_min DESC) AS rnk
FROM wm QUALIFY rnk <= 3 ORDER BY country, rnk;

-- ── P2 (window frame): daily plays + 7-day trailing rolling sum, per title ───────
WITH daily AS (
  SELECT title_id, event_ts::date AS d,
         count(*) FILTER (WHERE event_type='start') AS plays
  FROM playback_events GROUP BY 1,2
)
SELECT title_id, d, plays,
       sum(plays) OVER (PARTITION BY title_id ORDER BY d
                        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS plays_7d
FROM daily ORDER BY title_id, d;

-- ── P3 (LAG): day-over-day change in daily unique viewers, per title ─────────────
WITH daily AS (
  SELECT title_id, event_ts::date AS d, count(DISTINCT profile_id) AS viewers
  FROM playback_events GROUP BY 1,2
)
SELECT title_id, d, viewers,
       viewers - lag(viewers) OVER (PARTITION BY title_id ORDER BY d) AS dod_change
FROM daily ORDER BY title_id, d;

-- ── P4 (gap-and-islands · sessionization): >30-min gap starts a new session ──────
WITH ordered AS (
  SELECT profile_id, title_id, event_ts,
         lag(event_ts) OVER (PARTITION BY profile_id, title_id ORDER BY event_ts) AS prev_ts
  FROM playback_events
), flagged AS (
  SELECT *, CASE WHEN prev_ts IS NULL OR event_ts - prev_ts > INTERVAL 30 MINUTE
                 THEN 1 ELSE 0 END AS new_sess
  FROM ordered
), sess AS (
  SELECT profile_id, title_id, event_ts,
         sum(new_sess) OVER (PARTITION BY profile_id, title_id ORDER BY event_ts) AS session_no
  FROM flagged
), bounds AS (
  SELECT profile_id, title_id, session_no, max(event_ts) - min(event_ts) AS dur
  FROM sess GROUP BY 1,2,3
)
SELECT profile_id, count(*) AS sessions, round(avg(epoch(dur))/60.0, 1) AS avg_session_min
FROM bounds GROUP BY 1 ORDER BY sessions DESC, profile_id LIMIT 20;

-- ── P5 (cohort): weekly retention by first-watch week ────────────────────────────
WITH firsts AS (
  SELECT profile_id, date_trunc('week', min(event_ts)) AS cohort_week
  FROM playback_events GROUP BY 1
), activity AS (
  SELECT DISTINCT profile_id, date_trunc('week', event_ts) AS active_week
  FROM playback_events
), joined AS (
  SELECT f.cohort_week, date_diff('week', f.cohort_week, a.active_week) AS wk_offset, a.profile_id
  FROM firsts f JOIN activity a USING (profile_id)
), cohort_size AS (
  SELECT cohort_week, count(*) AS n FROM firsts GROUP BY 1
)
SELECT j.cohort_week, cs.n AS cohort_size, j.wk_offset,
       count(DISTINCT j.profile_id) AS active,
       round(100.0*count(DISTINCT j.profile_id)/cs.n, 1) AS pct
FROM joined j JOIN cohort_size cs USING (cohort_week)
WHERE j.wk_offset BETWEEN 0 AND 3
GROUP BY 1,2,3 ORDER BY 1,3;

-- ── P6 (optimization + modeling) ─────────────────────────────────────────────────
-- (a) Single set-based pass; LEFT JOIN keeps zero-play titles; half-open timestamp
--     range [start, end) is sargable (no per-row ::date cast), so a date-partitioned
--     store can prune to week 1 instead of scanning all events. Identical results,
--     ~1.8x faster here and far more at scale.
SELECT t.title_id, t.title_name,
       count(*) FILTER (WHERE e.event_type = 'start')  AS plays_wk1,
       count(DISTINCT e.profile_id)                    AS viewers_wk1
FROM titles t
LEFT JOIN playback_events e
  ON e.title_id = t.title_id
 AND e.event_ts >= TIMESTAMP '2026-05-01'
 AND e.event_ts <  TIMESTAMP '2026-05-08'
GROUP BY 1,2
ORDER BY plays_wk1 DESC;

-- (b) Grain: ONE ROW PER RAW PLAYBACK EVENT (profile × title × event_ts) — the
--     finest grain, so any rollup (sessions, watch-time, retention) is derivable and
--     nothing is pre-aggregated away. Partition by event DATE (e.g. Iceberg hidden
--     partitioning on days(event_ts)). A query bounded to week 1 then reads ~7 day
--     partitions instead of the whole table — partition pruning. Keep event_ts as a
--     real timestamp (never filter on a cast of it) so the predicate stays sargable.
--     At true scale you'd also Z-order/sort within partitions by title_id to cut the
--     bytes scanned for title-filtered queries.
