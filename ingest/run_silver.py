from ingest.db import ROOT, run_sql_file


def run() -> None:
    run_sql_file(ROOT / "sql" / "warehouse" / "silver.sql")
    print("[SUCCESS] silver MERGE / reload finished")


if __name__ == "__main__":
    run()
