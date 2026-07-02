# =============================================================================
# Patio Application - What-If Deployment Analysis
# =============================================================================
# Purpose: Preview infrastructure changes before deployment
# Usage: .\run-whatif-analysis.ps1 -Environment <dev|staging|prod>
# Compliance: deploy-001 v1.0.0 (change management)
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = $env:AZURE_SUBSCRIPTION_ID,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = 'eastus',
    
    [Parameter(Mandatory=$false)]
    [switch]$SaveOutput = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$DetailedChanges = $false
)

$ErrorActionPreference = 'Stop'

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Patio Application - What-If Deployment Analysis" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Environment:   $Environment" -ForegroundColor White
Write-Host "Location:      $Location" -ForegroundColor White
Write-Host "Subscription:  $SubscriptionId" -ForegroundColor White
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# CONFIGURATION
# =============================================================================

$resourceGroup = "rg-patio-$Environment"
$templateFile = "$PSScriptRoot\..\iac\main.bicep"
$parametersFile = "$PSScriptRoot\..\iac\parameters\$Environment.parameters.json"
$outputDir = "$PSScriptRoot\..\docs\whatif-reports"

# Verify files exist
if (-not (Test-Path $templateFile)) {
    Write-Host "❌ Template file not found: $templateFile" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $parametersFile)) {
    Write-Host "❌ Parameters file not found: $parametersFile" -ForegroundColor Red
    exit 1
}

# =============================================================================
# AZURE CLI VALIDATION
# =============================================================================

Write-Host "Validating Azure CLI..." -NoNewline

try {
    $azVersion = az version --output json 2>&1 | ConvertFrom-Json
    Write-Host " ✅ Version: $($azVersion.'azure-cli')" -ForegroundColor Green
} catch {
    Write-Host " ❌ Azure CLI not found or not logged in" -ForegroundColor Red
    Write-Host "Run: az login" -ForegroundColor Yellow
    exit 1
}

# =============================================================================
# SUBSCRIPTION VALIDATION
# =============================================================================

Write-Host "Validating Azure subscription..." -NoNewline

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host " ❌ Invalid subscription ID" -ForegroundColor Red
        exit 1
    }
}

$currentSub = az account show --output json | ConvertFrom-Json
Write-Host " ✅ $($currentSub.name)" -ForegroundColor Green

# =============================================================================
# RESOURCE GROUP CHECK
# =============================================================================

Write-Host "Checking resource group..." -NoNewline

$rgExists = az group exists --name $resourceGroup

if ($rgExists -eq 'false') {
    Write-Host " ⚠️ Does not exist (will be created)" -ForegroundColor Yellow
    $isNewDeployment = $true
} else {
    Write-Host " ✅ Exists" -ForegroundColor Green
    $isNewDeployment = $false
    
    # Get existing resource count
    $existingResources = az resource list --resource-group $resourceGroup --output json | ConvertFrom-Json
    Write-Host "  Existing resources: $($existingResources.Count)" -ForegroundColor Gray
}

# =============================================================================
# TEMPLATE VALIDATION
# =============================================================================

Write-Host "`nValidating Bicep template..." -ForegroundColor Cyan

Write-Host "  Building template..." -NoNewline
az bicep build --file $templateFile 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host " ❌ Template build failed" -ForegroundColor Red
    exit 1
}
Write-Host " ✅" -ForegroundColor Green

Write-Host "  Validating template..." -NoNewline
$validationOutput = az deployment group validate `
    --resource-group $resourceGroup `
    --template-file $templateFile `
    --parameters $parametersFile `
    --output json 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host " ❌ Validation failed" -ForegroundColor Red
    Write-Host $validationOutput -ForegroundColor Red
    exit 1
}
Write-Host " ✅" -ForegroundColor Green

# =============================================================================
# WHAT-IF ANALYSIS
# =============================================================================

Write-Host "`nRunning What-If analysis..." -ForegroundColor Cyan
Write-Host "This may take 2-3 minutes..." -ForegroundColor Gray
Write-Host ""

$whatIfArgs = @(
    'deployment', 'group', 'what-if'
    '--resource-group', $resourceGroup
    '--template-file', $templateFile
    '--parameters', $parametersFile
    '--result-format', 'FullResourcePayloads'
)

if ($DetailedChanges) {
    $whatIfArgs += '--exclude-change-types', 'Ignore,NoChange'
}

