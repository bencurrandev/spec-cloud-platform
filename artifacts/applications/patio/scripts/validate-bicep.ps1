# =============================================================================
# Patio Application - Bicep Validation Script
# =============================================================================
# Purpose: Validate all Bicep templates for syntax, linting, and best practices
# Usage: .\validate-bicep.ps1
# Compliance: lint-001 v1.0.0
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$BicepPath = "$PSScriptRoot\..\iac",
    
    [Parameter(Mandatory=$false)]
    [switch]$StrictMode = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$FixFormatting = $false
)

$ErrorActionPreference = 'Continue'

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Patio Application - Bicep Validation" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Path: $BicepPath" -ForegroundColor White
Write-Host "Strict Mode: $StrictMode" -ForegroundColor White
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Validation counters
$script:PassCount = 0
$script:ErrorCount = 0
$script:WarningCount = 0

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

function Test-BicepFile {
    param(
        [string]$FilePath,
        [string]$TestName
    )
    
    Write-Host "🔍 Testing: $TestName..." -NoNewline
    
    try {
        $output = az bicep build --file $FilePath 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-Host " ✅ PASS" -ForegroundColor Green
            $script:PassCount++
            return $true
        } else {
            Write-Host " ❌ FAIL" -ForegroundColor Red
            Write-Host "   $output" -ForegroundColor Red
            $script:ErrorCount++
            return $false
        }
    } catch {
        Write-Host " ❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $script:ErrorCount++
        return $false
    }
}

function Test-BicepLinting {
    param(
        [string]$FilePath,
        [string]$FileName
    )
    
    Write-Host "🔍 Linting: $FileName..." -NoNewline
    
    $output = az bicep build --file $FilePath 2>&1 | Out-String
    
    # Check for warnings
    if ($output -match "Warning") {
        $warningCount = ([regex]::Matches($output, "Warning")).Count
        Write-Host " ⚠️ $warningCount WARNING(S)" -ForegroundColor Yellow
        Write-Host $output -ForegroundColor Yellow
        $script:WarningCount += $warningCount
        
        if ($StrictMode) {
            $script:ErrorCount++
            return $false
        }
        return $true
    }
    
    # Check for errors
    if ($output -match "Error" -or $LASTEXITCODE -ne 0) {
        $errorCount = ([regex]::Matches($output, "Error")).Count
        Write-Host " ❌ $errorCount ERROR(S)" -ForegroundColor Red
        Write-Host $output -ForegroundColor Red
        $script:ErrorCount += $errorCount
        return $false
    }
    
    Write-Host " ✅ PASS (No issues)" -ForegroundColor Green
    $script:PassCount++
    return $true
}

function Test-BicepFormatting {
    param(
        [string]$FilePath,
        [string]$FileName
    )
    
    Write-Host "🔍 Formatting: $FileName..." -NoNewline
    
    if ($FixFormatting) {
        az bicep format --file $FilePath 2>&1 | Out-Null
        Write-Host " ✅ FORMATTED" -ForegroundColor Green
        $script:PassCount++
        return $true
    } else {
        # Just check formatting
        $result = az bicep format --file $FilePath --check 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host " ✅ PASS" -ForegroundColor Green
            $script:PassCount++
            return $true
        } else {
            Write-Host " ⚠️ FORMATTING NEEDED (run with -FixFormatting)" -ForegroundColor Yellow
            $script:WarningCount++
            return $true  # Not critical
        }
    }
}

# =============================================================================
# BICEP CLI VALIDATION
# =============================================================================

Write-Host "`n--- Bicep CLI Check ---`n" -ForegroundColor Cyan

Write-Host "Checking Bicep CLI installation..." -NoNewline
try {
    $bicepVersion = az bicep version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host " ✅ $bicepVersion" -ForegroundColor Green
    } else {
        Write-Host " ❌ Bicep CLI not found" -ForegroundColor Red
        Write-Host "Install with: az bicep install" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host " ❌ Azure CLI not found" -ForegroundColor Red
    exit 1
}

