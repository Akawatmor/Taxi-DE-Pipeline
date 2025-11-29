"""
Merge All Taxi Data ETL Job
AWS Glue Job for merging all cleaned taxi data into a unified schema
Based on: MiniChallenge_TaxiType_Jan2024 notebook Transform Stage
"""

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import col, lit
from pyspark.sql.types import StructType, StructField, StringType, TimestampType, IntegerType

# Get job parameters
args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'CLEANED_BUCKET',
    'DATA_MONTH'
])

# Initialize Glue context
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Configuration
CLEANED_BUCKET = args['CLEANED_BUCKET']
DATA_MONTH = args['DATA_MONTH']

print(f"=== Merging All Taxi Data ===")
print(f"Source: s3://{CLEANED_BUCKET}/cleaned/")
print(f"Target: s3://{CLEANED_BUCKET}/merged/")

# Define unified schema for merged data
unified_columns = ['taxi_type', 'pickup_datetime', 'dropoff_datetime', 'PULocationID', 'DOLocationID']

# Read all cleaned datasets
print("Reading Yellow Taxi data...")
yellow_path = f"s3://{CLEANED_BUCKET}/cleaned/yellow/"
yellow_df = spark.read.parquet(yellow_path) \
    .select('taxi_type', 'pickup_datetime', 'dropoff_datetime', 'PULocationID', 'DOLocationID')
yellow_count = yellow_df.count()
print(f"Yellow Taxi records: {yellow_count:,}")

print("Reading Green Taxi data...")
green_path = f"s3://{CLEANED_BUCKET}/cleaned/green/"
green_df = spark.read.parquet(green_path) \
    .select('taxi_type', 'pickup_datetime', 'dropoff_datetime', 'PULocationID', 'DOLocationID')
green_count = green_df.count()
print(f"Green Taxi records: {green_count:,}")

print("Reading FHV data...")
fhv_path = f"s3://{CLEANED_BUCKET}/cleaned/fhv/"
fhv_df = spark.read.parquet(fhv_path) \
    .select('taxi_type', 'pickup_datetime', 'dropoff_datetime', 'PULocationID', 'DOLocationID')
fhv_count = fhv_df.count()
print(f"FHV records: {fhv_count:,}")

print("Reading FHVHV data...")
fhvhv_path = f"s3://{CLEANED_BUCKET}/cleaned/fhvhv/"
fhvhv_df = spark.read.parquet(fhvhv_path) \
    .select('taxi_type', 'pickup_datetime', 'dropoff_datetime', 'PULocationID', 'DOLocationID')
fhvhv_count = fhvhv_df.count()
print(f"FHVHV records: {fhvhv_count:,}")

# Merge all datasets using UNION ALL
print("\nMerging all datasets...")
merged_df = yellow_df \
    .union(green_df) \
    .union(fhv_df) \
    .union(fhvhv_df)

# Get total count
total_count = merged_df.count()
print(f"\n✓ Successfully merged all datasets: {total_count:,} total records")

# Verify merge by counting per type
print("\nRecords per taxi type after merging:")
type_counts = merged_df.groupBy('taxi_type').count().orderBy(col('count').desc()).collect()
for row in type_counts:
    print(f"  {row['taxi_type']}: {row['count']:,}")

# Write merged data partitioned by taxi_type for efficient querying
output_path = f"s3://{CLEANED_BUCKET}/merged/"
print(f"\nWriting merged data to: {output_path}")

merged_df.write \
    .mode('overwrite') \
    .partitionBy('taxi_type') \
    .parquet(output_path)

print(f"\n✓ Merge completed successfully!")
print(f"Output saved to: {output_path}")

# Also create a summary statistics file
print("\n=== Generating Summary Statistics ===")
summary_df = spark.createDataFrame([
    ('Yellow', yellow_count, round(yellow_count * 100.0 / total_count, 2)),
    ('Green', green_count, round(green_count * 100.0 / total_count, 2)),
    ('FHV', fhv_count, round(fhv_count * 100.0 / total_count, 2)),
    ('FHVHV', fhvhv_count, round(fhvhv_count * 100.0 / total_count, 2))
], ['taxi_type', 'trip_count', 'percentage'])

summary_path = f"s3://{CLEANED_BUCKET}/summary/"
summary_df.write \
    .mode('overwrite') \
    .parquet(summary_path)

print(f"Summary saved to: {summary_path}")

job.commit()