# Run What-If
$whatIfOutput = & az @whatIfArgs 2>&1

# Capture exit code
$whatIfExitCode = $LASTEXITCODE

# Display output
Write-Host $whatIfOutput

# =============================================================================
# PARSE WHAT-IF RESULTS
# =============================================================================

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "What-If Analysis Summary" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Count changes
$createCount = ([regex]::Matches($whatIfOutput, "\+\s+Create")).Count
$modifyCount = ([regex]::Matches($whatIfOutput, "~\s+Modify")).Count
$deleteCount = ([regex]::Matches($whatIfOutput, "-\s+Delete")).Count
$deployCount = ([regex]::Matches($whatIfOutput, "!\s+Deploy")).Count
$ignoreCount = ([regex]::Matches($whatIfOutput, "\*\s+Ignore")).Count
$noChangeCount = ([regex]::Matches($whatIfOutput, "=\s+NoChange")).Count

Write-Host ""
Write-Host "Resource Changes:" -ForegroundColor White
Write-Host "  + Create:   $createCount" -ForegroundColor Green
Write-Host "  ~ Modify:   $modifyCount" -ForegroundColor Yellow
Write-Host "  - Delete:   $deleteCount" -ForegroundColor Red
Write-Host "  ! Deploy:   $deployCount" -ForegroundColor Cyan
Write-Host "  * Ignore:   $ignoreCount" -ForegroundColor Gray
Write-Host "  = NoChange: $noChangeCount" -ForegroundColor Gray
Write-Host ""

$totalChanges = $createCount + $modifyCount + $deleteCount + $deployCount

# =============================================================================
# RISK ASSESSMENT
# =============================================================================

Write-Host "Risk Assessment:" -ForegroundColor White

$riskLevel = 'LOW'
$riskColor = 'Green'
$warnings = @()

if ($deleteCount -gt 0) {
    $riskLevel = 'HIGH'
    $riskColor = 'Red'
    $warnings += "⚠️ $deleteCount resource(s) will be DELETED"
}

if ($modifyCount -gt 5) {
    if ($riskLevel -eq 'LOW') { $riskLevel = 'MEDIUM'; $riskColor = 'Yellow' }
    $warnings += "⚠️ $modifyCount resources will be modified"
}

if ($isNewDeployment) {
    $warnings += "ℹ️ New deployment (resource group does not exist)"
}

Write-Host "  Risk Level: $riskLevel" -ForegroundColor $riskColor

if ($warnings.Count -gt 0) {
    Write-Host "`n  Warnings:" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "    $warning" -ForegroundColor Yellow
    }
}

# =============================================================================
# DEPLOYMENT IMPACT ANALYSIS
# =============================================================================

Write-Host "`nDeployment Impact:" -ForegroundColor White

# Check for high-impact changes
$highImpactPatterns = @(
    @{Pattern = 'virtualMachines'; Impact = 'VM modifications may require restart'},
    @{Pattern = 'flexibleServers.*Delete'; Impact = 'Database deletion - DATA LOSS RISK'},
    @{Pattern = 'storageAccounts.*Delete'; Impact = 'Storage deletion - DATA LOSS RISK'},
    @{Pattern = 'loadBalancers'; Impact = 'Load balancer changes may cause brief downtime'},
    @{Pattern = 'networkSecurityGroups'; Impact = 'NSG changes may affect connectivity'},
    @{Pattern = 'redis.*Delete'; Impact = 'Cache deletion - Session data loss'}
)

$impactsFound = @()

foreach ($pattern in $highImpactPatterns) {
    if ($whatIfOutput -match $pattern.Pattern) {
        $impactsFound += "  ⚠️ $($pattern.Impact)"
    }
}

