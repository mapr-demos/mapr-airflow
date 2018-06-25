"""
###
Sample DAG, which declares MapR Spark, Spark SQL and Hive tasks.
"""
import airflow
import json
from airflow import DAG
from airflow.contrib.operators.spark_submit_operator import SparkSubmitOperator
from airflow.hooks.hive_hooks import HiveCliHook
from airflow.operators.bash_operator import BashOperator
from airflow.operators.dummy_operator import DummyOperator
from airflow.operators.hive_operator import HiveOperator
from airflow.operators.http_operator import SimpleHttpOperator
from airflow.operators.python_operator import BranchPythonOperator
from datetime import timedelta
import os

default_args = {
  'owner': 'airflow',
  'depends_on_past': False,
  'start_date': airflow.utils.dates.days_ago(2),
  'email': ['airflow@example.com'],
  'email_on_failure': False,
  'email_on_retry': False,
  'retries': 1,
  'retry_delay': timedelta(minutes=5),
  'provide_context': True
}

dag = DAG(
    'mapr_tasks_dag',
    default_args=default_args,
    description='A simple tutorial DAG',
    schedule_interval=timedelta(days=1))

get_last_commit_task = SimpleHttpOperator(
    task_id='get_last_commit_task',
    http_conn_id='http_github',
    endpoint='/repos/mapr-demos/mapr-music/commits/master',
    method='GET',
    xcom_push=True,
    dag=dag)


def query_hive(**kwargs):
  ti = kwargs['ti']
  # get sha of latest commit
  v1 = ti.xcom_pull(key=None, task_ids='get_last_commit_task')
  json_value = json.loads(v1)
  sha = json_value['sha']

  hive_cli = HiveCliHook()
  hql = "select * from mapr_music_updates where commit_sha = '" + sha + "';"
  latest_commit = hive_cli.run_cli(hql)

  changed = latest_commit.find(sha) == -1
  ti.xcom_push(key='sha', value=sha)
  ti.xcom_push(key='is_changed', value=changed)

  return 'reimport_dataset_task' if changed else 'skip_reimport_dataset_task'


check_last_commit_task = BranchPythonOperator(
    task_id='check_last_commit_task',
    python_callable=query_hive,
    dag=dag)

reimport_dataset_task = BashOperator(
    task_id='reimport_dataset_task',
    bash_command="""rm -rf ~/mapr-music;
                    ( cd ~ ; git clone https://github.com/mapr-demos/mapr-music );
                    ~/mapr-music/bin/import-dataset.sh --path ~/mapr-music/dataset/ --recreate""",
    dag=dag)

spark_compute_statistics_task = SparkSubmitOperator(
    task_id='spark_compute_statistics_task',
    application=os.environ['MAPR_DAG_SPARK_JOB_PATH'],
    java_class='com.mapr.example.StatisticsJob',
    application_args=["/apps/mapr-airflow",
                      "{{ task_instance.xcom_pull(key='sha', task_ids='check_last_commit_task') }}"],
    dag=dag)

insert_reimport_record = HiveOperator(
    task_id='insert_reimport_record',
    hql="insert into table mapr_music_updates values ('{{ task_instance.xcom_pull(key='sha', task_ids='check_last_commit_task') }}', '/apps/mapr-airflow/{{ task_instance.xcom_pull(key='sha', task_ids='check_last_commit_task') }}');",
    dag=dag)

skip_reimport_dataset_task = DummyOperator(task_id='skip_reimport_dataset_task',
                                           dag=dag)
finish_task = DummyOperator(task_id='skip_reimport_dataset_task', dag=dag)

get_last_commit_task >> check_last_commit_task >> reimport_dataset_task >> spark_compute_statistics_task >> insert_reimport_record
check_last_commit_task >> skip_reimport_dataset_task

dag.doc_md = __doc__
