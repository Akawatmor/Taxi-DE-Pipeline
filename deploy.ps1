# =============================================================================
# NYC Taxi Data Pipeline - Deployment Script (PowerShell)
# Deploy the complete data engineering pipeline to AWS
# Designed for AWS Learner Lab Environment
# =============================================================================

param(
    [string]$StackName = "taxi-pipeline",
    [string]$Region = $env:AWS_DEFAULT_REGION,
    [string]$DataMonth = "2024-01"
)

# Set default region if not provided
if (-not $Region) {
    $Region = "us-east-1"
}

Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║       NYC Taxi Data Engineering Pipeline - Deployment           ║" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

# Check AWS CLI
Write-Host "[1/6] Checking AWS CLI..." -ForegroundColor Yellow
try {
    $null = aws --version
    Write-Host "✓ AWS CLI found" -ForegroundColor Green
} catch {
    Write-Host "Error: AWS CLI is not installed" -ForegroundColor Red
    exit 1
}

# Verify AWS credentials
Write-Host "[2/6] Verifying AWS credentials..." -ForegroundColor Yellow
try {
    $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
    $AccountId = $identity.Account
    Write-Host "✓ AWS Account: $AccountId" -ForegroundColor Green
    Write-Host "✓ Region: $Region" -ForegroundColor Green
} catch {
    Write-Host "Error: AWS credentials not configured" -ForegroundColor Red
    Write-Host "Please run: aws configure"
    exit 1
}

# Deploy CloudFormation Stack
Write-Host "[3/6] Deploying CloudFormation Stack..." -ForegroundColor Yellow
Write-Host "This may take 5-10 minutes..."

$cfnPath = Join-Path $PSScriptRoot "cloudformation\taxi-pipeline-stack.yaml"

aws cloudformation deploy `
    --template-file $cfnPath `
    --stack-name $StackName `
    --parameter-overrides `
        EnvironmentName=$StackName `
        DataMonth=$DataMonth `
    --capabilities CAPABILITY_NAMED_IAM `
    --region $Region

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: CloudFormation deployment failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ CloudFormation stack deployed successfully" -ForegroundColor Green

# Get stack outputs
Write-Host "[4/6] Getting stack outputs..." -ForegroundColor Yellow

$outputs = aws cloudformation describe-stacks `
    --stack-name $StackName `
    --query "Stacks[0].Outputs" `
    --output json `
    --region $Region | ConvertFrom-Json

$GlueScriptsBucket = ($outputs | Where-Object { $_.OutputKey -eq "GlueScriptsBucketName" }).OutputValue
$RawDataBucket = ($outputs | Where-Object { $_.OutputKey -eq "RawDataBucketName" }).OutputValue

Write-Host "✓ Glue Scripts Bucket: $GlueScriptsBucket" -ForegroundColor Green
Write-Host "✓ Raw Data Bucket: $RawDataBucket" -ForegroundColor Green

# Upload Glue Scripts
Write-Host "[5/6] Uploading Glue ETL scripts..." -ForegroundColor Yellow

$scriptsPath = Join-Path $PSScriptRoot "glue-scripts"

aws s3 cp "$scriptsPath\yellow_taxi_etl.py" "s3://$GlueScriptsBucket/scripts/" --region $Region
aws s3 cp "$scriptsPath\green_taxi_etl.py" "s3://$GlueScriptsBucket/scripts/" --region $Region
aws s3 cp "$scriptsPath\fhv_taxi_etl.py" "s3://$GlueScriptsBucket/scripts/" --region $Region
aws s3 cp "$scriptsPath\fhvhv_taxi_etl.py" "s3://$GlueScriptsBucket/scripts/" --region $Region
aws s3 cp "$scriptsPath\merge_data_etl.py" "s3://$GlueScriptsBucket/scripts/" --region $Region

Write-Host "✓ Glue scripts uploaded" -ForegroundColor Green

# Display completion message
Write-Host "[6/6] Deployment Complete!" -ForegroundColor Yellow
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║                    Deployment Summary                            ║" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""
Write-Host "Stack Name: $StackName" -ForegroundColor Green
Write-Host "Region: $Region" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps to Start the Pipeline:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Download and upload taxi data to S3:" -ForegroundColor White
Write-Host ""
Write-Host "# Yellow Taxi" -ForegroundColor Cyan
Write-Host "Invoke-WebRequest -Uri 'https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2024-01.parquet' -OutFile 'yellow_tripdata_2024-01.parquet'"
Write-Host "aws s3 cp yellow_tripdata_2024-01.parquet s3://$RawDataBucket/yellow/"
Write-Host ""
Write-Host "# Green Taxi" -ForegroundColor Cyan
Write-Host "Invoke-WebRequest -Uri 'https://d37ci6vzurychx.cloudfront.net/trip-data/green_tripdata_2024-01.parquet' -OutFile 'green_tripdata_2024-01.parquet'"
Write-Host "aws s3 cp green_tripdata_2024-01.parquet s3://$RawDataBucket/green/"
Write-Host ""
Write-Host "# FHV" -ForegroundColor Cyan
Write-Host "Invoke-WebRequest -Uri 'https://d37ci6vzurychx.cloudfront.net/trip-data/fhv_tripdata_2024-01.parquet' -OutFile 'fhv_tripdata_2024-01.parquet'"
Write-Host "aws s3 cp fhv_tripdata_2024-01.parquet s3://$RawDataBucket/fhv/"
Write-Host ""
Write-Host "# FHVHV" -ForegroundColor Cyan
Write-Host "Invoke-WebRequest -Uri 'https://d37ci6vzurychx.cloudfront.net/trip-data/fhvhv_tripdata_2024-01.parquet' -OutFile 'fhvhv_tripdata_2024-01.parquet'"
Write-Host "aws s3 cp fhvhv_tripdata_2024-01.parquet s3://$RawDataBucket/fhvhv/"
Write-Host ""
Write-Host "2. The pipeline will automatically trigger via EventBridge when files are uploaded." -ForegroundColor White
Write-Host ""
Write-Host "3. Monitor the pipeline in AWS Step Functions console." -ForegroundColor White
Write-Host ""
Write-Host "4. Query results using Amazon Athena in the '${StackName}_db' database." -ForegroundColor White
Write-Host ""
Write-Host "✓ All done! Your data pipeline is ready." -ForegroundColor Green
