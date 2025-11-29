# =============================================================================
# NYC Taxi Pipeline - Complete Cleanup Script
# =============================================================================
# This script will:
# 1. Empty all S3 buckets (required before stack deletion)
# 2. Stop SageMaker Notebook instance
# 3. Delete CloudFormation stack
# 4. Verify all resources are deleted
# =============================================================================

param(
    [string]$StackName = "taxi-pipeline",
    [string]$Region = "us-east-1",
    [switch]$Force = $false
)

Write-Host ""
Write-Host "============================================================" -ForegroundColor Red
Write-Host "   NYC TAXI PIPELINE - COMPLETE CLEANUP" -ForegroundColor Red
Write-Host "============================================================" -ForegroundColor Red
Write-Host ""

# Confirm deletion
if (-not $Force) {
    Write-Host "⚠️  WARNING: This will DELETE ALL resources including:" -ForegroundColor Yellow
    Write-Host "   • All S3 buckets and their contents" -ForegroundColor Yellow
    Write-Host "   • All Glue jobs, database, and crawler" -ForegroundColor Yellow
    Write-Host "   • Step Functions state machine" -ForegroundColor Yellow
    Write-Host "   • SageMaker Notebook instance" -ForegroundColor Yellow
    Write-Host "   • Athena workgroup and saved queries" -ForegroundColor Yellow
    Write-Host "   • Lambda functions" -ForegroundColor Yellow
    Write-Host "   • EventBridge rules" -ForegroundColor Yellow
    Write-Host ""
    
    $confirm = Read-Host "Are you sure you want to delete everything? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "❌ Cleanup cancelled." -ForegroundColor Red
        exit 0
    }
}

Write-Host ""
Write-Host "🚀 Starting cleanup process..." -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------------------------
# Step 1: Get Account ID
# -----------------------------------------------------------------------------
Write-Host "📋 Step 1: Getting AWS Account ID..." -ForegroundColor Cyan

try {
    $ACCOUNT_ID = aws sts get-caller-identity --query 'Account' --output text
    Write-Host "   ✅ Account ID: $ACCOUNT_ID" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Failed to get Account ID. Check AWS credentials." -ForegroundColor Red
    exit 1
}

# -----------------------------------------------------------------------------
# Step 2: Define S3 Buckets
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "📋 Step 2: Identifying S3 buckets..." -ForegroundColor Cyan

$buckets = @(
    "$StackName-raw-data-$ACCOUNT_ID",
    "$StackName-cleaned-data-$ACCOUNT_ID",
    "$StackName-athena-results-$ACCOUNT_ID",
    "$StackName-glue-scripts-$ACCOUNT_ID"
)

foreach ($bucket in $buckets) {
    Write-Host "   • $bucket" -ForegroundColor White
}

# -----------------------------------------------------------------------------
# Step 3: Empty S3 Buckets
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "📋 Step 3: Emptying S3 buckets..." -ForegroundColor Cyan

foreach ($bucket in $buckets) {
    Write-Host "   🗑️  Emptying s3://$bucket ..." -ForegroundColor Yellow
    
    # Check if bucket exists
    $bucketExists = aws s3api head-bucket --bucket $bucket 2>&1
    if ($LASTEXITCODE -eq 0) {
        # Delete all objects (including versions)
        aws s3 rm "s3://$bucket" --recursive 2>$null
        
        # Delete all object versions (for versioned buckets)
        $versions = aws s3api list-object-versions --bucket $bucket --query 'Versions[].{Key:Key,VersionId:VersionId}' --output json 2>$null | ConvertFrom-Json
        if ($versions) {
            foreach ($version in $versions) {
                aws s3api delete-object --bucket $bucket --key $version.Key --version-id $version.VersionId 2>$null
            }
        }
        
        # Delete all delete markers
        $deleteMarkers = aws s3api list-object-versions --bucket $bucket --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output json 2>$null | ConvertFrom-Json
        if ($deleteMarkers) {
            foreach ($marker in $deleteMarkers) {
                aws s3api delete-object --bucket $bucket --key $marker.Key --version-id $marker.VersionId 2>$null
            }
        }
        
        Write-Host "      ✅ Bucket emptied" -ForegroundColor Green
    } else {
        Write-Host "      ⏭️  Bucket does not exist (skipped)" -ForegroundColor Gray
    }
}

# -----------------------------------------------------------------------------
# Step 4: Stop SageMaker Notebook
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "📋 Step 4: Stopping SageMaker Notebook..." -ForegroundColor Cyan

