package com.mapr.example

import org.apache.spark.sql.{SaveMode, SparkSession}

object TopArtistsJob {

  val TopArtistsNum = 3

  def main(args: Array[String]) {

    if (args.length < 2) {
      throw new RuntimeException(s"Usage: ${TopArtistsJob.getClass.getName} <parquet-file-path> <result-directory-mfs-path> <commit-sha>")
    }

    val parquetFilePath = args(0)
    val resultDirectoryPath = args(1)
    val commitSha = args(2)
    val spark = SparkSession.builder().appName("TopArtistsJob").getOrCreate()
    import org.apache.spark.sql.functions._

    val topArtistsDF = spark.read.parquet(parquetFilePath)
      .orderBy(desc("albums_number"))
      .limit(TopArtistsNum)

    topArtistsDF.write
      .format("csv")
      .mode(SaveMode.Overwrite)
      .save(s"$resultDirectoryPath/$commitSha/artists-by-albums")
  }

}


