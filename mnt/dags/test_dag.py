from airflow.operators.python import PythonOperator
from airflow import DAG
from datetime import datetime, timedelta


def testing():
    print('Hello World!')
    return


default_args = {
    'owner': 'osuarez',
    'start_date': datetime(2020,5,1),
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}


with DAG(   dag_id='testing_dag',
            default_args=default_args,
            schedule_interval='@daily',
        ) as dag:


    run_this = PythonOperator(
        task_id='python_test',
        python_callable=testing
    )


