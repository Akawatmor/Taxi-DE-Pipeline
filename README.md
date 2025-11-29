# 🚕 NYC Taxi Data Engineering Pipeline on AWS

[![AWS](https://img.shields.io/badge/AWS-Serverless-orange?logo=amazon-aws)](https://aws.amazon.com/)
[![CloudFormation](https://img.shields.io/badge/IaC-CloudFormation-blue)](https://aws.amazon.com/cloudformation/)

> **Mini Challenge Project**: วิเคราะห์ข้อมูล NYC Taxi เพื่อหา Taxi Type ที่มีการใช้งานมากที่สุดในเดือนมกราคม 2024

**By** Akawat Moradsatian 6609681231

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Problem Statement](#-problem-statement)
- [Architecture](#️-architecture)
- [AWS Services Used](#-aws-services-used)
- [Project Structure](#-project-structure)
- [Prerequisites](#-prerequisites)
- [Deployment Guide](#-deployment-guide)
- [Pipeline Execution](#-pipeline-execution)
- [Data Analysis](#-data-analysis)
- [Demo & Actual Results](#-demo--actual-results)
- [Monitoring & Troubleshooting](#-monitoring--troubleshooting)
- [Cost Optimization](#-cost-optimization)
- [Cleanup](#-cleanup)
- [Technical Details](#-technical-details)

---

## 📖 Overview

โปรเจกต์นี้เป็นการแปลง Jupyter Notebook (Local Environment) ไปสู่ **Serverless Data Engineering Pipeline** บน AWS โดยออกแบบมาสำหรับ **AWS Learner Lab** environment

### 🎯 Key Features

| Feature | Description |
|---------|-------------|
| **Single File Deployment** | Deploy ทั้งระบบด้วย CloudFormation ไฟล์เดียว |
| **Event-Driven** | Trigger อัตโนมัติเมื่อ upload ครบ 4 ไฟล์ |
| **Parallel Processing** | ประมวลผล 4 Taxi Types พร้อมกัน |
| **Auto Analytics** | SageMaker Notebook พร้อมโค้ดวิเคราะห์อัตโนมัติ |
| **Learner Lab Ready** | ใช้ LabRole ที่มีอยู่แล้ว (ไม่สร้าง IAM Role ใหม่) |

---

## 🎯 Problem Statement

### คำถามหลัก
> **"Taxi Type ไหนมี Trips มากที่สุดในเดือนมกราคม 2024?"**

### ข้อมูลที่ใช้
- **Source**: [NYC TLC Trip Record Data](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page)
- **Period**: January 1-31, 2024
- **Format**: Apache Parquet
- **Taxi Types**: 
  - 🟡 Yellow Taxi (Medallion Taxi)
  - 🟢 Green Taxi (Street Hail Livery)
  - 🚐 FHV (For-Hire Vehicle)
  - 📱 FHVHV (High Volume For-Hire Vehicle - Uber/Lyft)

---

## 🏗️ Architecture

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS CLOUD                                       │
│                                                                              │
│  ┌──────────────┐                                                           │
│  │  Data Source │  NYC TLC Trip Record Data (Parquet Files)                 │
│  │  (External)  │  https://d37ci6vzurychx.cloudfront.net/trip-data/         │
│  └──────┬───────┘                                                           │
│         │ aws s3 cp                                                         │
│         ▼                                                                   │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                        INGESTION LAYER                                │  │
│  │  ┌─────────────────┐     ┌─────────────────┐     ┌────────────────┐  │  │
│  │  │   Amazon S3     │────▶│ Amazon Lambda   │────▶│ EventBridge    │  │  │
│  │  │   (Raw Data)    │     │ (File Counter)  │     │ (Trigger)      │  │  │
│  │  │                 │     │                 │     │                │  │  │
│  │  │ /yellow/*.parq  │     │ Count files     │     │ When 4 files   │  │  │
│  │  │ /green/*.parq   │     │ in bucket       │     │ are uploaded   │  │  │
│  │  │ /fhv/*.parq     │     │                 │     │ trigger Step   │  │  │
│  │  │ /fhvhv/*.parq   │     │                 │     │ Functions      │  │  │
│  │  └─────────────────┘     └─────────────────┘     └───────┬────────┘  │  │
│  └──────────────────────────────────────────────────────────┼───────────┘  │
│                                                              │              │
│                                                              ▼              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                     PROCESSING LAYER (Step Functions)                 │  │
│  │                                                                       │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐ │  │
│  │  │              PARALLEL GLUE ETL JOBS                             │ │  │
│  │  │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────────┐   │ │  │
│  │  │  │  Yellow   │ │   Green   │ │    FHV    │ │     FHVHV     │   │ │  │
│  │  │  │  Taxi ETL │ │  Taxi ETL │ │    ETL    │ │      ETL      │   │ │  │
│  │  │  │           │ │           │ │           │ │               │   │ │  │
│  │  │  │ • Remove  │ │ • Remove  │ │ • Remove  │ │ • Remove      │   │ │  │
│  │  │  │   dupes   │ │   dupes   │ │   dupes   │ │   dupes       │   │ │  │
│  │  │  │ • Filter  │ │ • Filter  │ │ • Filter  │ │ • Filter      │   │ │  │
│  │  │  │   dates   │ │   dates   │ │   dates   │ │   dates       │   │ │  │
│  │  │  │ • Remove  │ │ • Remove  │ │ • Remove  │ │ • Remove      │   │ │  │
│  │  │  │   nulls   │ │   nulls   │ │   nulls   │ │   nulls       │   │ │  │
│  │  │  │ • Remove  │ │ • Remove  │ │ • Standard│ │ • Remove      │   │ │  │
│  │  │  │  outliers │ │  outliers │ │   columns │ │   outliers    │   │ │  │
│  │  │  └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └───────┬───────┘   │ │  │
│  │  └────────┼─────────────┼─────────────┼───────────────┼───────────┘ │  │
│  │           │             │             │               │             │  │
│  │           └─────────────┴──────┬──────┴───────────────┘             │  │
│  │                                ▼                                     │  │
│  │                    ┌───────────────────┐                            │  │
│  │                    │    Merge ETL      │                            │  │
│  │                    │                   │                            │  │
│  │                    │ Union all 4 types │                            │  │
│  │                    │ Add taxi_type col │                            │  │
│  │                    │ Standardize cols  │                            │  │
│  │                    └─────────┬─────────┘                            │  │
│  │                              │                                       │  │
│  │                              ▼                                       │  │
│  │                    ┌───────────────────┐                            │  │
│  │                    │   Glue Crawler    │                            │  │
│  │                    │                   │                            │  │
│  │                    │ Catalog merged    │                            │  │
│  │                    │ data to Glue      │                            │  │
│  │                    │ Data Catalog      │                            │  │
│  │                    └─────────┬─────────┘                            │  │
│  │                              │                                       │  │
│  │                              ▼                                       │  │
│  │                    ┌───────────────────┐                            │  │
│  │                    │   Athena Query    │                            │  │
│  │                    │                   │                            │  │
│  │                    │ SELECT taxi_type, │                            │  │
│  │                    │   COUNT(*) ...    │                            │  │
│  │                    │ GROUP BY taxi_type│                            │  │
│  │                    └───────────────────┘                            │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                        STORAGE LAYER                                  │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐   │  │
│  │  │   Amazon S3     │  │   Amazon S3     │  │   Amazon S3         │   │  │
│  │  │  (Cleaned Data) │  │ (Athena Results)│  │  (Glue Scripts)     │   │  │
│  │  │                 │  │                 │  │                     │   │  │
│  │  │ /cleaned/       │  │ /results/       │  │ *.py ETL scripts    │   │  │
│  │  │   yellow/       │  │                 │  │                     │   │  │
│  │  │   green/        │  │                 │  │                     │   │  │
│  │  │   fhv/          │  │                 │  │                     │   │  │
│  │  │   fhvhv/        │  │                 │  │                     │   │  │
│  │  │   merged/       │  │                 │  │                     │   │  │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                       ANALYTICS LAYER                                 │  │
│  │  ┌──────────────────────────────────────────────────────────────┐    │  │
│  │  │                    AWS SageMaker Notebook                     │    │  │
│  │  │  ┌────────────────────────────────────────────────────────┐  │    │  │
│  │  │  │  NYC_Taxi_Analysis.ipynb (Auto-created)                │  │    │  │
│  │  │  │                                                         │  │    │  │
│  │  │  │  • Connect to Athena via PyAthena                      │  │    │  │
│  │  │  │  • Query taxi_pipeline_db.taxi_merged                  │  │    │  │
│  │  │  │  • Generate Bar Chart & Pie Chart                      │  │    │  │
│  │  │  │  • Display final ranking results                       │  │    │  │
│  │  │  └────────────────────────────────────────────────────────┘  │    │  │
│  │  └──────────────────────────────────────────────────────────────┘    │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow Sequence

```
1️⃣ INGEST    →  2️⃣ TRIGGER   →  3️⃣ CLEAN     →  4️⃣ MERGE     →  5️⃣ CATALOG   →  6️⃣ QUERY     →  7️⃣ ANALYZE
   ─────────────────────────────────────────────────────────────────────────────────────────────────────────
   Upload 4      Lambda        Glue ETL       Glue ETL       Glue          Athena         SageMaker
   parquet       counts        (parallel)     (merge)        Crawler       Query          Notebook
   files         files,        clean each     union all      create        aggregate      visualize
   to S3         trigger       taxi type      4 types        table         by type        results
                 if = 4
```

### ภาพ Architecture โดยรวม

![High-level architecture diagram](./Architecture%20Diagram%20(Post).png "Architecture Diagram")
_Figure: High-level architecture of the NYC Taxi pipeline_

---

## 🛠️ AWS Services Used

### Core Services

| Service | Purpose | Configuration |
|---------|---------|---------------|
| **Amazon S3** | Data Lake Storage | 4 buckets: raw, cleaned, results, scripts |
| **AWS Lambda** | File Counter | Python 3.11, triggers when 4 files uploaded |
| **Amazon EventBridge** | Event Routing | S3 → Lambda → Step Functions |
| **AWS Step Functions** | Workflow Orchestration | State machine with parallel execution |
| **AWS Glue** | ETL Processing | Version 4.0, PySpark, G.1X/G.2X workers |
| **AWS Glue Crawler** | Data Cataloging | Auto-detect schema from parquet |
| **Amazon Athena** | SQL Query Engine | Presto-based, serverless |
| **AWS SageMaker** | Analytics Notebook | ml.t3.medium with Lifecycle Config |

### Supporting Services

| Service | Purpose |
|---------|---------|
| **AWS CloudFormation** | Infrastructure as Code |
| **Amazon CloudWatch** | Logging & Monitoring |
| **AWS IAM** | Security (uses existing LabRole) |

### Resource Naming Convention

```
{EnvironmentName}-{ResourceType}-{AccountId}

Example:
- taxi-pipeline-raw-data-754289373217
- taxi-pipeline-cleaned-data-754289373217
- taxi-pipeline-athena-results-754289373217
- taxi-pipeline-glue-scripts-754289373217
```

---

## 📁 Project Structure

```
aws-taxi-pipeline/
│
├── 📂 cloudformation/
│   └── 📄 taxi-pipeline-stack.yaml    # Complete infrastructure (800+ lines)
│                                        # Includes: S3, Lambda, EventBridge,
│                                        # Step Functions, Glue, Athena, SageMaker
│
├── 📂 glue-scripts/
│   ├── 📄 yellow_taxi_etl.py          # Yellow taxi data cleaning
│   │                                    # - Remove duplicates
│   │                                    # - Filter Jan 2024
│   │                                    # - Remove invalid locations
│   │                                    # - Clean fare outliers
│   │
│   ├── 📄 green_taxi_etl.py           # Green taxi data cleaning
│   │                                    # - Same cleaning logic as yellow
│   │                                    # - Different column mapping
│   │
│   ├── 📄 fhv_taxi_etl.py             # For-Hire Vehicle cleaning
│   │                                    # - Simpler schema
│   │                                    # - No fare data
│   │
│   ├── 📄 fhvhv_taxi_etl.py           # High-Volume FHV cleaning
│   │                                    # - Uber/Lyft data
│   │                                    # - Rich trip details
│   │
│   └── 📄 merge_data_etl.py           # Merge all 4 types
│                                        # - Union with taxi_type column
│                                        # - Standardized output schema
│
├── 📂 sagemaker-notebooks/
│   └── 📄 taxi_analysis.ipynb         # Analysis notebook (backup)
│                                        # Auto-created by Lifecycle Config
│
├── 📄 deploy.ps1                       # Windows PowerShell deployment
├── 📄 deploy.sh                        # Linux/Mac Bash deployment
├── 📄 ingest-data.ps1                  # Data upload script
└── 📄 README.md                        # This documentation
```

---

## 📋 Prerequisites

### 1. AWS Account Setup

#### For Learner Lab
```
✅ Access to AWS Academy Learner Lab
✅ Lab must be STARTED (green indicator)
✅ Copy LabRole ARN from IAM Console
```

#### For Regular AWS Account
```
✅ AWS Account with Administrator access
✅ IAM permissions for: S3, Glue, Athena, Lambda, Step Functions, SageMaker
```

### 2. Local Environment

| Requirement | Version | Check Command |
|-------------|---------|---------------|
| AWS CLI | v2.x | `aws --version` |
| PowerShell | 5.1+ | `$PSVersionTable.PSVersion` |
| Git (optional) | Any | `git --version` |

### 3. AWS CLI Configuration

```powershell
# Configure AWS CLI with Learner Lab credentials
aws configure

# For Learner Lab, also set session token
aws configure set aws_session_token "YOUR_SESSION_TOKEN"

# Verify configuration
aws sts get-caller-identity
```

**Expected Output:**
```json
{
    "UserId": "AROA...:user123",
    "Account": "754289373217",
    "Arn": "arn:aws:sts::754289373217:assumed-role/voclabs/user123"
}
```

---

## 🚀 Deployment Guide

### Step 1: Get Your LabRole ARN

```powershell
# Find your LabRole ARN
aws iam get-role --role-name LabRole --query 'Role.Arn' --output text
```

**Expected Output:**
```
arn:aws:iam::754289373217:role/LabRole
```

### Step 2: Deploy CloudFormation Stack

#### Option A: Using AWS CLI (Recommended)

```powershell
# Navigate to project directory
cd aws-taxi-pipeline

# Deploy the stack
aws cloudformation create-stack `
    --stack-name taxi-pipeline `
    --template-body file://cloudformation/taxi-pipeline-stack.yaml `
    --capabilities CAPABILITY_NAMED_IAM `
    --parameters ParameterKey=LabRoleARN,ParameterValue=arn:aws:iam::754289373217:role/LabRole

# Wait for completion (takes ~5-10 minutes)
aws cloudformation wait stack-create-complete --stack-name taxi-pipeline

# Check status
aws cloudformation describe-stacks --stack-name taxi-pipeline --query 'Stacks[0].StackStatus'
```

#### Option B: Using PowerShell Script

```powershell
cd aws-taxi-pipeline
.\deploy.ps1 -StackName "taxi-pipeline" -Region "us-east-1"
```

#### Option C: Using AWS Console

1. Open [CloudFormation Console](https://console.aws.amazon.com/cloudformation)
2. Click **Create stack** → **With new resources**
3. Upload `taxi-pipeline-stack.yaml`
4. Stack name: `taxi-pipeline`
5. Parameters:
   - LabRoleARN: `arn:aws:iam::YOUR_ACCOUNT_ID:role/LabRole`
6. Acknowledge IAM capabilities
7. Create stack

### Step 3: Upload Glue Scripts to S3

```powershell
# Get the Glue scripts bucket name
$BUCKET = aws cloudformation describe-stacks `
    --stack-name taxi-pipeline `
    --query 'Stacks[0].Outputs[?OutputKey==`GlueScriptsBucketName`].OutputValue' `
    --output text

# Upload all ETL scripts
aws s3 cp glue-scripts/yellow_taxi_etl.py s3://$BUCKET/scripts/
aws s3 cp glue-scripts/green_taxi_etl.py s3://$BUCKET/scripts/
aws s3 cp glue-scripts/fhv_taxi_etl.py s3://$BUCKET/scripts/
aws s3 cp glue-scripts/fhvhv_taxi_etl.py s3://$BUCKET/scripts/
aws s3 cp glue-scripts/merge_data_etl.py s3://$BUCKET/scripts/

# Verify upload
aws s3 ls s3://$BUCKET/scripts/
```

### Step 4: Verify Deployment

```powershell
# List all created resources
aws cloudformation describe-stack-resources `
    --stack-name taxi-pipeline `
    --query 'StackResources[].{Type:ResourceType,Name:PhysicalResourceId,Status:ResourceStatus}' `
    --output table
```

---

## 🔄 Pipeline Execution

### Step 1: Download NYC Taxi Data

```powershell
# Create temp directory
mkdir tempdata
cd tempdata

# Download all 4 parquet files (~500MB total)
# Yellow Taxi (~50MB)
curl -o yellow_tripdata_2024-01.parquet https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2024-01.parquet

# Green Taxi (~2MB)
curl -o green_tripdata_2024-01.parquet https://d37ci6vzurychx.cloudfront.net/trip-data/green_tripdata_2024-01.parquet

# FHV (~10MB)
curl -o fhv_tripdata_2024-01.parquet https://d37ci6vzurychx.cloudfront.net/trip-data/fhv_tripdata_2024-01.parquet

# FHVHV (~400MB)
curl -o fhvhv_tripdata_2024-01.parquet https://d37ci6vzurychx.cloudfront.net/trip-data/fhvhv_tripdata_2024-01.parquet

# Verify downloads
ls -la *.parquet
```

### Step 2: Upload to S3 (Triggers Pipeline)

```powershell
# Get raw data bucket name
$RAW_BUCKET = aws cloudformation describe-stacks `
    --stack-name taxi-pipeline `
    --query 'Stacks[0].Outputs[?OutputKey==`RawDataBucketName`].OutputValue' `
    --output text

# Upload all 4 files (pipeline triggers when 4th file is uploaded)
aws s3 cp yellow_tripdata_2024-01.parquet s3://$RAW_BUCKET/yellow/
aws s3 cp green_tripdata_2024-01.parquet s3://$RAW_BUCKET/green/
aws s3 cp fhv_tripdata_2024-01.parquet s3://$RAW_BUCKET/fhv/
aws s3 cp fhvhv_tripdata_2024-01.parquet s3://$RAW_BUCKET/fhvhv/

echo "✅ All files uploaded! Pipeline should start automatically."
```

### Step 3: Monitor Pipeline Execution

```powershell
# Get Step Functions ARN
$STATE_MACHINE = aws cloudformation describe-stacks `
    --stack-name taxi-pipeline `
    --query 'Stacks[0].Outputs[?OutputKey==`StepFunctionsArn`].OutputValue' `
    --output text

# List recent executions
aws stepfunctions list-executions `
    --state-machine-arn $STATE_MACHINE `
    --query 'executions[0:3].{Name:name,Status:status,Start:startDate}' `
    --output table
```

**Or via AWS Console:**
1. Open [Step Functions Console](https://console.aws.amazon.com/states)
2. Click on `taxi-pipeline-state-machine`
3. View execution graph and status

### Pipeline Duration

| Stage | Estimated Time |
|-------|---------------|
| Yellow Taxi ETL | ~3-5 min |
| Green Taxi ETL | ~1-2 min |
| FHV ETL | ~2-3 min |
| FHVHV ETL | ~8-12 min |
| Merge ETL | ~5-8 min |
| Crawler | ~2-3 min |
| Athena Query | ~10-30 sec |
| **Total** | **~25-40 min** |

---

## 📊 Data Analysis

### Option 1: SageMaker Notebook (Recommended)

1. **Open SageMaker Console**
   - Go to [SageMaker Console](https://console.aws.amazon.com/sagemaker)
   - Click **Notebook instances**
   - Find `taxi-pipeline-analytics-notebook`

2. **Start Notebook** (if stopped)
   - Click **Start**
   - Wait for status = `InService`

3. **Open JupyterLab**
   - Click **Open JupyterLab**
   - Navigate to `NYC_Taxi_Analysis.ipynb` (auto-created)

4. **Run Analysis**
   - Run all cells (`Shift + Enter`)
   - View charts and results

### Option 2: Athena Console Query

```sql
-- Open Athena Console and run:

-- 1. Check available tables
SHOW TABLES IN taxi_pipeline_db;

-- 2. Preview data
SELECT * FROM taxi_pipeline_db.taxi_merged LIMIT 10;

-- 3. Main analysis query
SELECT 
    taxi_type,
    COUNT(*) as trip_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM taxi_pipeline_db.taxi_merged
GROUP BY taxi_type
ORDER BY trip_count DESC;
```

### Expected Results

| Rank | Taxi Type | Trip Count | Percentage |
|------|-----------|------------|------------|
| 1 | FHVHV | ~20M+ | ~75% |
| 2 | Yellow | ~3M+ | ~12% |
| 3 | FHV | ~2M+ | ~8% |
| 4 | Green | ~60K+ | ~0.2% |

> **🥇 Answer: FHVHV (Uber/Lyft) is the most used taxi type in NYC (January 2024)**

---

## 🎬 Demo & Actual Results

### 📹 Demo Video

<video src="https://static2.petchsko123.dpdns.org/cs341/minilab-taxi/minilab-lastpipeline-6609681231.mp4" controls="controls" style="max-width: 100%;">
  Your browser does not support the video tag.
</video>

https://github.com/user-attachments/assets/f9e1d414-8a46-46d2-9850-6ae73b934764

> 📎 **Direct Link:** [https://static2.petchsko123.dpdns.org/cs341/minilab-taxi/minilab-lastpipeline-6609681231.mp4](https://static2.petchsko123.dpdns.org/cs341/minilab-taxi/minilab-lastpipeline-6609681231.mp4)

### 📊 Actual Pipeline Results (28 September Run)

| Rank | Taxi Type | Trip Count | Percentage |
|------|-----------|------------|------------|
| 🥇 1 | **FHVHV** | **19,657,306** | **86.48%** |
| 🥈 2 | Yellow | 2,756,703 | 12.13% |
| 🥉 3 | FHV | 262,654 | 1.16% |
| 4 | Green | 52,708 | 0.23% |

### 🏆 Summary

> **🚀 Top Taxi Type: FHVHV (Uber/Lyft) with 19,657,306 rides (86.48%)**
>
> High Volume For-Hire Vehicles (FHVHV) ซึ่งรวม Uber และ Lyft ครองส่วนแบ่งตลาดมากที่สุดใน NYC ในเดือนมกราคม 2024 คิดเป็นสัดส่วนถึง 86.48% ของการเดินทางทั้งหมด!

---

## 🔍 Monitoring & Troubleshooting

### CloudWatch Logs

```powershell
# View Glue job logs
aws logs describe-log-groups --log-group-name-prefix "/aws-glue/jobs"

# Get recent log events
aws logs get-log-events `
    --log-group-name "/aws-glue/jobs/output" `
    --log-stream-name "yellow-taxi-etl" `
    --limit 50
```

### Common Issues

#### 1. Pipeline Not Triggering

**Symptom:** Files uploaded but Step Functions not starting

**Solution:**
```powershell
# Check if Lambda was invoked
aws logs tail /aws/lambda/taxi-pipeline-file-counter --since 1h

# Verify 4 files exist
aws s3 ls s3://$RAW_BUCKET/ --recursive | grep parquet
```

#### 2. Glue Job Failed

**Symptom:** Step Functions shows failed state

**Solution:**
```powershell
# Check Glue job run details
aws glue get-job-runs --job-name yellow-taxi-etl

# View error message
aws glue get-job-run --job-name yellow-taxi-etl --run-id jr_xxx
```

#### 3. Athena Query Error

**Symptom:** Table not found or column errors

**Solution:**
```sql
-- Verify table exists
SHOW TABLES IN taxi_pipeline_db;

-- Check table schema
DESCRIBE taxi_pipeline_db.taxi_merged;

-- Check if data exists
SELECT COUNT(*) FROM taxi_pipeline_db.taxi_merged;
```

#### 4. SageMaker Notebook Empty

**Symptom:** No `NYC_Taxi_Analysis.ipynb` file

**Solution:**
```
1. Stop the notebook instance
2. Start it again (triggers Lifecycle Config)
3. Wait 2-3 minutes for startup script
4. Refresh JupyterLab file browser
```

---

## 💰 Cost Optimization

### Estimated Costs (per pipeline run)

| Service | Usage | Estimated Cost |
|---------|-------|---------------|
| S3 Storage | ~1GB | $0.023 |
| Glue ETL | ~5 DPU-hours | $2.20 |
| Athena Query | ~1GB scanned | $0.005 |
| Lambda | 5 invocations | $0.00 |
| Step Functions | 20 transitions | $0.00 |
| SageMaker | 1 hour ml.t3.medium | $0.05 |
| **Total** | | **~$2.30** |

### Tips for Learner Lab

1. **Stop SageMaker when not in use**
   ```powershell
   aws sagemaker stop-notebook-instance --notebook-instance-name taxi-pipeline-analytics-notebook
   ```

2. **Use smaller Glue workers**
   - G.1X (4 vCPU, 16GB) instead of G.2X for smaller datasets

3. **Clean up old data**
   ```powershell
   # Delete old Athena results (auto-deleted after 30 days)
   aws s3 rm s3://$RESULTS_BUCKET/ --recursive
   ```

4. **Monitor remaining credits**
   - Check AWS Academy dashboard
   - Typical budget: $100 per lab

---

## 🧹 Cleanup

### Delete All Resources

```powershell
# 1. Empty S3 buckets first (required before stack deletion)
$BUCKETS = @(
    "taxi-pipeline-raw-data-754289373217",
    "taxi-pipeline-cleaned-data-754289373217",
    "taxi-pipeline-athena-results-754289373217",
    "taxi-pipeline-glue-scripts-754289373217"
)

foreach ($bucket in $BUCKETS) {
    Write-Host "Emptying $bucket..."
    aws s3 rm s3://$bucket --recursive
}

# 2. Delete CloudFormation stack
aws cloudformation delete-stack --stack-name taxi-pipeline

# 3. Wait for deletion
aws cloudformation wait stack-delete-complete --stack-name taxi-pipeline

Write-Host "✅ All resources deleted!"
```

### Verify Cleanup

```powershell
# Check stack is deleted
aws cloudformation describe-stacks --stack-name taxi-pipeline

# Should return: "Stack with id taxi-pipeline does not exist"
```

---

## 🔧 Technical Details

### ETL Processing Logic

#### Data Cleaning Steps (All Taxi Types)

```python
# 1. Remove duplicates
df = df.dropDuplicates()

# 2. Filter to January 2024
df = df.filter(
    (col("pickup_datetime") >= "2024-01-01") & 
    (col("pickup_datetime") < "2024-02-01")
)

# 3. Remove null location IDs
df = df.filter(
    col("PULocationID").isNotNull() & 
    col("DOLocationID").isNotNull()
)

# 4. Remove outliers (for Yellow/Green)
df = df.filter(
    (col("fare_amount") > 0) & 
    (col("fare_amount") < 500) &
    (col("trip_distance") > 0) &
    (col("trip_distance") < 100)
)
```

#### Output Schema (Standardized)

| Column | Type | Description |
|--------|------|-------------|
| taxi_type | string | "Yellow", "Green", "FHV", "FHVHV" |
| pickup_datetime | timestamp | Trip start time |
| dropoff_datetime | timestamp | Trip end time |
| PULocationID | int | Pickup location zone |
| DOLocationID | int | Dropoff location zone |

### Step Functions State Machine

```json
{
  "StartAt": "ProcessTaxiDataParallel",
  "States": {
    "ProcessTaxiDataParallel": {
      "Type": "Parallel",
      "Branches": [
        {"StartAt": "YellowTaxiETL", ...},
        {"StartAt": "GreenTaxiETL", ...},
        {"StartAt": "FhvETL", ...},
        {"StartAt": "FhvhvETL", ...}
      ],
      "Next": "MergeAllData"
    },
    "MergeAllData": {...},
    "RunCrawler": {...},
    "WaitForCrawler": {...},
    "RunAthenaQuery": {...}
  }
}
```

### CloudFormation Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| EnvironmentName | taxi-pipeline | Prefix for all resources |
| DataMonth | 2024-01 | Data period (YYYY-MM) |
| GlueJobTimeout | 60 | ETL job timeout (minutes) |
| LabRoleARN | - | **Required** - Your LabRole ARN |

---

## 📝 Original Notebook Mapping

| Local Notebook Stage | AWS Implementation | Details |
|---------------------|-------------------|---------|
| 1. Import Libraries | Lambda + Glue | boto3, pyspark |
| 2. Download Data | S3 + aws cli | Parquet from NYC TLC |
| 3. Load Data | Glue ETL | DynamicFrame / DataFrame |
| 4. Clean Data | Glue ETL | Remove nulls, dupes, outliers |
| 5. Transform | Glue ETL (Merge) | Union + taxi_type column |
| 6. Aggregate | Athena Query | GROUP BY taxi_type |
| 7. Visualize | SageMaker Notebook | Matplotlib, Seaborn |
| 8. Report | SageMaker Notebook | Final ranking output |

---

## 📚 References

- [NYC TLC Trip Record Data](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page)
- [AWS Glue Developer Guide](https://docs.aws.amazon.com/glue/latest/dg/what-is-glue.html)
- [AWS Step Functions Guide](https://docs.aws.amazon.com/step-functions/latest/dg/welcome.html)
- [Amazon Athena User Guide](https://docs.aws.amazon.com/athena/latest/ug/what-is.html)
- [AWS CloudFormation User Guide](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html)

---

**Created by:** Akawat Moradsatian (6609681231)  
**Course:** Data Engineering Pipeline on AWS  
**Date:** November 2024
