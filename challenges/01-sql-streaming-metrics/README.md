# Theme 1 — SQL & Query Optimization (Netflix streaming-metrics accent)

A self-contained week of SQL drilling on a synthetic Netflix-style playback dataset,
generated entirely in DuckDB (no Python, no committed data files). Mastery-gated:
the theme is **done only when you pass a cold Friday mock** — not when these problems
are finished.

## Files
| File | What it is |
|---|---|
| `00_generate.sql` | Reproducible dataset generator (titles, profiles, playback_events) |
| `01_problems.sql` | 6 graded problems, escalating. Attempt these. |
| `02_solutions.sql` | Reference solutions. **Open only after attempting.** |
| `03_check.sql` | Sanity checks + the expected shape of each answer (self-grading) |

## Generate the data
Uses the DuckDB container already in this repo. From the repo root:

```bash
docker compose run --rm -v "$PWD/challenges:/challenges" duckdb \
  /data/warehouse.duckdb -c ".read /challenges/01-sql-streaming-metrics/00_generate.sql"
```

Or, with the DuckDB CLI on the host:

```bash
duckdb data/warehouse.duckdb -c ".read challenges/01-sql-streaming-metrics/00_generate.sql"
```

Re-running rebuilds the tables from scratch. The tables live in the gitignored
`data/warehouse.duckdb`, so nothing data-heavy is committed.

## The dataset (grain matters)
`playback_events` is **one row per raw playback event** — the finest grain, so sessions,
watch-time, completion, and retention are all *derivable*, nothing pre-aggregated.

- `event_type ∈ {start, heartbeat, pause, resume, stop}`; heartbeats land every 5 min.
- `position_sec` is the playhead; it continues across a pause/resume within one viewing.
- A profile may watch a title across several days; each viewing restarts position at 0,
  so to attribute watch-time correctly you must **sessionize** (that's P4).
- ~35-day window from 2026-05-01 → weekly retention cohorts exist (that's P5).

## How to run the week (maps to your calendar blocks)
- **Mon** — P1–P2 (window functions, frames). Open `01_problems.sql`, solve cold.
- **Tue** — P3–P5 (LAG, sessionization, cohort retention). The two hard ones.
- **Wed** — P6 (optimization). Rewrite the slow query; write the grain/partition note.
- **Thu** — re-attempt cold whatever cracked; drill the weakest sub-skill.
- **Fri** — **cold mock in `grill me claude`** (not here). One fresh streaming-metrics
  problem, 45 min, then defend the plan + the table model.
- **Sat** — deep build: design the playback fact + dims yourself and reload.
- **Sun** — synthesis: write the verdict + gaps into the Notion Control Doc; set Week 2.

## Self-grading
Run `03_check.sql` for structural sanity, then compare each answer to the expected shape
listed there. Only open `02_solutions.sql` once you've committed to an answer.

## The gate (what "pass" means)
Cold, 45 min, one hard streaming-metrics problem, no warm-up. **Pass = correct results
AND you can defend the query plan AND state the grain/partitioning of the tables.** Miss
any leg → SQL runs another week, and Sunday turns the exact miss into Week 2's focus.
