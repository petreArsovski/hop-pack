# Hop & Barrel — run the pipeline in order

Shop/OLTP is **SQL Server**. Warehouse (bronze / silver / gold / ops) is **Postgres**. Landing JSON column names stay the same. Gold SQL stays Postgres.

Start sources, land files, load bronze, merge silver, rebuild gold, optionally trigger Airflow.

## Step 1 — Sources up

Compose starts SQL Server (`mssql`) and Postgres. SQL Server does not auto-run `docker-entrypoint-initdb.d`. The `mssql-init` service waits until `sqlcmd` healthcheck passes, then applies `sql/source/*.sql`.

```bash
docker compose up -d --wait mssql mssql-init postgres
```

Two databases, same names as the config CSVs: `hop_and_barrel` (shop) and `hop_distributors`.

```bash
docker compose exec mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'HopBarrel1!' -C -d hop_and_barrel -Q "SELECT beer_id, name, price FROM beers;"
docker compose exec mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'HopBarrel1!' -C -d hop_and_barrel -Q "SELECT customer_id, name, email FROM customers;"
```

Host port is **14333** (container 1433) so a local SQL Server on 1433 is left alone. Postgres / pgAdmin stay on **5433**.

You should see customer 6 `Unknown Guest` with a null email, order 2006 with a nonsense header total, and `beer_distributors` row `(9, 101)`. Those stay messy on purpose.

Seed scripts use `IDENTITY` / `IDENTITY_INSERT` and `DATETIME2` (SQL Server `TIMESTAMP` is a different type — not a datetime).

## Step 2 — Landing

Config CSVs (`config/shop_tables.csv`, `config/distributor_tables.csv`) list database + table + `full` vs `incremental`. One Python job, many tables.

```bash
docker compose --profile run build pipeline
docker compose --profile run run --rm pipeline python -m ingest.extract_to_landing
```

Incremental extract uses T-SQL:

```sql
SELECT * FROM [customers] WHERE [updated_at] > %s
```

The `%s` is a pymssql placeholder. The watermark is `MAX(load_timestamp)` from **Postgres** `ops.audit_log` where `status = 'SUCCESS'` — only after JSON exists. Empty incremental files must not wipe bronze (the bronze loader already skips empty JSON).

Look under `landing/shop/` and `landing/distributors/`.

## Step 3 — Bronze

`ingest/load_bronze.py` truncates Postgres `bronze.*` and inserts from the latest landing JSON. Confirm:

```bash
docker compose --profile run run --rm pipeline python -m ingest.load_bronze
docker compose exec postgres psql -U warehouse -d hop_warehouse -c "SELECT customer_id, email FROM bronze.customers ORDER BY customer_id;"
```

Customer 6 is still here with a null email. Bronze is raw, not cleaned.

## Step 4 — Silver

`sql/warehouse/silver.sql` (Postgres `MERGE`, SCD2, `is_quarantined`).

```bash
docker compose --profile run run --rm pipeline python -m ingest.run_silver
docker compose exec postgres psql -U warehouse -d hop_warehouse -c "SELECT customer_id, name, is_quarantined, is_active FROM silver.customers ORDER BY customer_id;"
```

Expect customers 1–5 clean (`is_quarantined = f`) and customer 6 quarantined (`t`).

## Step 5 — Gold

`sql/warehouse/gold.sql` builds report tables from silver only.

```bash
docker compose --profile run run --rm pipeline python -m ingest.run_gold
docker compose exec postgres psql -U warehouse -d hop_warehouse -c "SELECT style_name, SUM(total_units_sold) FROM gold.sales_by_style_day GROUP BY 1 ORDER BY 1;"
```

## Step 6 — Airflow (optional)

One DAG, one task: `extract_bronze_silver_gold` calls `ingest.run_pipeline.run`. Trigger in the UI first; add a schedule last.

```bash
docker compose --profile airflow build airflow
docker compose --profile airflow up -d airflow
```

http://127.0.0.1:8085 — `admin` / `admin`. Compose network: `MSSQL_HOST=mssql`, port `1433`.

## Ports

| What | Host | Inside Compose |
| --- | --- | --- |
| SQL Server shop | 14333 | `mssql:1433` |
| Postgres warehouse / pgAdmin | 5433 | `postgres:5432` |
| Airflow UI | 8085 | 8080 |

SA password (lab only): `HopBarrel1!`. Warehouse user: `warehouse` / `warehouse`.
