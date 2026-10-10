"""Landing JSON -> Postgres bronze (truncate + insert)."""

from __future__ import annotations

import json
from pathlib import Path

from ingest.db import ROOT, landing_root, pg_conn, run_sql_file

TABLES = {
    "styles": ("shop/styles", ["style_id", "name", "updated_at"]),
    "beers": ("shop/beers", ["beer_id", "name", "style_id", "abv", "price", "updated_at"]),
    "customers": ("shop/customers", ["customer_id", "name", "email", "updated_at"]),
    "orders": ("shop/orders", ["order_id", "customer_id", "order_date", "total_amount", "updated_at"]),
    "order_items": (
        "shop/order_items",
        ["order_item_id", "order_id", "beer_id", "quantity", "price", "updated_at"],
    ),
    "distributors": (
        "distributors/distributors",
        ["distributor_id", "distributor_name", "contact_name", "city", "country", "created_at"],
    ),
    "beer_distributors": (
        "distributors/beer_distributors",
        ["distributor_id", "beer_id", "supply_price", "last_updated"],
    ),
    "taproom_reviews": (
        "reviews",
        ["review_id", "customer_id", "beer_id", "rating", "review_text", "review_date"],
    ),
}


def latest_json(rel: str) -> Path | None:
    folder = landing_root() / rel
    files = sorted(folder.glob("*.json"))
    return files[-1] if files else None


def load_table(name: str, rel: str, columns: list[str]) -> None:
    path = latest_json(rel)
    if path is None:
        print(f"[WARN] no JSON for {name} in {rel}")
        return
    rows = json.loads(path.read_text())
    if not rows:
        print(f"[INFO] skip bronze.{name}: {path.name} is empty (keep previous bronze)")
        return
    placeholders = ", ".join(["%s"] * len(columns))
    col_sql = ", ".join(columns)
    conn = pg_conn()
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(f"TRUNCATE bronze.{name}")
                for row in rows:
                    values = [row.get(c) for c in columns]
                    cur.execute(
                        f"INSERT INTO bronze.{name} ({col_sql}) VALUES ({placeholders})",
                        values,
                    )
        print(f"[SUCCESS] bronze.{name}: {len(rows)} rows from {path.name}")
    finally:
        conn.close()


def run() -> None:
    run_sql_file(ROOT / "sql" / "warehouse" / "bronze.sql")
    for name, (rel, cols) in TABLES.items():
        load_table(name, rel, cols)


if __name__ == "__main__":
    run()
