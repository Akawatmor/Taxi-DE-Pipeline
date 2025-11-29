"""
FHV (For-Hire Vehicle) ETL Job
AWS Glue Job for cleaning and transforming FHV data
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

print(f"=== Cleaning FHV Data ===")
print(f"Source: s3://{RAW_BUCKET}/fhv/")
print(f"Target: s3://{CLEANED_BUCKET}/cleaned/fhv/")
print(f"Date Range: {start_date} to {end_date}")

# Read raw data
input_path = f"s3://{RAW_BUCKET}/fhv/"
fhv_df = spark.read.parquet(input_path)

# Get original count
original_count = fhv_df.count()
print(f"Original FHV records: {original_count:,}")

# Data Cleaning Steps
# FHV has different column names: pickup_datetime, dropOff_datetime, PUlocationID, DOlocationID
cleaned_df = fhv_df \
    .dropDuplicates(['dispatching_base_num', 'pickup_datetime', 'dropOff_datetime', 
                     'PUlocationID', 'DOlocationID']) \
    .filter(col('pickup_datetime').isNotNull()) \
    .filter(col('dropOff_datetime').isNotNull()) \
    .filter(col('PUlocationID').isNotNull()) \
    .filter(col('DOlocationID').isNotNull()) \
    .filter(col('dispatching_base_num').isNotNull()) \
    .filter(col('dropOff_datetime') > col('pickup_datetime')) \
    .filter(col('pickup_datetime') >= start_date) \
    .filter(col('pickup_datetime') < end_date) \
    .filter(col('dropOff_datetime') >= start_date) \
    .filter(col('dropOff_datetime') < end_date)

# Add taxi type column for later merging
cleaned_df = cleaned_df.withColumn('taxi_type', lit('FHV'))

# Rename columns for standardization
cleaned_df = cleaned_df \
    .withColumnRenamed('dropOff_datetime', 'dropoff_datetime') \
    .withColumnRenamed('PUlocationID', 'PULocationID') \
    .withColumnRenamed('DOlocationID', 'DOLocationID')

# Get final count
final_count = cleaned_df.count()
records_removed = original_count - final_count
print(f"FHV - Final cleaned records: {final_count:,} (removed {records_removed:,})")

# Write cleaned data
output_path = f"s3://{CLEANED_BUCKET}/cleaned/fhv/"
cleaned_df.write \
    .mode('overwrite') \
    .parquet(output_path)

print(f"✓ FHV cleaning completed")
print(f"Output saved to: {output_path}")

job.commit()
