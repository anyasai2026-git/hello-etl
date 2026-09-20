"""
Tier 0 ETL — customers_etl.py  (runs as an AWS Glue PySpark job)
Flow:  raw CSV (S3) -> clean/transform -> processed Parquet (S3)
"""
import sys
from datetime import datetime
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import functions as F

args = getResolvedOptions(sys.argv, ["JOB_NAME", "raw_path", "processed_path"])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

# EXTRACT
df = (spark.read.option("header", True).option("inferSchema", True)
      .csv(args["raw_path"]))
print(f"[EXTRACT] rows read: {df.count()}")
df.printSchema()

# TRANSFORM: uppercase+trim name, drop null email, stamp date
transformed = (df
    .withColumn("name", F.upper(F.trim(F.col("name"))))
    .filter(F.col("email").isNotNull() & (F.trim(F.col("email")) != ""))
    .withColumn("processed_date", F.lit(datetime.utcnow().strftime("%Y-%m-%d"))))
print(f"[TRANSFORM] rows after cleaning: {transformed.count()}")

# LOAD
transformed.write.mode("overwrite").parquet(args["processed_path"])
print(f"[LOAD] written to: {args['processed_path']}")

job.commit()
print("[DONE] job committed successfully")
