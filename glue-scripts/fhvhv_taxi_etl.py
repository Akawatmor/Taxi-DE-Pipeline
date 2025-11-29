"""
FHVHV (High Volume For-Hire Vehicle) ETL Job
AWS Glue Job for cleaning and transforming FHVHV data (Uber, Lyft, etc.)
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
DATA_MONTH = args['DATA_MONTH']

# Parse month for date filtering
year, month = DATA_MONTH.split('-')
start_date = f"{year}-{month}-01"
if int(month) == 12:
    end_date = f"{int(year)+1}-01-01"
else:
    end_date = f"{year}-{int(month)+1:02d}-01"

print(f"=== Cleaning FHVHV Data ===")
print(f"Source: s3://{RAW_BUCKET}/fhvhv/")
print(f"Target: s3://{CLEANED_BUCKET}/cleaned/fhvhv/")
print(f"Date Range: {start_date} to {end_date}")

# Read raw data
input_path = f"s3://{RAW_BUCKET}/fhvhv/"
fhvhv_df = spark.read.parquet(input_path)

# Get original count
original_count = fhvhv_df.count()
print(f"Original FHVHV records: {original_count:,}")

# Data Cleaning Steps
# FHVHV columns: hvfhs_license_num, pickup_datetime, dropoff_datetime, PULocationID, DOLocationID
cleaned_df = fhvhv_df \
    .dropDuplicates(['hvfhs_license_num', 'pickup_datetime', 'dropoff_datetime', 
                     'PULocationID', 'DOLocationID']) \
    .filter(col('pickup_datetime').isNotNull()) \
    .filter(col('dropoff_datetime').isNotNull()) \
    .filter(col('PULocationID').isNotNull()) \
    .filter(col('DOLocationID').isNotNull()) \
    .filter(col('hvfhs_license_num').isNotNull()) \
    .filter(col('dropoff_datetime') > col('pickup_datetime')) \
    .filter(col('pickup_datetime') >= start_date) \
    .filter(col('pickup_datetime') < end_date) \
    .filter(col('dropoff_datetime') >= start_date) \
    .filter(col('dropoff_datetime') < end_date)

# Add taxi type column for later merging
cleaned_df = cleaned_df.withColumn('taxi_type', lit('FHVHV'))

# Get final count
final_count = cleaned_df.count()
records_removed = original_count - final_count
print(f"FHVHV - Final cleaned records: {final_count:,} (removed {records_removed:,})")

# Write cleaned data
output_path = f"s3://{CLEANED_BUCKET}/cleaned/fhvhv/"
cleaned_df.write \
    .mode('overwrite') \
    .parquet(output_path)

print(f"✓ FHVHV cleaning completed")
print(f"Output saved to: {output_path}")

job.commit()