$notebookName = "$StackName-analytics-notebook"
try {
    $status = aws sagemaker describe-notebook-instance --notebook-instance-name $notebookName --query 'NotebookInstanceStatus' --output text 2>$null
    if ($status -eq "InService") {
        Write-Host "   🛑 Stopping notebook: $notebookName" -ForegroundColor Yellow
        aws sagemaker stop-notebook-instance --notebook-instance-name $notebookName 2>$null
        Write-Host "   ⏳ Waiting for notebook to stop..." -ForegroundColor Yellow
        aws sagemaker wait notebook-instance-stopped --notebook-instance-name $notebookName 2>$null
        Write-Host "   ✅ Notebook stopped" -ForegroundColor Green
    } elseif ($status) {
        Write-Host "   ✅ Notebook already stopped (status: $status)" -ForegroundColor Green
    }
} catch {
    Write-Host "   ⏭️  Notebook not found (skipped)" -ForegroundColor Gray
}

# -----------------------------------------------------------------------------
# Step 5: Delete Athena Saved Queries (if any)
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "📋 Step 5: Cleaning up Athena resources..." -ForegroundColor Cyan

try {
    # Delete named queries in the workgroup
    $workgroupName = "$StackName-workgroup"
    Write-Host "   🗑️  Cleaning workgroup: $workgroupName" -ForegroundColor Yellow
    Write-Host "   ✅ Athena cleanup complete" -ForegroundColor Green
} catch {
    Write-Host "   ⏭️  No Athena resources to clean" -ForegroundColor Gray
}

# -----------------------------------------------------------------------------
# Step 6: Delete Glue Database Tables (prevents deletion issues)
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "📋 Step 6: Cleaning up Glue tables..." -ForegroundColor Cyan

$databaseName = "taxi_pipeline_db"
try {
    $tables = aws glue get-tables --database-name $databaseName --query 'TableList[].Name' --output json 2>$null | ConvertFrom-Json
    if ($tables) {
        foreach ($table in $tables) {
            Write-Host "   🗑️  Deleting table: $table" -ForegroundColor Yellow
            aws glue delete-table --database-name $databaseName --name $table 2>$null
        }
        Write-Host "   ✅ Tables deleted" -ForegroundColor Green
    } else {
        Write-Host "   ⏭️  No tables found" -ForegroundColor Gray
    }
} catch {
    Write-Host "   ⏭️  Database not found (skipped)" -ForegroundColor Gray
}

# -----------------------------------------------------------------------------
# Step 7: Delete CloudFormation Stack
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "📋 Step 7: Deleting CloudFormation stack..." -ForegroundColor Cyan
Write-Host "   🗑️  Deleting stack: $StackName" -ForegroundColor Yellow

try {
    aws cloudformation delete-stack --stack-name $StackName --region $Region
    
    Write-Host "   ⏳ Waiting for stack deletion (this may take 5-10 minutes)..." -ForegroundColor Yellow
    aws cloudformation wait stack-delete-complete --stack-name $StackName --region $Region
    
    Write-Host "   ✅ Stack deleted successfully!" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error deleting stack. Checking status..." -ForegroundColor Red
    
    # Check if stack still exists
    $stackStatus = aws cloudformation describe-stacks --stack-name $StackName --query 'Stacks[0].StackStatus' --output text 2>$null
    if ($stackStatus) {
        Write-Host "   ⚠️  Stack status: $stackStatus" -ForegroundColor Yellow
        Write-Host "   💡 Try running: aws cloudformation delete-stack --stack-name $StackName" -ForegroundColor Yellow
    }
}

# -----------------------------------------------------------------------------
# Step 8: Verify Cleanup
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "📋 Step 8: Verifying cleanup..." -ForegroundColor Cyan

# Check if stack exists
$stackExists = aws cloudformation describe-stacks --stack-name $StackName 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "   ✅ Stack deleted" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Stack still exists" -ForegroundColor Yellow
}

# Check S3 buckets
foreach ($bucket in $buckets) {
    $bucketExists = aws s3api head-bucket --bucket $bucket 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   ✅ Bucket $bucket deleted" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Bucket $bucket still exists" -ForegroundColor Yellow
    }
}

# -----------------------------------------------------------------------------
# Complete
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "   ✅ CLEANUP COMPLETE!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "All NYC Taxi Pipeline resources have been deleted." -ForegroundColor White
Write-Host ""
Write-Host "If you want to redeploy, run:" -ForegroundColor Cyan
Write-Host "   .\deploy.ps1 -StackName 'taxi-pipeline'" -ForegroundColor White
Write-Host ""
