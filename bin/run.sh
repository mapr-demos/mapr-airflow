#!/bin/bash

DEFAULT_WEB_UI_PORT=8080

# Check if 'WEB_UI_PORT' environment varaible set
if [ ! -z ${WEB_UI_PORT+x} ]; then # WEB_UI_PORT exists
    echo "Web UI port number: $WEB_UI_PORT"
else
    echo "WEB_UI_PORT environment variable is not set. Please set it and rerun. Defaulting to: $DEFAULT_WEB_UI_PORT"
    WEB_UI_PORT=${DEFAULT_WEB_UI_PORT}
fi

# Check if 'DRILL_NODE' environment variable set
if [ ! -z ${DRILL_NODE+x} ]; then # DRILL_NODE exists
    echo "Drill node: $DRILL_NODE"
else
    echo 'DRILL_NODE environment variable is not set. Please set it and rerun.'
    exit 1
fi

# Check if 'DRILL_CLUSTER_ID' environment variable set
if [ ! -z ${DRILL_CLUSTER_ID+x} ]; then # DRILL_CLUSTER_ID exists
    echo "Drill cluster id: $DRILL_CLUSTER_ID"
else
    echo 'DRILL_CLUSTER_ID environment variable is not set. Please set it and rerun.'
    exit 1
fi

# Check if 'MAPR_USER_PASSWORD' environment variable set
if [ ! -z ${MAPR_USER_PASSWORD+x} ]; then # DRILL_CLUSTER_ID exists
    echo "MapR user password: $MAPR_USER_PASSWORD"
else
    echo 'MAPR_USER_PASSWORD environment variable is not set. Please set it and rerun.'
    exit 1
fi

sudo /opt/mapr/server/configure.sh -R -c -Z ${MAPR_CLDB_HOSTS}:5181 -C ${MAPR_CLDB_HOSTS}:7222
sudo chown ${MAPR_CONTAINER_USER}:${MAPR_CONTAINER_GROUP} -R /opt/mapr/spark
sudo chown ${MAPR_CONTAINER_USER}:${MAPR_CONTAINER_GROUP} -R /opt/mapr/drill

airflow initdb
SPARK_VERSION=$(cat /opt/mapr/spark/sparkversion)
DRILL_VERSION=$(cat /opt/mapr/drill/drillversion)
export PATH=$PATH:/opt/mapr/spark/spark-${SPARK_VERSION}/bin
export PATH=$PATH:/opt/mapr/drill/drill-${DRILL_VERSION}/bin
export MAPR_DAG_SPARK_JOB_PATH=/home/mapr/mapr-apps/spark-statistics-job-1.0.0-SNAPSHOT.jar
export MAPR_DAG_DRILL_SCRIPT_PATH=/home/mapr/airflow/bin/drill-script.sh

cp -R /home/mapr/mapr-apps/mapr-airflow/* /home/mapr/airflow/

# Set Drill node name
sed -i -e "s/localhost/$DRILL_NODE/g" /home/mapr/airflow/bin/drill-script.sh

# Change drill-override.conf
sed -i -e "s/localhost:2181/$DRILL_NODE:5181/g" /opt/mapr/drill/drill-${DRILL_VERSION}/conf/drill-override.conf
sed -i -e "s/drillbits1/$DRILL_CLUSTER_ID/g" /opt/mapr/drill/drill-${DRILL_VERSION}/conf/drill-override.conf

# Create GitHub HTTP connection, which will be used by 'mapr_tasks_dag'
airflow connections --add --conn_id http_github --conn_type http --conn_host https://api.github.com --conn_schema https

# Edit Hive connection to use Beeline instead of Hive CLI
airflow connections --delete --conn_id hive_cli_default
airflow connections --add --conn_id hive_cli_default --conn_type hive_cli --conn_host node1 --conn_port 10000 --conn_schema default --conn_login ${MAPR_CONTAINER_USER} --conn_password ${MAPR_USER_PASSWORD} --conn_extra "{\"use_beeline\": true, \"auth\": \"null;user=$MAPR_CONTAINER_USER;password=$MAPR_USER_PASSWORD\"}"

airflow scheduler &

airflow webserver -p ${WEB_UI_PORT}
