# MapR Airflow

## Contents

* [Overview](#overview)
* [Airflow Installation](#airflow-installation)
* [MapR DAG](#mapr-dag)
* [Airflow Connection](#airflow-connection)
* [Run sample DAG](#run-sample-dag)


## Overview

Airflow is a platform to programmatically author, schedule and monitor workflows. Use airflow to author workflows as 
directed acyclic graphs (DAGs) of tasks. The airflow scheduler executes your tasks on an array of workers while 
following the specified dependencies. This repository contains sample MapR Tasks Pipeline along with explanation of 
how to run it on MapR Cluster.

## Airflow Installation

Install Airflow  on one of the MapR Cluster nodes:
```
[mapr@yournode ~]$ sudo pip install apache-airflow

[mapr@yournode ~]$ sudo pip install apache-airflow[hive]
```

Airflow directory will be created in `/home/mapr`:
```
[mapr@yournode ~]$ ls /home/mapr/airflow/
airflow.cfg  airflow.db  airflow-webserver.pid  logs  unittests.cfg
```

Init Airflow DB using CLI:
```
[mapr@yournode ~]$ airflow initdb
```

## MapR DAG

Sample [MapR DAG](dags/mapr_tasks_dag.py) declares tasks to reimport 
[MapR Music](https://github.com/mapr-demos/mapr-music) dataset in case when the repository updated. For the sake 
of example it also declares Spark Task, which computes statistics on imported dataset.

![](images/mapr-dag.png?raw=true "MapR DAG")

MapR DAG consists of the following tasks:

* get_last_commit_task

Fetches the latest `mapr-music` commit using GitHub API.

* check_last_commit_task

Checks if the latest commit is processed. This task queries Hive `mapr_music_updates` table.  

* reimport_dataset_task

This task will be executed in the case when the latest mapr-music commit was changed. It clones `mapr-music` repository 
and invokes `import-dataset.sh` script in order to reimport MapR Music data.

* spark_compute_statistics_task

Submits simple Spark job, which computes top 10 areas by artists and stores results as `csv` file to MapR-FS.

* insert_reimport_record

Stores hash of the latest processed commit and path to statistics file to Hive `mapr_music_updates` table.

* skip_reimport_dataset_task

This task executed in the case when the latest mapr-music commit was not changed. It is dummy task, that does literally 
nothing.

* drill_artist_albums_task

Invokes [script](bin/drill-script.sh) which executes Drill query and stores result as parquet file in MapR-FS.

* spark_top_artists_task

Submits simple Spark job, which computes top 3 artists by albums number and stores results as `csv` file to MapR-FS.


Now, `mapr_tasks_dag` is ready and will be run each day, as defined via `schedule_interval` parameter. Also, we can trigger DAG execution for certain period using Airflow CLI:

## Airflow Connection


`get_last_commit_task` is based on SimpleHTTPOperator that requires Airflow Connection to be created. 
The connection information to external systems is stored in the Airflow metadata database and managed in the 
UI `(Menu -> Admin -> Connections)`. 

So, we have to create the GitHub API connection:
![](images/creating-airflow-connection.png?raw=true "Creating Airflow Connection")


## Run sample DAG

* Clone `mapr-airflow` repository

```
$ git clone https://github.com/mapr-demos/mapr-airflow.git
```

* Copy `mapr_tasks_dag.py`

The default location for custom DAGs is `~/airflow/dags`, so copy `dags` directory to your Airflow installation on 
one of the MapR Cluster nodes:
```

$ export MAPR_NODE_HOSTNAME=yournode

$ scp -r mapr-airflow/dags mapr@$MAPR_NODE_HOSTNAME:/home/mapr/airflow

```

* Copy `drill-script.sh`

```

$ export MAPR_NODE_HOSTNAME=yournode

$ scp -r mapr-airflow/bin mapr@$MAPR_NODE_HOSTNAME:/home/mapr/airflow

```

* Build and copy Spark Statistics Job

```

$ cd mapr-airflow/spark-statistics-job

$ mvn clean package

$ scp target/spark-statistics-job-1.0.0-SNAPSHOT.jar mapr@$MAPR_NODE_HOSTNAME:/home/mapr

```

* Add `spark-submit` to `PATH`

`spark_compute_statistics_task` uses Airflow's `SparkSubmitOperator`, which requires that the `spark-submit` binary is 
in the PATH, so we have to add Spark `bin` directory location to `PATH` environment variable.

On node:
```
[mapr@yournode ~]$ export SPARK_VERSION=2.2.1 

[mapr@yournode ~]$ export PATH=$PATH:/opt/mapr/spark/spark-$SPARK_VERSION/bin
```

* Specify Spark Statistics Job location

Specify path of Spark Statistics Job jar via `MAPR_DAG_SPARK_JOB_PATH` environment variable:
```
[mapr@yournode ~]$ export MAPR_DAG_SPARK_JOB_PATH=/home/mapr/spark-statistics-job-1.0.0-SNAPSHOT.jar
```

* Specify Drill script location

Specify path of Drill script via `MAPR_DAG_DRILL_SCRIPT_PATH` environment variable:
```
[mapr@yournode ~]$ export MAPR_DAG_DRILL_SCRIPT_PATH=/home/mapr/airflow/bin/drill-script.sh
```

* Create Hive table

Create Hive table to store the latests processed commit along with path to statistics file:
```
[mapr@yournode ~]$ hive shell
hive> CREATE TABLE mapr_music_updates (commit_sha String, statistics String);
OK
Time taken: 0.222 seconds

```

* Start Airflow Web server

Start Airflow Web server using the following command:
```
airflow webserver -p 8080
```

Now, `mapr_tasks_dag` is ready and will be run each day, as defined via `schedule_interval` parameter. 

* Airflow backfill

We can trigger DAG execution for certain period using Airflow CLI:
```
airflow backfill mapr_tasks_dag -s 2015-07-15 -e 2015-07-20
```

* Verify results

Ensure that MapR Music tables exist and dataset is successfully imported:

```
[mapr@yournode ~]$ maprcli table info -path /apps/artists -json

...

[mapr@yournode ~]$ mapr dbshell

maprdb mapr:> find /apps/artists --limit 1
{"_id":"00010eb3-ebfe-4965-81ef-0ac64cd49fde","MBID":"00010eb3-ebfe-4965-81ef-0ac64cd49fde","albums":[],"area":"Sevilla","begin_date":{"$dateDay":"1890-02-10"},"deleted":false,"disambiguation_comment":"","end_date":{"$dateDay":"1969-11-26"},"gender":"Female","images_urls":[],"mbid":"00010eb3-ebfe-4965-81ef-0ac64cd49fde","name":"La Niña de los Peines","profile_image_url":"https://upload.wikimedia.org/wikipedia/commons/8/81/Ni%C3%B1a_los_peines.jpg","rating":2.7205882352941178,"slug_name":"la-nina-de-los-peines","slug_postfix":{"$numberLong":0}}
1 document(s) found.

```

Spark Statistics Job stores results as `csv` file at MapR-FS `/apps/mapr-airflow` directory. Ensure that this directory 
exists and contains valid results:

```
[mapr@yournode ~]$ hadoop fs -ls /apps/mapr-airflow
Found 1 items
drwxr-xr-x   - mapr mapr          2 2018-06-25 14:11 /apps/mapr-airflow/32a2e66b6874d6ad01d8defc485595b70b4ef596


[mapr@yournode ~]$ hadoop fs -ls /apps/mapr-airflow/32a2e66b6874d6ad01d8defc485595b70b4ef596
Found 2 items
drwxr-xr-x   - mapr mapr          2 2018-06-27 16:07 /apps/mapr-airflow/32a2e66b6874d6ad01d8defc485595b70b4ef596/areas-by-artists
drwxr-xr-x   - mapr mapr          2 2018-06-27 16:07 /apps/mapr-airflow/32a2e66b6874d6ad01d8defc485595b70b4ef596/artists-by-albums


[mapr@yournode ~]$ hadoop fs -cat /apps/mapr-airflow/32a2e66b6874d6ad01d8defc485595b70b4ef596/areas-by-artists/part-00000-afe4c306-5f81-4b01-8d45-faea0c169504.csv
United States,2043
Germany,1297
\N,901
United Kingdom,876
Finland,598
Austria,393
South Korea,389
France,296
Italy,220
Japan,211

[mapr@yournode ~]$ hadoop fs -cat /apps/mapr-airflow/32a2e66b6874d6ad01d8defc485595b70b4ef596/artists-by-albums/part-00000-d88ce130-ca6a-4da5-a103-c3f5e194af68.csv
f795c501-1c41-4be2-bc2a-875eba75aa31,Gentle Giant,113
c14b4180-dc87-481e-b17a-64e4150f90f6,Opeth,73
b23e8a63-8f47-4882-b55b-df2c92ef400e,Interpol,65

```


Also, Hive `mapr_music_updates` table must contain latest commit record:

```
[mapr@yournode ~]$ hive shell
hive> select * from mapr_music_updates;
OK
32a2e66b6874d6ad01d8defc485595b70b4ef596	/apps/mapr-airflow/32a2e66b6874d6ad01d8defc485595b70b4ef596
Time taken: 0.129 seconds, Fetched: 1 row(s)

```