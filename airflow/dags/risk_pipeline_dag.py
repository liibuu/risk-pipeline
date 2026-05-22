from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.providers.microsoft.azure.sensors.wasb import WasbBlobSensor
from airflow.providers.microsoft.azure.operators.data_factory import AzureDataFactoryRunPipelineOperator

default_args = {
    "owner": "airflow",
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
    "email": ["liibuu-test@gmail.com"],
    "email_on_failure": True,
}

with DAG(
    dag_id="risk_pipeline",
    default_args=default_args,
    start_date=datetime(2026, 1, 1),
    schedule=None,   # manually
    catchup=False,
) as dag:

    # 1. Wait for source files to land in ADLS
    # wait_for_data = WasbBlobSensor(
    #     task_id="wait_for_source_files",
    #     container_name="risk-data",
    #     blob_name="landing/customerprofile/",
    #     wasb_conn_id="azure_blob_default",
    #     poke_interval=60,
    #     timeout=3600,
    # )

    # 2. Trigger ADF pipeline (ingestion: landing → raw)
    # run_adf = AzureDataFactoryRunPipelineOperator(
    #     task_id="run_adf_ingestion",
    #     pipeline_name="pl_ingest_all_sources",
    #     azure_data_factory_conn_id="azure_data_factory_default",
    #     factory_name="<your-adf-name>",
    #     resource_group_name="<your-rg>",
    #     wait_for_termination=True,
    # )

    landing_to_raw = BashOperator(
        task_id="landing_to_raw",
        bash_command=(
            "python /opt/airflow/setup/landing_to_raw.py"
        ),
        execution_timeout=timedelta(minutes=30),
    )    

    clean_adls = BashOperator(
        task_id="clean_curated_mart",
        bash_command=(
            "python /opt/airflow/setup/clean_adls.py"
        ),
    )

    # 3. dbt run - raw layer
    dbt_raw = BashOperator(
        task_id="dbt_run_raw",
        bash_command=(
            "cd /opt/airflow/dbt && "
            ". /opt/airflow/dbt/set_env.sh && "
            "/home/airflow/.local/bin/dbt run --select raw"
        ),
    )

    # 4. dbt run - curated layer
    dbt_curated = BashOperator(
        task_id="dbt_run_curated",
        bash_command=(
            "cd /opt/airflow/dbt && "
            ". /opt/airflow/dbt/set_env.sh && "
            "/home/airflow/.local/bin/dbt run --select curated --full-refresh"
        ),
    )

    # 5. dbt run - mart layer
    dbt_mart = BashOperator(
        task_id="dbt_run_mart",
        bash_command=(
            "cd /opt/airflow/dbt && "
            ". /opt/airflow/dbt/set_env.sh && "
            "/home/airflow/.local/bin/dbt run --select mart --full-refresh"
        ),
    )

    # 6. dbt test - all layers
    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=(
            "cd /opt/airflow/dbt && "
            ". /opt/airflow/dbt/set_env.sh && "
            "/home/airflow/.local/bin/dbt test"
        ),
    )

    # DAG dependency chain
    # wait_for_data >> run_adf >> landing_to_raw >> clean_adls >> dbt_raw >> dbt_curated >> dbt_mart >> dbt_test
    landing_to_raw >> clean_adls >> dbt_raw >> dbt_curated >> dbt_mart >> dbt_test