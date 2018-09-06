#!/bin/bash

DEFAULT_WEB_UI_PORT=8080

# Check if 'WEB_UI_PORT' environment varaible set
if [ ! -z ${WEB_UI_PORT+x} ]; then # WEB_UI_PORT exists
    echo "Web UI port number: $WEB_UI_PORT"
else
    echo "WEB_UI_PORT environment variable is not set. Please set it and rerun. Defaulting to: $DEFAULT_WEB_UI_PORT"
    WEB_UI_PORT=${DEFAULT_WEB_UI_PORT}
fi

sudo /opt/mapr/server/configure.sh -R -c -Z ${MAPR_CLDB_HOSTS}:5181 -C ${MAPR_CLDB_HOSTS}:7222
sudo chown ${MAPR_CONTAINER_USER}:${MAPR_CONTAINER_GROUP} -R /opt/mapr/spark
sudo chown ${MAPR_CONTAINER_USER}:${MAPR_CONTAINER_GROUP} -R /opt/mapr/hive

airflow initdb
SPARK_VERSION=$(cat /opt/mapr/spark/sparkversion)
export PATH=$PATH:/opt/mapr/spark/spark-${SPARK_VERSION}/bin
export MAPR_DAG_SPARK_JOB_PATH=/home/mapr/mapr-apps/spark-statistics-job-1.0.0-SNAPSHOT.jar
export MAPR_DAG_DRILL_SCRIPT_PATH=/home/mapr/airflow/bin/drill-script.sh

cp -R /home/mapr/mapr-apps/mapr-airflow/* /home/mapr/airflow/

# TODO: add GitHub connection, configure Hive, Drill connections

airflow scheduler &

airflow webserver -p ${WEB_UI_PORT}
