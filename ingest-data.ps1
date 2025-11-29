# =============================================================================
# Data Ingestion Script for AWS Taxi Pipeline
# Downloads TLC Taxi data and uploads to S3 to trigger the pipeline
# =============================================================================

param(
    [string]$RawDataBucket,
    [string]$DataMonth = "2024-01",
    [string]$Region = "us-east-1",
    [switch]$SkipDownload
)

Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║           NYC Taxi Data - Ingestion Script                       ║" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

# Get bucket name from CloudFormation if not provided
if (-not $RawDataBucket) {
    Write-Host "Getting bucket name from CloudFormation stack..." -ForegroundColor Yellow
    $RawDataBucket = aws cloudformation describe-stacks `
        --stack-name "taxi-pipeline" `
        --query "Stacks[0].Outputs[?OutputKey=='RawDataBucketName'].OutputValue" `
        --output text `
        --region $Region
    
    if (-not $RawDataBucket -or $RawDataBucket -eq "None") {
        Write-Host "Error: Could not find Raw Data Bucket. Please provide -RawDataBucket parameter." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Target Bucket: $RawDataBucket" -ForegroundColor Green
Write-Host "Data Month: $DataMonth" -ForegroundColor Green
Write-Host ""

# Base URLs for TLC data
$baseUrl = "https://d37ci6vzurychx.cloudfront.net/trip-data"

$datasets = @(
    @{Name = "Yellow Taxi"; File = "yellow_tripdata_$DataMonth.parquet"; Prefix = "yellow" },
    @{Name = "Green Taxi"; File = "green_tripdata_$DataMonth.parquet"; Prefix = "green" },
    @{Name = "FHV"; File = "fhv_tripdata_$DataMonth.parquet"; Prefix = "fhv" },
    @{Name = "FHVHV"; File = "fhvhv_tripdata_$DataMonth.parquet"; Prefix = "fhvhv" }
)

$totalDatasets = $datasets.Count
$current = 0

foreach ($dataset in $datasets) {
    $current++
    $percent = [math]::Round(($current / $totalDatasets) * 100)
    
    Write-Host "[$current/$totalDatasets] Processing $($dataset.Name)..." -ForegroundColor Yellow
    
    $url = "$baseUrl/$($dataset.File)"
    $localFile = $dataset.File
    $s3Path = "s3://$RawDataBucket/$($dataset.Prefix)/$($dataset.File)"
    
    # Download file if not skipping
    if (-not $SkipDownload) {
        Write-Host "  Downloading from: $url" -ForegroundColor Cyan
        try {
            # Use curl for faster downloads (available in Windows 10+)
            curl.exe -L -o $localFile $url --progress-bar
            
            if (-not (Test-Path $localFile)) {
                throw "Download failed"
            }
            
            $fileSize = (Get-Item $localFile).Length / 1MB
            Write-Host "  ✓ Downloaded: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Green
        } catch {
            Write-Host "  Error downloading $($dataset.Name): $_" -ForegroundColor Red
            continue
        }
    } else {
        if (-not (Test-Path $localFile)) {
            Write-Host "  Error: Local file not found: $localFile" -ForegroundColor Red
            continue
        }
        Write-Host "  Using existing file: $localFile" -ForegroundColor Cyan
    }
    
    # Upload to S3
    Write-Host "  Uploading to: $s3Path" -ForegroundColor Cyan
    try {
        aws s3 cp $localFile $s3Path --region $Region
        Write-Host "  ✓ Uploaded successfully" -ForegroundColor Green
    } catch {
        Write-Host "  Error uploading $($dataset.Name): $_" -ForegroundColor Red
        continue
    }
    
    Write-Host ""
}

Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║                    Ingestion Complete!                           ║" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""
Write-Host "The ETL pipeline should now be triggered automatically via EventBridge." -ForegroundColor Green
Write-Host ""
Write-Host "Monitor the pipeline:" -ForegroundColor Yellow
Write-Host "  aws stepfunctions list-executions --state-machine-arn <ARN> --region $Region"
Write-Host ""
Write-Host "Or check AWS Console:" -ForegroundColor Yellow
Write-Host "  Step Functions > State machines > taxi-pipeline-etl-workflow"
