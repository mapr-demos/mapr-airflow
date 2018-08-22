"""
###
Sample DAG, which declares single MapR Hive task.
"""
import datetime
import airflow
from airflow import DAG
from airflow.operators.hive_operator import HiveOperator
from datetime import timedelta

default_args = {
  'owner': 'airflow',
  'depends_on_past': False,
  'start_date': airflow.utils.dates.days_ago(0, hour=0, minute=0, second=1),
  'email': ['airflow@example.com'],
  'email_on_failure': False,
  'email_on_retry': False,
  'retries': 1,
  'retry_delay': timedelta(minutes=5),
  'provide_context': True
}

dag = DAG(
    'mapr_hive_task_dag',
    default_args=default_args,
    description='MapR single task DAG',
    schedule_interval=timedelta(minutes=15))

insert_current_datetime = HiveOperator(
    task_id='insert_current_datetime_task',
    hql="insert into table datetimes values ('" + datetime.datetime.now().strftime("%I:%M%p on %B %d, %Y") + "');",
    dag=dag)

dag.doc_md = __doc__
