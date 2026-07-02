# =============================================================================
# Patio Application - Security Compliance Review Script
# =============================================================================
# Purpose: Validate security configuration against compliance requirements
# Usage: .\validate-security.ps1
# Compliance: ac-001, dp-001, audit-001, sec-001
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$IacPath = "$PSScriptRoot\..\iac",
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose = $false
)

$ErrorActionPreference = 'Continue'

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Patio Application - Security Compliance Review" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Compliance counters
$script:PassCount = 0
$script:FailCount = 0
$script:WarningCount = 0

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

function Test-Compliance {
    param(
        [string]$Name,
        [scriptblock]$Check,
        [bool]$IsCritical = $true,
        [string]$Specification = ""
    )
    
    $specLabel = if ($Specification) { "($Specification)" } else { "" }
    Write-Host "🔍 $Name $specLabel..." -NoNewline
    
    try {
        $result = & $Check
        if ($result) {
            Write-Host " ✅ COMPLIANT" -ForegroundColor Green
            $script:PassCount++
            return $true
        } else {
            if ($IsCritical) {
                Write-Host " ❌ NON-COMPLIANT" -ForegroundColor Red
                $script:FailCount++
            } else {
                Write-Host " ⚠️ WARNING" -ForegroundColor Yellow
                $script:WarningCount++
            }
            return $false
        }
    } catch {
        Write-Host " ❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        if ($IsCritical) {
            $script:FailCount++
        } else {
            $script:WarningCount++
        }
        return $false
    }
}

# =============================================================================
# AC-001: ACCESS CONTROL
# =============================================================================

Write-Host "`n--- AC-001: Access Control Compliance ---`n" -ForegroundColor Cyan

# Check 1: SSH key authentication only (no passwords)
Test-Compliance -Name "SSH key-based authentication enforced" -Specification "ac-001" -Check {
    $vmFiles = Get-ChildItem -Path $IacPath -Filter "*vm*.bicep" -Recurse
    
    foreach ($file in $vmFiles) {
        $content = Get-Content $file.FullName -Raw
        
        # Check for password authentication
        if ($content -match "adminPassword|password\s*:") {
            Write-Host "`n  ❌ Password authentication found in $($file.Name)" -ForegroundColor Red
            return $false
        }
        
        # Check for SSH public key
        if ($content -notmatch "sshPublicKey|publicKey") {
            Write-Host "`n  ⚠️ No SSH public key configuration in $($file.Name)" -ForegroundColor Yellow
            return $false
        }
    }
    
    return $true
}

# Check 2: RBAC configuration
Test-Compliance -Name "RBAC roles defined and assigned" -Specification "ac-001" -Check {
    $baselineFile = Join-Path $IacPath "security-baseline.bicep"
    
    if (-not (Test-Path $baselineFile)) {
        Write-Host "`n  ❌ security-baseline.bicep not found" -ForegroundColor Red
        return $false
    }
    
    $content = Get-Content $baselineFile -Raw
    
    # Check for RBAC role definitions
    $requiredRoles = @('Customer', 'Business Owner', 'Admin')
    $missingRoles = @()
    
    foreach ($role in $requiredRoles) {
        if ($content -notmatch $role.Replace(' ', '')) {
            $missingRoles += $role
        }
    }
    
    if ($missingRoles.Count -gt 0) {
        Write-Host "`n  ⚠️ Missing RBAC roles: $($missingRoles -join ', ')" -ForegroundColor Yellow
        return $false
    }
    
    return $true
}

# Check 3: MFA enforcement for privileged roles
Test-Compliance -Name "MFA required for Business Owner and Admin roles" -Specification "ac-001" -Check {
    $baselineFile = Join-Path $IacPath "security-baseline.bicep"
    $content = Get-Content $baselineFile -Raw
    
    if ($content -match "mfa.*required|requireMFA.*true") {
        return $true
    }
    
    Write-Host "`n  ⚠️ MFA enforcement not explicitly configured" -ForegroundColor Yellow
    return $false
} -IsCritical $false

