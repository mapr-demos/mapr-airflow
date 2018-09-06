FROM maprtech/pacc:6.0.1_5.0.0_centos7

ENV SLUGIFY_USES_TEXT_UNIDECODE=yes

RUN yum upgrade python-setuptools
RUN yum install -y python-pip git gcc gcc-c++ libffi-devel python-devel python-pip python-wheel openssl-devel libsasl2-devel openldap-devel cyrus-sasl-devel cyrus-sasl-gssapi cyrus-sasl-md5 cyrus-sasl-plain

RUN yum install -y mapr-spark mapr-hive mapr-hiveserver2 mapr-hivemetastore

# TODO: install sqlline

RUN pip install --upgrade setuptools pip
RUN pip install apache-airflow apache-airflow[hive] hmsclient

# Create a directory for your MapR Application and copy the Application
RUN mkdir -p /home/mapr/mapr-apps/mapr-airflow

COPY ./bin /home/mapr/mapr-apps/mapr-airflow/bin
COPY ./dags /home/mapr/mapr-apps/mapr-airflow/dags
COPY ./spark-statistics-job/target/spark-statistics-job-1.0.0-SNAPSHOT.jar /home/mapr/mapr-apps/spark-statistics-job-1.0.0-SNAPSHOT.jar
RUN chmod +x /home/mapr/mapr-apps/mapr-airflow/bin/run.sh

CMD ["/home/mapr/mapr-apps/mapr-airflow/bin/run.sh"]
