from datetime import datetime

from airflow import DAG
from airflow.operators.python import PythonOperator


def extract_bronze_silver_gold() -> None:
    from ingest.run_pipeline import run

    run()


with DAG(
    dag_id="hop_and_barrel_pipeline",
    start_date=datetime(2026, 1, 1),
    schedule=None,
    catchup=False,
    tags=["hop-and-barrel", "local"],
) as dag:
    PythonOperator(
        task_id="extract_bronze_silver_gold",
        python_callable=extract_bronze_silver_gold,
    )
