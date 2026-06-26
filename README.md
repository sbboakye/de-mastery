# DE Mastery

A personal sandbox for practicing **data-engineering** skills — SQL, modelling,
and moving data between engines. It pairs a Scala/Spark project with a
containerized **PostgreSQL** + **DuckDB** environment you can spin up locally.

- **PostgreSQL 16** — a real client/server (OLTP) database
- **DuckDB** — an embedded analytics (OLAP) database
- **Adminer** — a lightweight web SQL client
- **Scala 2.13 + Spark 4** — the application/learning code (`src/`)

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) with Compose v2 (`docker compose`)
- For the Scala side: JDK 17+ and [sbt](https://www.scala-sbt.org/)

## Quick start (databases)

```bash
docker compose up -d        # starts postgres + adminer
```

| Service | Where | Credentials |
|---|---|---|
| **Postgres** | `localhost:5432` | user `de` · pass `de` · db `de_mastery` |
| **Adminer** (web GUI) | http://localhost:8088 | System `PostgreSQL`, Server `postgres`, then the creds above |

The files in [`seed/`](seed/) load a small store schema (customers, products,
orders, order_items) the first time the Postgres volume is created.

### Postgres CLI

```bash
docker compose exec postgres psql -U de -d de_mastery
```

## DuckDB

DuckDB is **embedded** — it runs in-process (like SQLite), so there's no server
to keep alive. It's launched on demand rather than by `docker compose up`:

```bash
docker compose run --rm duckdb
```

This opens `/data/warehouse.duckdb` (persisted under `./data/`). Examples:

```sql
-- read a CSV/Parquet file you dropped in ./data
SELECT * FROM read_csv_auto('/data/yourfile.csv');

-- create a persistent table
CREATE TABLE nums AS SELECT * FROM range(10) t(n);
```

### Query Postgres directly from DuckDB

DuckDB can attach the running Postgres instance — great for practicing the
OLTP → OLAP handoff:

```sql
INSTALL postgres;
LOAD postgres;
ATTACH 'host=postgres port=5432 dbname=de_mastery user=de password=de' AS pg (TYPE postgres);

SELECT * FROM pg.customers;                            -- live query against Postgres
CREATE TABLE local_orders AS SELECT * FROM pg.orders;  -- copy into DuckDB
```

## Scala / Spark

```bash
sbt compile      # build
sbt run          # run
sbt test         # tests
```

Source lives in [`src/`](src/). The Postgres above is a convenient target for
JDBC reads/writes from Spark.

## Project layout

```
.
├── docker-compose.yml     # postgres + adminer + duckdb (cli profile)
├── Dockerfile.duckdb      # minimal image carrying the DuckDB CLI
├── seed/                  # SQL run once on first Postgres init
├── data/                  # shared scratch (csv/parquet, warehouse.duckdb) — gitignored
├── build.sbt              # Scala/Spark build
└── src/                   # Scala source
```

## Common commands

```bash
docker compose up -d            # start postgres + adminer
docker compose run --rm duckdb  # open a DuckDB shell
docker compose ps               # see what's running
docker compose down             # stop services (keeps data volume)
docker compose down -v          # stop AND wipe Postgres data + re-seed next time
```

Files in `./data` and the Postgres `pgdata` volume persist across restarts. To
re-run the seed SQL, remove the volume with `docker compose down -v`.