# =============================================================================
# BICEP FILE DISCOVERY
# =============================================================================

Write-Host "`n--- Discovering Bicep Files ---`n" -ForegroundColor Cyan

$bicepFiles = Get-ChildItem -Path $BicepPath -Filter "*.bicep" -Recurse

Write-Host "Found $($bicepFiles.Count) Bicep files:" -ForegroundColor White
foreach ($file in $bicepFiles) {
    $relativePath = $file.FullName.Replace($BicepPath, "").TrimStart("\")
    Write-Host "  - $relativePath" -ForegroundColor Gray
}

# =============================================================================
# SYNTAX VALIDATION
# =============================================================================

Write-Host "`n--- Syntax Validation ---`n" -ForegroundColor Cyan

foreach ($file in $bicepFiles) {
    $fileName = $file.Name
    Test-BicepFile -FilePath $file.FullName -TestName "Syntax: $fileName"
}

# =============================================================================
# LINTING VALIDATION
# =============================================================================

Write-Host "`n--- Linting Validation ---`n" -ForegroundColor Cyan

foreach ($file in $bicepFiles) {
    $fileName = $file.Name
    Test-BicepLinting -FilePath $file.FullName -FileName $fileName
}

# =============================================================================
# FORMATTING VALIDATION
# =============================================================================

Write-Host "`n--- Formatting Validation ---`n" -ForegroundColor Cyan

foreach ($file in $bicepFiles) {
    $fileName = $file.Name
    Test-BicepFormatting -FilePath $file.FullName -FileName $fileName
}

# =============================================================================
# BICEP CONFIG VALIDATION
# =============================================================================

Write-Host "`n--- Bicep Configuration ---`n" -ForegroundColor Cyan

$bicepConfigPath = Join-Path $BicepPath "bicepconfig.json"

if (Test-Path $bicepConfigPath) {
    Write-Host "Validating bicepconfig.json..." -NoNewline
    
    try {
        $config = Get-Content $bicepConfigPath | ConvertFrom-Json
        
        # Check required sections
        $requiredSections = @('analyzers', 'formatting')
        $missingSections = @()
        
        foreach ($section in $requiredSections) {
            if (-not $config.PSObject.Properties[$section]) {
                $missingSections += $section
            }
        }
        
        if ($missingSections.Count -eq 0) {
            Write-Host " ✅ PASS" -ForegroundColor Green
            $script:PassCount++
            
            # Display key settings
            Write-Host "`n  Analyzer Rules:" -ForegroundColor Gray
            $config.analyzers.core.rules.PSObject.Properties | ForEach-Object {
                $ruleName = $_.Name
                $ruleLevel = $_.Value.level
                Write-Host "    - $ruleName : $ruleLevel" -ForegroundColor Gray
            }
        } else {
            Write-Host " ⚠️ MISSING SECTIONS: $($missingSections -join ', ')" -ForegroundColor Yellow
            $script:WarningCount++
        }
    } catch {
        Write-Host " ❌ INVALID JSON: $($_.Exception.Message)" -ForegroundColor Red
        $script:ErrorCount++
    }
} else {
    Write-Host "⚠️ bicepconfig.json not found" -ForegroundColor Yellow
    Write-Host "  Expected at: $bicepConfigPath" -ForegroundColor Gray
    $script:WarningCount++
}

# =============================================================================
# SECURITY VALIDATION
# =============================================================================

Write-Host "`n--- Security Validation ---`n" -ForegroundColor Cyan

Write-Host "Checking for hardcoded secrets..." -NoNewline

$secretPatterns = @(
    @{Pattern = 'password\s*=\s*[''"][^''"]'; Name = "Hardcoded Password"},
    @{Pattern = 'apiKey\s*=\s*[''"][^''"]'; Name = "Hardcoded API Key"},
    @{Pattern = 'connectionString\s*=\s*[''"](?!@)'; Name = "Hardcoded Connection String"},
    @{Pattern = 'secret\s*=\s*[''"][^''"]'; Name = "Hardcoded Secret"}
)

$secretsFound = $false

foreach ($file in $bicepFiles) {
    $content = Get-Content $file.FullName -Raw
    
    foreach ($pattern in $secretPatterns) {
        if ($content -match $pattern.Pattern) {
            if (-not $secretsFound) {
                Write-Host " ❌ FOUND SECRETS" -ForegroundColor Red
                $secretsFound = $true
            }
            Write-Host "  - $($pattern.Name) in $($file.Name)" -ForegroundColor Red
            $script:ErrorCount++
        }
    }
}

if (-not $secretsFound) {
    Write-Host " ✅ PASS (No secrets found)" -ForegroundColor Green
    $script:PassCount++
}

# =============================================================================
# BEST PRACTICES VALIDATION
# =============================================================================

Write-Host "`n--- Best Practices Validation ---`n" -ForegroundColor Cyan

# Check 1: Parameters should have descriptions
Write-Host "Checking parameter descriptions..." -NoNewline
$missingDescriptions = 0

foreach ($file in $bicepFiles) {
    $content = Get-Content $file.FullName -Raw
    
    # Find all param declarations without @description
    $paramsWithoutDesc = [regex]::Matches($content, "(?<!@description[^\r\n]*\r?\n)param\s+\w+") | Where-Object {
        $_.Value -notmatch "param\s+tags"  # Exclude common params
    }
    
    $missingDescriptions += $paramsWithoutDesc.Count
}

if ($missingDescriptions -eq 0) {
    Write-Host " ✅ PASS (All parameters documented)" -ForegroundColor Green
    $script:PassCount++
} else {
    Write-Host " ⚠️ $missingDescriptions parameters missing @description" -ForegroundColor Yellow
    $script:WarningCount++
}

# Check 2: Outputs should have descriptions
Write-Host "Checking output descriptions..." -NoNewline
$missingOutputDescriptions = 0

foreach ($file in $bicepFiles) {
    $content = Get-Content $file.FullName -Raw
    $outputsWithoutDesc = [regex]::Matches($content, "(?<!@description[^\r\n]*\r?\n)output\s+\w+")
    $missingOutputDescriptions += $outputsWithoutDesc.Count
}

if ($missingOutputDescriptions -eq 0) {
    Write-Host " ✅ PASS (All outputs documented)" -ForegroundColor Green
    $script:PassCount++
} else {
    Write-Host " ⚠️ $missingOutputDescriptions outputs missing @description" -ForegroundColor Yellow
    $script:WarningCount++
}

# Check 3: Secure parameters should not have default values
Write-Host "Checking secure parameter defaults..." -NoNewline
$secureDefaultsFound = 0

foreach ($file in $bicepFiles) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match "@secure\(\)[^\r\n]*\r?\n\s*param\s+\w+[^=]*=") {
        $secureDefaultsFound++
        Write-Host " ❌ Secure parameter with default value in $($file.Name)" -ForegroundColor Red
        $script:ErrorCount++
    }
}

if ($secureDefaultsFound -eq 0) {
    Write-Host " ✅ PASS (No secure defaults)" -ForegroundColor Green
    $script:PassCount++
}

# =============================================================================
# FINAL REPORT
# =============================================================================

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "Validation Summary" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Files Validated:   $($bicepFiles.Count)" -ForegroundColor White
Write-Host "✅ Passed:         $script:PassCount" -ForegroundColor Green
Write-Host "❌ Errors:         $script:ErrorCount" -ForegroundColor Red
Write-Host "⚠️  Warnings:       $script:WarningCount" -ForegroundColor Yellow
Write-Host "==================================================================" -ForegroundColor Cyan

if ($script:ErrorCount -gt 0) {
    Write-Host "`n❌ VALIDATION FAILED" -ForegroundColor Red
    exit 1
} elseif ($script:WarningCount -gt 0) {
    Write-Host "`n⚠️ VALIDATION PASSED WITH WARNINGS" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "`n✅ ALL VALIDATIONS PASSED" -ForegroundColor Green
    exit 0
}
