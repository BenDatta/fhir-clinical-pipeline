from datetime import datetime
from airflow.sdk import dag, task
import subprocess

@dag(
    dag_id="fhir_clinical_pipeline",
    description="Extract FHIR clinical resources into the PostgreSQL warehouse and run dbt.",
    start_date=datetime(2026, 1, 1),
    schedule="@daily",
    catchup=False,
    tags=["healthcare", "FHIR", "clinical-analytics"],
)
def fhir_clinical_pipeline():

    @task
    def extract_load():
        subprocess.run(
            ["python", "/opt/airflow/pipeline/extract_load.py"],
            check=True,
        )

    @task
    def transform():
        subprocess.run(
            ["dbt", "build", "--project-dir", "/opt/airflow/dbt",
             "--profiles-dir", "/opt/airflow/dbt"],
            check=True,
        )

    extract_load() >> transform()

fhir_clinical_pipeline()
