FROM maprtech/pacc:6.0.1_5.0.0_centos7

ENV SLUGIFY_USES_TEXT_UNIDECODE=yes

RUN yum upgrade python-setuptools
RUN yum install -y python-pip git gcc gcc-c++ libffi-devel python-devel python-pip python-wheel openssl-devel libsasl2-devel openldap-devel cyrus-sasl-devel cyrus-sasl-gssapi cyrus-sasl-md5 cyrus-sasl-plain

RUN yum install -y mapr-spark

RUN mkdir /tmp/drill-rpm
WORKDIR /tmp/drill-rpm
RUN wget https://package.mapr.com/releases/MEP/MEP-5.0.0/redhat/mapr-drill-internal-1.13.0.201803281600-1.noarch.rpm
RUN wget https://package.mapr.com/releases/MEP/MEP-5.0.0/redhat/mapr-drill-1.13.0.201803281600-1.noarch.rpm
RUN rpm -Uvh mapr-drill-internal-1.13.0.201803281600-1.noarch.rpm
RUN rpm -Uvh --nodeps mapr-drill-1.13.0.201803281600-1.noarch.rpm


RUN pip install --upgrade setuptools pip
RUN pip install apache-airflow apache-airflow[hive] hmsclient

# Workaround for 'hive_hooks' beeline issue
RUN sed -i -e "s/{hql}/{hql}\\\n/g" /usr/lib/python2.7/site-packages/airflow/hooks/hive_hooks.py

# Create a directory for your MapR Application and copy the Application
RUN mkdir -p /home/mapr/mapr-apps/mapr-airflow

COPY ./bin /home/mapr/mapr-apps/mapr-airflow/bin
COPY ./dags /home/mapr/mapr-apps/mapr-airflow/dags
COPY ./spark-statistics-job/target/spark-statistics-job-1.0.0-SNAPSHOT.jar /home/mapr/mapr-apps/spark-statistics-job-1.0.0-SNAPSHOT.jar
RUN chmod +x /home/mapr/mapr-apps/mapr-airflow/bin/run.sh

CMD ["/home/mapr/mapr-apps/mapr-airflow/bin/run.sh"]
