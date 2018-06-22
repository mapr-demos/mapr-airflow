package com.mapr.example

import org.apache.spark.sql.SparkSession
import com.mapr.db.spark.sql._

object StatisticsJob {

  def main(args: Array[String]) {

    val spark = SparkSession.builder().appName("StatisticsJob").getOrCreate()

    val languages = spark.loadFromMapRDB("/apps/languages")
    languages.show()
  }

}


