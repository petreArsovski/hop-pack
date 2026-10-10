import os
from pathlib import Path

import psycopg2
import pymssql

ROOT = Path(__file__).resolve().parent.parent


def env(name: str, default: str) -> str:
    return os.environ.get(name, default)


def mssql_conn(database: str):
    return pymssql.connect(
        server=env("MSSQL_HOST", "127.0.0.1"),
        port=int(env("MSSQL_PORT", "14333")),
        user=env("MSSQL_USER", "sa"),
        password=env("MSSQL_PASSWORD", "HopBarrel1!"),
        database=database,
        login_timeout=15,
    )


def pg_conn():
    return psycopg2.connect(
        host=env("PG_HOST", "127.0.0.1"),
        port=int(env("PG_PORT", "5433")),
        user=env("PG_USER", "warehouse"),
        password=env("PG_PASSWORD", "warehouse"),
        dbname=env("PG_DATABASE", "hop_warehouse"),
    )


def landing_root() -> Path:
    return Path(env("LANDING_DIR", str(ROOT / "landing")))


def run_sql_file(path: Path) -> None:
    sql = path.read_text()
    conn = pg_conn()
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(sql)
    finally:
        conn.close()
