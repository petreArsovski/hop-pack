"""SQL Server shop/distributors (and reviews file) -> JSON in landing/. Watermark lives in Postgres ops.audit_log."""

from __future__ import annotations

import csv
import json
import os
import shutil
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path

from ingest.db import ROOT, landing_root, mssql_conn, pg_conn


def json_default(value):
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, bytes):
        return value.decode("utf-8")
    raise TypeError(f"Cannot serialize {type(value)}")


def log_event(event_type: str, message: str, table: str | None = None) -> None:
    print(f"[{event_type}] {message}")
    conn = pg_conn()
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO ops.pipeline_logs (event_type, message, tablename)
                    VALUES (%s, %s, %s)
                    """,
                    (event_type, message, table),
                )
    finally:
        conn.close()


def get_latest_watermark(table_name: str) -> str:
    """Bookmark from last SUCCESS load — not from the config CSV."""
    conn = pg_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT MAX(load_timestamp)
                FROM ops.audit_log
                WHERE tablename = %s AND status = 'SUCCESS'
                """,
                (table_name,),
            )
            row = cur.fetchone()
            if row and row[0]:
                return row[0].strftime("%Y-%m-%d %H:%M:%S")
            return "1900-01-01 00:00:00"
    finally:
        conn.close()


def write_audit(table: str, load_type: str, count: int, status: str) -> None:
    conn = pg_conn()
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO ops.audit_log
                      (tablename, load_type, record_count, load_timestamp, status)
                    VALUES (%s, %s, %s, NOW(), %s)
                    """,
                    (table, load_type, count, status),
                )
    finally:
        conn.close()


def relax_landing_permissions() -> None:
    """Airflow runs as uid 50000; pipeline often writes as root. Make landing world-writable."""
    root = landing_root()
    root.mkdir(parents=True, exist_ok=True)
    for dirpath, _, filenames in os.walk(root):
        try:
            os.chmod(dirpath, 0o777)
        except OSError:
            pass
        for name in filenames:
            try:
                os.chmod(Path(dirpath) / name, 0o666)
            except OSError:
                pass


def archive_existing(table_dir: Path) -> None:
    if not table_dir.exists():
        return
    archive = landing_root() / "archive" / table_dir.name
    archive.mkdir(parents=True, exist_ok=True)
    relax_landing_permissions()
    for file in table_dir.glob("*.json"):
        dest = archive / file.name
        try:
            if dest.exists():
                dest.unlink()
            shutil.move(str(file), str(dest))
        except OSError:
            try:
                file.unlink()
            except OSError:
                pass


def extract_table(database: str, table: str, load_type: str, watermark_col: str, target_path: str) -> None:
    table_dir = landing_root() / Path(target_path).relative_to("landing")
    table_dir.mkdir(parents=True, exist_ok=True)
    archive_existing(table_dir)

    load_type_norm = load_type.strip().lower()
    table_ident = table.replace("]", "]]")
    last_watermark = None
    if load_type_norm == "incremental":
        last_watermark = get_latest_watermark(table)
        log_event("INFO", f"Watermark for {table}: {last_watermark}", table)
        col_ident = watermark_col.replace("]", "]]")
        sql = f"SELECT * FROM [{table_ident}] WHERE [{col_ident}] > %s"
        params = (last_watermark,)
    else:
        sql = f"SELECT * FROM [{table_ident}]"
        params = ()

    conn = mssql_conn(database)
    try:
        cur = conn.cursor(as_dict=True)
        cur.execute(sql, params)
        rows = cur.fetchall()
        cur.close()
    finally:
        conn.close()

    today = datetime.now().strftime("%Y%m%d")
    out = table_dir / f"{table}_{today}.json"
    out.write_text(json.dumps(rows, default=json_default, indent=2))
    write_audit(table, load_type, len(rows), "SUCCESS")
    log_event("SUCCESS", f"Wrote {len(rows)} rows to {out}", table)


def read_config(path: Path) -> list[dict]:
    with path.open() as f:
        return list(csv.DictReader(f))


def extract_reviews() -> None:
    src = ROOT / "data" / "reviews" / "taproom_reviews.json"
    dest_dir = landing_root() / "reviews"
    dest_dir.mkdir(parents=True, exist_ok=True)
    archive_existing(dest_dir)
    today = datetime.now().strftime("%Y%m%d")
    dest = dest_dir / f"taproom_reviews_{today}.json"
    dest.write_text(src.read_text())
    rows = json.loads(src.read_text())
    write_audit("taproom_reviews", "full", len(rows), "SUCCESS")
    log_event("SUCCESS", f"Copied reviews fixture to {dest}", "taproom_reviews")


def run() -> None:
    relax_landing_permissions()
    for cfg_name in ("shop_tables.csv", "distributor_tables.csv"):
        for row in read_config(ROOT / "config" / cfg_name):
            if row["is_active"].strip() != "1":
                continue
            try:
                extract_table(
                    database=row["database"],
                    table=row["tablename"],
                    load_type=row["load_type"],
                    watermark_col=row.get("watermark") or "",
                    target_path=row["target_path"],
                )
            except Exception as exc:  # noqa: BLE001 — failed extract must not write SUCCESS
                log_event("ERROR", f"{row['tablename']}: {exc}", row["tablename"])
                raise
    extract_reviews()
    relax_landing_permissions()


if __name__ == "__main__":
    run()