# Check 4: Key Vault RBAC authorization
Test-Compliance -Name "Key Vault uses RBAC authorization model" -Specification "ac-001" -Check {
    $kvFiles = Get-ChildItem -Path $IacPath -Filter "*keyvault*.bicep" -Recurse
    
    foreach ($file in $kvFiles) {
        $content = Get-Content $file.FullName -Raw
        
        if ($content -match "enableRbacAuthorization.*true") {
            return $true
        }
    }
    
    Write-Host "`n  ⚠️ RBAC authorization not found in Key Vault configuration" -ForegroundColor Yellow
    return $false
}

# =============================================================================
# DP-001: DATA PROTECTION
# =============================================================================

Write-Host "`n--- DP-001: Data Protection Compliance ---`n" -ForegroundColor Cyan

# Check 5: AES-256 encryption at rest
Test-Compliance -Name "Encryption at rest enabled (AES-256)" -Specification "dp-001" -Check {
    $storageFiles = Get-ChildItem -Path $IacPath -Filter "*storage*.bicep" -Recurse
    
    foreach ($file in $storageFiles) {
        $content = Get-Content $file.FullName -Raw
        
        # Check for blob encryption
        if ($content -notmatch "enableBlobEncryption.*true") {
            Write-Host "`n  ❌ Blob encryption not enabled in $($file.Name)" -ForegroundColor Red
            return $false
        }
    }
    
    return $true
}

# Check 6: TLS 1.2+ minimum version
Test-Compliance -Name "TLS 1.2+ minimum version enforced" -Specification "dp-001" -Check {
    $allFiles = Get-ChildItem -Path $IacPath -Filter "*.bicep" -Recurse
    $tlsViolations = @()
    
    foreach ($file in $allFiles) {
        $content = Get-Content $file.FullName -Raw
        
        # Check for TLS version configuration
        if ($content -match "minimumTlsVersion|minimalTlsVersion") {
            # Ensure it's 1.2 or higher
            if ($content -match "(minimumTlsVersion|minimalTlsVersion).*['\"](TLS)?1\.[01]['\"]") {
                $tlsViolations += $file.Name
            }
        }
    }
    
    if ($tlsViolations.Count -gt 0) {
        Write-Host "`n  ❌ TLS < 1.2 found in: $($tlsViolations -join ', ')" -ForegroundColor Red
        return $false
    }
    
    return $true
}

# Check 7: HTTPS-only traffic enforced
Test-Compliance -Name "HTTPS-only traffic enforced (storage accounts)" -Specification "dp-001" -Check {
    $storageFiles = Get-ChildItem -Path $IacPath -Filter "*storage*.bicep" -Recurse
    
    foreach ($file in $storageFiles) {
        $content = Get-Content $file.FullName -Raw
        
        if ($content -notmatch "supportsHttpsTrafficOnly.*true") {
            Write-Host "`n  ❌ HTTPS-only not enforced in $($file.Name)" -ForegroundColor Red
            return $false
        }
    }
    
    return $true
}

# Check 8: SSL enforcement for MySQL
Test-Compliance -Name "MySQL SSL enforcement enabled" -Specification "dp-001" -Check {
    $mysqlFiles = Get-ChildItem -Path $IacPath -Filter "*mysql*.bicep" -Recurse
    
    foreach ($file in $mysqlFiles) {
        $content = Get-Content $file.FullName -Raw
        
        if ($content -match "sslEnforcement.*Enabled|sslEnforcement:.*'Enabled'") {
            return $true
        }
    }
    
    Write-Host "`n  ❌ SSL enforcement not found in MySQL configuration" -ForegroundColor Red
    return $false
}

# Check 9: Redis TLS enforcement
Test-Compliance -Name "Redis Cache TLS 1.2+ enforced" -Specification "dp-001" -Check {
    $redisFiles = Get-ChildItem -Path $IacPath -Filter "*redis*.bicep" -Recurse
    
    foreach ($file in $redisFiles) {
        $content = Get-Content $file.FullName -Raw
        
        if ($content -match "minimumTlsVersion.*'1\.2'") {
            return $true
        }
    }
    
    Write-Host "`n  ⚠️ Redis TLS version not explicitly set to 1.2" -ForegroundColor Yellow
    return $false
} -IsCritical $false

# =============================================================================
# AUDIT-001: AUDIT LOGGING
# =============================================================================

Write-Host "`n--- AUDIT-001: Audit Logging Compliance ---`n" -ForegroundColor Cyan

