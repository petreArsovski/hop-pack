# Hop & Barrel data pipeline

Local medallion pipeline for a neighborhood craft beer shop: two **SQL Server** source databases, file landing, **Postgres** bronze / silver / gold, and Airflow for orchestration.

Stack: Docker Compose, Python, SQL Server 2022 (Linux), Postgres 16, Apache Airflow.

## Architecture

```
SQL Server (shop + distributors) ──► Python extract ──► landing/*.json
                                                            │
                                                            ▼
                                                  Postgres bronze (raw)
                                                            │
                                                            ▼
                                             Postgres silver (SCD2, quarantine)
                                                            │
                                                            ▼
                                        gold: sales, margin, reviews, engagement
```

- **Full load** for small dims (`beers`, `styles`, `distributors`)
- **Incremental** loads keyed on `updated_at` / `last_updated`, watermark in `ops.audit_log` (SUCCESS only after files land)
- **Silver SCD2** on customers, orders, order items, reviews (`is_active`, effective dates)
- **Quarantine** flag for incomplete customer rows
- Gold answers: units and revenue by style/day, shelf vs supply margin, ratings by beer

The warehouse stays Postgres. Do not point bronze/silver/gold at SQL Server.

## Run

Needs Docker Desktop (or Engine + Compose). SQL Server does **not** run files in `docker-entrypoint-initdb.d` by itself; Compose starts `mssql-init`, which waits until the engine is healthy and then applies `sql/source/*.sql` with `sqlcmd`.

```bash
docker compose up -d --wait mssql mssql-init postgres
docker compose --profile run build pipeline
docker compose --profile run run --rm pipeline
```

Useful checks (shop is SQL Server; warehouse is Postgres):

```bash
docker compose exec mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'HopBarrel1!' -C -d hop_and_barrel -Q "SELECT beer_id, name, price FROM beers;"
docker compose exec postgres psql -U warehouse -d hop_warehouse -c "SELECT * FROM gold.sales_by_style_day;"
docker compose exec postgres psql -U warehouse -d hop_warehouse -c "SELECT customer_id, name, is_quarantined FROM silver.customers;"
```

From the host (SQL Server is published on **14333** so it does not collide with a local instance on 1433):

```bash
sqlcmd -S 127.0.0.1,14333 -U sa -P 'HopBarrel1!' -C -d hop_and_barrel -Q "SELECT customer_id, name, email FROM customers;"
```

pgAdmin (or any Postgres client) still uses **5433** → container 5432. The warehouse is unchanged.

Airflow (optional):

```bash
docker compose --profile airflow build airflow
docker compose --profile airflow up -d airflow
```

UI: http://127.0.0.1:8085 — `admin` / `admin`. Enable and trigger `hop_and_barrel_pipeline` (one task that still calls `run_pipeline`).

Published ports: SQL Server **14333**, Postgres **5433**, Airflow **8085**. Containers on the Compose network talk to `mssql:1433` and `postgres:5432`. Host-side Python defaults in `ingest/db.py` are `127.0.0.1:14333` and `127.0.0.1:5433`.

Reset databases: `docker compose down -v`.

## Layout

| Path | Role |
| --- | --- |
| `sql/source/` | OLTP T-SQL seed (`hop_and_barrel` + `hop_distributors`) |
| `scripts/init-mssql.sh` | `sqlcmd` after the engine is healthy |
| `data/reviews/` | tap-room reviews fixture |
| `config/` | metadata: table list, full vs incremental |
| `landing/` | extracted JSON |
| `sql/warehouse/` | bronze, silver, gold, audit DDL (Postgres) |
| `ingest/` | extract, bronze load, MERGE, gold rebuild |
| `dags/` | Airflow DAG |

## Seed quirks (on purpose)

- Customer 6 has a null email → `silver.customers.is_quarantined`
- Order 2006 header total does not match line items
- `beer_distributors` includes a row for missing distributor 9
