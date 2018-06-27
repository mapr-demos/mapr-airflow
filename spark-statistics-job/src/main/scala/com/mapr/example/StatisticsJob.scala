package com.mapr.example

import com.mapr.db.spark.sql._
import org.apache.spark.sql.{SaveMode, SparkSession}

object StatisticsJob {

  def main(args: Array[String]) {

    if (args.length < 2) {
      throw new RuntimeException(s"Usage: ${StatisticsJob.getClass.getName} <result-directory-mfs-path> <commit-sha>")
    }

    val resultDirectoryPath = args(0)
    val commitSha = args(1)
    val spark = SparkSession.builder().appName("StatisticsJob").getOrCreate()
    import spark.implicits._

    val topAreasDF = spark.loadFromMapRDB("/apps/artists")
      .select("area").as[String].rdd
      .map(area => (area, 1))
      .reduceByKey(_ + _)
      .sortBy(_._2, ascending = false)
      .toDF()
      .limit(10)

    topAreasDF.write
      .format("csv")
      .mode(SaveMode.Overwrite)
      .save(s"$resultDirectoryPath/$commitSha/areas-by-artists")
  }

}