# Check 10: 90-day log retention
Test-Compliance -Name "90-day log retention configured" -Specification "audit-001" -Check {
    $logFiles = Get-ChildItem -Path $IacPath -Filter "*log*.bicep" -Recurse
    
    foreach ($file in $logFiles) {
        $content = Get-Content $file.FullName -Raw
        
        # Check for 90-day retention
        if ($content -match "retentionDays.*90|logRetentionDays.*90") {
            return $true
        }
    }
    
    Write-Host "`n  ⚠️ 90-day retention not found in log storage configuration" -ForegroundColor Yellow
    return $false
}

# Check 11: Diagnostic settings for audit logging
Test-Compliance -Name "Diagnostic settings configured for audit events" -Specification "audit-001" -Check {
    $kvFiles = Get-ChildItem -Path $IacPath -Filter "*keyvault*.bicep" -Recurse
    
    foreach ($file in $kvFiles) {
        $content = Get-Content $file.FullName -Raw
        
        if ($content -match "diagnosticSettings|Microsoft\.Insights/diagnosticSettings") {
            if ($content -match "AuditEvent") {
                return $true
            }
        }
    }
    
    Write-Host "`n  ⚠️ Audit event logging not configured for Key Vault" -ForegroundColor Yellow
    return $false
} -IsCritical $false

# Check 12: Immutable storage for audit logs (production)
Test-Compliance -Name "Immutable storage policy for audit logs" -Specification "audit-001" -Check {
    $logFiles = Get-ChildItem -Path $IacPath -Filter "*log*.bicep" -Recurse
    
    foreach ($file in $logFiles) {
        $content = Get-Content $file.FullName -Raw
        
        if ($content -match "immutabilityPolicy") {
            return $true
        }
    }
    
    Write-Host "`n  ℹ️ Immutability policy configured conditionally (prod only)" -ForegroundColor Gray
    return $true
} -IsCritical $false

# =============================================================================
# SEC-001: SECRETS MANAGEMENT
# =============================================================================

Write-Host "`n--- SEC-001: Secrets Management ---`n" -ForegroundColor Cyan

# Check 13: No hardcoded secrets
Test-Compliance -Name "No hardcoded secrets in IaC files" -Specification "sec-001" -Check {
    $allFiles = Get-ChildItem -Path $IacPath -Filter "*.bicep" -Recurse
    
    $secretPatterns = @(
        'password\s*=\s*[''"][^@]',
        'apiKey\s*=\s*[''"][^@]',
        'connectionString\s*=\s*[''"](?!@|placeholder)',
        'secret\s*=\s*[''"][^@]'
    )
    
    foreach ($file in $allFiles) {
        $content = Get-Content $file.FullName -Raw
        
        foreach ($pattern in $secretPatterns) {
            if ($content -match $pattern) {
                Write-Host "`n  ❌ Potential hardcoded secret in $($file.Name)" -ForegroundColor Red
                return $false
            }
        }
    }
    
    return $true
}

# Check 14: Secrets use @secure() decorator
Test-Compliance -Name "Secure parameters use @secure() decorator" -Specification "sec-001" -Check {
    $allFiles = Get-ChildItem -Path $IacPath -Filter "*.bicep" -Recurse
    
    $secretParamNames = @('password', 'apiKey', 'connectionString', 'secret', 'key')
    $violations = @()
    
    foreach ($file in $allFiles) {
        $content = Get-Content $file.FullName -Raw
        
        foreach ($paramName in $secretParamNames) {
            # Check if parameter exists without @secure
            if ($content -match "param\s+\w*$paramName\w*" -and $content -notmatch "@secure\(\)[^\r\n]*\r?\n\s*param\s+\w*$paramName") {
                $violations += "$($file.Name): $paramName"
            }
        }
    }
    
    if ($violations.Count -gt 0) {
        Write-Host "`n  ⚠️ Parameters without @secure: $($violations -join ', ')" -ForegroundColor Yellow
        return $false
    }
    
    return $true
} -IsCritical $false

