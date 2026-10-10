"""Hand-run order: extract -> bronze -> silver -> gold. Airflow calls this later."""

from ingest.extract_to_landing import run as extract
from ingest.load_bronze import run as bronze
from ingest.run_gold import run as gold
from ingest.run_silver import run as silver


def run() -> None:
    extract()
    bronze()
    silver()
    gold()
    print("[SUCCESS] Hop & Barrel pipeline complete")


if __name__ == "__main__":
    run()