if ($impactsFound.Count -gt 0) {
    foreach ($impact in $impactsFound) {
        Write-Host $impact -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✅ No high-impact changes detected" -ForegroundColor Green
}

# =============================================================================
# ESTIMATED COST IMPACT
# =============================================================================

Write-Host "`nEstimated Cost Impact:" -ForegroundColor White

# Simple cost estimation based on resource changes
$estimatedCosts = @{
    'dev' = 48
    'staging' = 73
    'prod' = 95
}

$currentCost = $estimatedCosts[$Environment]

if ($isNewDeployment) {
    Write-Host "  New deployment: +`$$currentCost/month" -ForegroundColor Green
} else {
    $costChange = 0
    
    if ($createCount -gt 0) {
        $costChange += ($createCount * 10) # Rough estimate
    }
    if ($deleteCount -gt 0) {
        $costChange -= ($deleteCount * 10)
    }
    
    if ($costChange -gt 0) {
        Write-Host "  Estimated increase: +`$$costChange/month" -ForegroundColor Yellow
    } elseif ($costChange -lt 0) {
        Write-Host "  Estimated savings: `$$([Math]::Abs($costChange))/month" -ForegroundColor Green
    } else {
        Write-Host "  No significant cost change expected" -ForegroundColor Green
    }
}

# =============================================================================
# DEPLOYMENT READINESS
# =============================================================================

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "Deployment Readiness Check" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

$readinessChecks = @()

# Check 1: No unexpected deletions
if ($deleteCount -eq 0) {
    $readinessChecks += @{Status = $true; Message = "No resource deletions"}
} else {
    $readinessChecks += @{Status = $false; Message = "BLOCKING: $deleteCount resources will be deleted"}
}

# Check 2: Deployment is not too large
if ($totalChanges -lt 50) {
    $readinessChecks += @{Status = $true; Message = "Reasonable change scope ($totalChanges resources)"}
} else {
    $readinessChecks += @{Status = $false; Message = "WARNING: Large deployment ($totalChanges resources)"}
}

# Check 3: Environment-specific checks
if ($Environment -eq 'prod' -and $modifyCount -gt 0) {
    $readinessChecks += @{Status = $false; Message = "PRODUCTION: Manual approval required for modifications"}
} else {
    $readinessChecks += @{Status = $true; Message = "Environment checks passed"}
}

# Display checks
foreach ($check in $readinessChecks) {
    if ($check.Status) {
        Write-Host "  ✅ $($check.Message)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ $($check.Message)" -ForegroundColor Yellow
    }
}

# =============================================================================
# SAVE REPORT
# =============================================================================

if ($SaveOutput) {
    Write-Host "`nSaving What-If report..." -ForegroundColor Cyan
    
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $reportFile = Join-Path $outputDir "whatif-$Environment-$timestamp.txt"
    
    # Create report
    $report = @"
=================================================================
Patio Application - What-If Analysis Report
=================================================================
Environment:  $Environment
Date:         $(Get-Date -Format 'yyyy-MM-DD HH:mm:ss')
Subscription: $($currentSub.name)
Location:     $Location

=================================================================
SUMMARY
=================================================================
Total Changes: $totalChanges
  + Create:   $createCount
  ~ Modify:   $modifyCount
  - Delete:   $deleteCount
  ! Deploy:   $deployCount
  
Risk Level: $riskLevel

=================================================================
DETAILED OUTPUT
=================================================================
$whatIfOutput

=================================================================
END OF REPORT
=================================================================
"@

    $report | Out-File -FilePath $reportFile -Encoding UTF8
    
    Write-Host "  Report saved to: $reportFile" -ForegroundColor Green
}

# =============================================================================
# FINAL RECOMMENDATIONS
# =============================================================================

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "Recommendations" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

if ($totalChanges -eq 0) {
    Write-Host "✅ No changes detected - deployment not needed" -ForegroundColor Green
} elseif ($deleteCount -gt 0) {
    Write-Host "⚠️ CAUTION: Review deletions carefully before deploying" -ForegroundColor Yellow
    Write-Host "   Consider backing up data before proceeding" -ForegroundColor Yellow
} elseif ($totalChanges -lt 10) {
    Write-Host "✅ Safe to proceed with deployment" -ForegroundColor Green
} else {
    Write-Host "⚠️ Large deployment - proceed with caution" -ForegroundColor Yellow
    Write-Host "   Consider deploying in stages if possible" -ForegroundColor Yellow
}

if ($Environment -eq 'prod') {
    Write-Host "`n🔒 PRODUCTION DEPLOYMENT CHECKLIST:" -ForegroundColor Cyan
    Write-Host "   [ ] What-If analysis reviewed and approved" -ForegroundColor White
    Write-Host "   [ ] Backup verified" -ForegroundColor White
    Write-Host "   [ ] Change window scheduled" -ForegroundColor White
    Write-Host "   [ ] Rollback plan prepared" -ForegroundColor White
    Write-Host "   [ ] Stakeholders notified" -ForegroundColor White
}

Write-Host ""

# Exit code
if ($whatIfExitCode -eq 0) {
    exit 0
} else {
    exit $whatIfExitCode
}