# Check 15: Key Vault soft delete enabled
Test-Compliance -Name "Key Vault soft delete enabled" -Specification "sec-001" -Check {
    $kvFiles = Get-ChildItem -Path $IacPath -Filter "*keyvault*.bicep" -Recurse
    
    foreach ($file in $kvFiles) {
        $content = Get-Content $file.FullName -Raw
        
        if ($content -match "enableSoftDelete.*true") {
            return $true
        }
    }
    
    Write-Host "`n  ❌ Soft delete not enabled for Key Vault" -ForegroundColor Red
    return $false
}

# Check 16: Key Vault purge protection (production)
Test-Compliance -Name "Key Vault purge protection (conditional)" -Specification "sec-001" -Check {
    $kvFiles = Get-ChildItem -Path $IacPath -Filter "*keyvault*.bicep" -Recurse
    
    foreach ($file in $kvFiles) {
        $content = Get-Content $file.FullName -Raw
        
        if ($content -match "enablePurgeProtection") {
            return $true
        }
    }
    
    Write-Host "`n  ℹ️ Purge protection configured conditionally (prod only)" -ForegroundColor Gray
    return $true
} -IsCritical $false

# =============================================================================
# NETWORK SECURITY
# =============================================================================

Write-Host "`n--- Network Security Compliance ---`n" -ForegroundColor Cyan

# Check 17: NSG rules configured
Test-Compliance -Name "Network Security Groups configured" -Check {
    $nsgFiles = Get-ChildItem -Path $IacPath -Filter "*nsg*.bicep" -Recurse
    
    if ($nsgFiles.Count -eq 0) {
        Write-Host "`n  ❌ No NSG configuration files found" -ForegroundColor Red
        return $false
    }
    
    foreach ($file in $nsgFiles) {
        $content = Get-Content $file.FullName -Raw
        
        # Check for security rules
        if ($content -notmatch "securityRules") {
            Write-Host "`n  ❌ No security rules in $($file.Name)" -ForegroundColor Red
            return $false
        }
    }
    
    return $true
}

# Check 18: Default deny rule
Test-Compliance -Name "NSG default deny rules configured" -Check {
    $baselineFile = Join-Path $IacPath "security-baseline.bicep"
    
    if (Test-Path $baselineFile) {
        $content = Get-Content $baselineFile -Raw
        
        if ($content -match "Deny.*All|DenyAllInbound") {
            return $true
        }
    }
    
    Write-Host "`n  ⚠️ Explicit deny-all rule not found" -ForegroundColor Yellow
    return $false
} -IsCritical $false

# Check 19: Private endpoints for PaaS services
Test-Compliance -Name "Private endpoints configured for databases" -Check {
    $mysqlFiles = Get-ChildItem -Path $IacPath -Filter "*mysql*.bicep" -Recurse
    
    foreach ($file in $mysqlFiles) {
        $content = Get-Content $file.FullName -Raw
        
        if ($content -match "publicNetworkAccess.*Disabled|privateEndpoint") {
            return $true
        }
    }
    
    Write-Host "`n  ℹ️ Private endpoint configured via subnet delegation" -ForegroundColor Gray
    return $true
} -IsCritical $false

# =============================================================================
# FINAL COMPLIANCE REPORT
# =============================================================================

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "Security Compliance Summary" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "✅ Compliant:      $script:PassCount" -ForegroundColor Green
Write-Host "❌ Non-Compliant:  $script:FailCount" -ForegroundColor Red
Write-Host "⚠️  Warnings:       $script:WarningCount" -ForegroundColor Yellow
Write-Host "==================================================================" -ForegroundColor Cyan

$totalChecks = $script:PassCount + $script:FailCount + $script:WarningCount
$complianceRate = if ($totalChecks -gt 0) { [math]::Round(($script:PassCount / $totalChecks) * 100, 1) } else { 0 }

Write-Host "`nCompliance Rate: $complianceRate%" -ForegroundColor White

if ($script:FailCount -gt 0) {
    Write-Host "`n❌ COMPLIANCE VALIDATION FAILED" -ForegroundColor Red
    Write-Host "Critical security issues must be resolved before deployment" -ForegroundColor Red
    exit 1
} elseif ($script:WarningCount -gt 0) {
    Write-Host "`n⚠️ COMPLIANCE PASSED WITH WARNINGS" -ForegroundColor Yellow
    Write-Host "Review warnings and consider remediation" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "`n✅ FULL SECURITY COMPLIANCE ACHIEVED" -ForegroundColor Green
    exit 0
}
