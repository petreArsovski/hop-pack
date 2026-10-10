from ingest.db import ROOT, run_sql_file


def run() -> None:
    run_sql_file(ROOT / "sql" / "warehouse" / "gold.sql")
    print("[SUCCESS] gold tables rebuilt")


if __name__ == "__main__":
    run()
