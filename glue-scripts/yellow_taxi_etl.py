"""
Yellow Taxi ETL Job
AWS Glue Job for cleaning and transforming Yellow Taxi data
Based on: MiniChallenge_TaxiType_Jan2024 notebook
"""

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.functions import col, lit
from pyspark.sql.types import TimestampType

# Get job parameters
args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'RAW_BUCKET',
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
RAW_BUCKET = args['RAW_BUCKET']
CLEANED_BUCKET = args['CLEANED_BUCKET']
DATA_MONTH = args['DATA_MONTH']  # e.g., '2024-01'

# Parse month for date filtering
year, month = DATA_MONTH.split('-')
start_date = f"{year}-{month}-01"
if int(month) == 12:
    end_date = f"{int(year)+1}-01-01"
else:
    end_date = f"{year}-{int(month)+1:02d}-01"

print(f"=== Cleaning Yellow Taxi Data ===")
print(f"Source: s3://{RAW_BUCKET}/yellow/")
print(f"Target: s3://{CLEANED_BUCKET}/cleaned/yellow/")
print(f"Date Range: {start_date} to {end_date}")

# Read raw data
input_path = f"s3://{RAW_BUCKET}/yellow/"
yellow_df = spark.read.parquet(input_path)

# Get original count
original_count = yellow_df.count()
print(f"Original Yellow Taxi records: {original_count:,}")

# Data Cleaning Steps (based on notebook logic)
# 1. Remove duplicates
# 2. Filter out negative values
# 3. Filter date range
# 4. Remove nulls in critical columns
# 5. Remove outliers

cleaned_df = yellow_df \
    .dropDuplicates(['VendorID', 'tpep_pickup_datetime', 'tpep_dropoff_datetime', 
                     'passenger_count', 'trip_distance', 'PULocationID', 'DOLocationID']) \
    .filter(col('passenger_count') >= 0) \
    .filter(col('trip_distance') >= 0) \
    .filter(col('tpep_pickup_datetime').isNotNull()) \
    .filter(col('tpep_dropoff_datetime').isNotNull()) \
    .filter(col('PULocationID').isNotNull()) \
    .filter(col('DOLocationID').isNotNull()) \
    .filter(col('passenger_count').isNotNull()) \
    .filter(col('trip_distance').isNotNull()) \
    .filter(col('tpep_dropoff_datetime') > col('tpep_pickup_datetime')) \
    .filter(col('tpep_pickup_datetime') >= start_date) \
    .filter(col('tpep_pickup_datetime') < end_date) \
    .filter(col('tpep_dropoff_datetime') >= start_date) \
    .filter(col('tpep_dropoff_datetime') < end_date) \
    .filter(col('fare_amount') >= 0) \
    .filter(col('tip_amount') >= 0) \
    .filter(col('fare_amount') <= 10000) \
    .filter(col('trip_distance') <= 1000)

# Add taxi type column for later merging
cleaned_df = cleaned_df.withColumn('taxi_type', lit('Yellow'))

# Rename datetime columns for standardization
cleaned_df = cleaned_df \
    .withColumnRenamed('tpep_pickup_datetime', 'pickup_datetime') \
    .withColumnRenamed('tpep_dropoff_datetime', 'dropoff_datetime')

# Get final count
final_count = cleaned_df.count()
records_removed = original_count - final_count
print(f"Yellow Taxi - Final cleaned records: {final_count:,} (removed {records_removed:,})")

# Write cleaned data
output_path = f"s3://{CLEANED_BUCKET}/cleaned/yellow/"
cleaned_df.write \
    .mode('overwrite') \
    .parquet(output_path)

print(f"✓ Yellow Taxi cleaning completed")
print(f"Output saved to: {output_path}")

job.commit()
