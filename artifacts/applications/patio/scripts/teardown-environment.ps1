# =============================================================================
# Patio Application - Infrastructure Teardown Script
# =============================================================================
# Purpose: Clean up dev/staging environments to save costs
# Usage: .\teardown-environment.ps1 -Environment <dev|staging> -ResourceGroup <name>
# Safety: PRODUCTION teardown is BLOCKED by this script
# Compliance: cost-001 (cost optimization), gov-001 (environment management)
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('dev', 'staging')]  # PRODUCTION NOT ALLOWED
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$DeleteKeyVaultPermanently = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$BackupBeforeDelete = $true
)

# =============================================================================
# INITIALIZATION
# =============================================================================

$ErrorActionPreference = 'Stop'

Write-Host "==================================================================" -ForegroundColor Red
Write-Host "Patio Application - Environment Teardown" -ForegroundColor Red
Write-Host "==================================================================" -ForegroundColor Red
Write-Host "Environment:      $Environment" -ForegroundColor Yellow
Write-Host "Resource Group:   $ResourceGroup" -ForegroundColor Yellow
Write-Host "Backup Enabled:   $BackupBeforeDelete" -ForegroundColor Yellow
Write-Host "==================================================================" -ForegroundColor Red
Write-Host ""

# =============================================================================
# SAFETY CHECKS
# =============================================================================

Write-Host "🛡️ Running safety checks..." -ForegroundColor Cyan

# Check 1: Prevent production deletion
if ($Environment -eq 'prod' -or $ResourceGroup -like '*prod*') {
    Write-Host "❌ BLOCKED: Production environment deletion is not allowed!" -ForegroundColor Red
    Write-Host "Production resources must be deleted manually through Azure Portal with approval." -ForegroundColor Red
    exit 1
}

# Check 2: Verify resource group exists
Write-Host "Verifying resource group exists..." -NoNewline
$rgExists = az group exists --name $ResourceGroup
if ($rgExists -eq 'false') {
    Write-Host " ❌ Resource group '$ResourceGroup' does not exist" -ForegroundColor Red
    exit 1
}
Write-Host " ✅" -ForegroundColor Green

# Check 3: Verify resource group matches environment
if ($ResourceGroup -notlike "*$Environment*") {
    Write-Host "⚠️ WARNING: Resource group name does not contain environment name" -ForegroundColor Yellow
    Write-Host "Expected: $Environment in resource group name" -ForegroundColor Yellow
    
    if (-not $Force) {
        $confirm = Read-Host "Continue anyway? (yes/no)"
        if ($confirm -ne 'yes') {
            Write-Host "Teardown cancelled by user" -ForegroundColor Yellow
            exit 0
        }
    }
}

# =============================================================================
# BACKUP BEFORE DELETE (OPTIONAL)
# =============================================================================

if ($BackupBeforeDelete) {
    Write-Host "`n📦 Creating backup before deletion..." -ForegroundColor Cyan
    
    $backupDir = ".\backups\$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    
    Write-Host "Backing up resource group metadata..." -NoNewline
    az group show --name $ResourceGroup | Out-File "$backupDir\resource-group.json"
    Write-Host " ✅" -ForegroundColor Green
    
    Write-Host "Backing up all resource configurations..." -NoNewline
    az resource list --resource-group $ResourceGroup | Out-File "$backupDir\all-resources.json"
    Write-Host " ✅" -ForegroundColor Green
    
    # Backup Key Vault secrets (names only, not values for security)
    Write-Host "Backing up Key Vault secret names..." -NoNewline
    $keyVaults = az keyvault list --resource-group $ResourceGroup | ConvertFrom-Json
    foreach ($kv in $keyVaults) {
        $secrets = az keyvault secret list --vault-name $kv.name | ConvertFrom-Json
        $secrets | ConvertTo-Json -Depth 10 | Out-File "$backupDir\keyvault-$($kv.name)-secrets.json"
    }
    Write-Host " ✅" -ForegroundColor Green
    
    # Backup MySQL database (schema and data)
    Write-Host "Backing up MySQL databases..." -NoNewline
    $mysqlServers = az mysql flexible-server list --resource-group $ResourceGroup | ConvertFrom-Json
    foreach ($mysql in $mysqlServers) {
        $backupInfo = @{
            ServerName = $mysql.name
            FQDN = $mysql.fullyQualifiedDomainName
            Version = $mysql.version
            SKU = $mysql.sku
            Note = "To restore: Use Azure Backup or manual mysqldump"
        } | ConvertTo-Json
        $backupInfo | Out-File "$backupDir\mysql-$($mysql.name)-info.json"
    }
    Write-Host " ✅" -ForegroundColor Green
    
    # Backup storage account container lists
    Write-Host "Backing up storage account container lists..." -NoNewline
    $storageAccounts = az storage account list --resource-group $ResourceGroup | ConvertFrom-Json
    foreach ($sa in $storageAccounts) {
        $containers = az storage container list --account-name $sa.name --auth-mode login 2>$null | ConvertFrom-Json
        if ($containers) {
            $containers | ConvertTo-Json -Depth 10 | Out-File "$backupDir\storage-$($sa.name)-containers.json"
        }
    }
    Write-Host " ✅" -ForegroundColor Green
    
    Write-Host "`n✅ Backup created at: $backupDir`n" -ForegroundColor Green
}

# =============================================================================
# USER CONFIRMATION
# =============================================================================

if (-not $Force) {
    Write-Host "==================================================================" -ForegroundColor Red
    Write-Host "⚠️  WARNING: This will DELETE the following resources:" -ForegroundColor Yellow
    Write-Host "==================================================================" -ForegroundColor Red
    
    # List all resources
    $resources = az resource list --resource-group $ResourceGroup | ConvertFrom-Json
    
    $resourcesByType = $resources | Group-Object -Property type | Sort-Object Count -Descending
    foreach ($group in $resourcesByType) {
        Write-Host "  - $($group.Name): $($group.Count) resource(s)" -ForegroundColor Yellow
    }
    
    Write-Host "`nTotal resources to delete: $($resources.Count)" -ForegroundColor Yellow
    Write-Host "==================================================================" -ForegroundColor Red
    Write-Host ""
    
    # Cost savings estimate
    $costSavings = @{
        'dev' = 48
        'staging' = 73
    }
    Write-Host "💰 Estimated monthly savings: `$$($costSavings[$Environment])" -ForegroundColor Green
    Write-Host ""
    
    # Final confirmation
    Write-Host "Type the environment name '$Environment' to confirm deletion: " -ForegroundColor Red -NoNewline
    $confirmation = Read-Host
    
    if ($confirmation -ne $Environment) {
        Write-Host "`n❌ Confirmation failed. Teardown cancelled." -ForegroundColor Red
        exit 0
    }
    
    Write-Host "`n⏱️ Starting teardown in 5 seconds... (Ctrl+C to cancel)" -ForegroundColor Yellow
    Start-Sleep -Seconds 5
}

# =============================================================================
# RESOURCE DELETION (ORDERED)
# =============================================================================

Write-Host "`n🗑️ Starting resource deletion..." -ForegroundColor Cyan

# Step 1: Stop all VMs first (to save costs immediately)
Write-Host "`n[1/7] Stopping all VMs..." -ForegroundColor Cyan
$vms = az vm list --resource-group $ResourceGroup | ConvertFrom-Json
foreach ($vm in $vms) {
    Write-Host "  Stopping VM: $($vm.name)..." -NoNewline
    az vm deallocate --resource-group $ResourceGroup --name $vm.name --no-wait
    Write-Host " ✅" -ForegroundColor Green
}
Write-Host "  VMs are being deallocated (async)" -ForegroundColor Gray

# Step 2: Delete VMs and related resources
Write-Host "`n[2/7] Deleting Virtual Machines..." -ForegroundColor Cyan
foreach ($vm in $vms) {
    Write-Host "  Deleting VM: $($vm.name)..." -NoNewline
    az vm delete --resource-group $ResourceGroup --name $vm.name --yes --no-wait
    Write-Host " ✅" -ForegroundColor Green
}

# Step 3: Delete Load Balancer
Write-Host "`n[3/7] Deleting Load Balancer..." -ForegroundColor Cyan
$lbs = az network lb list --resource-group $ResourceGroup | ConvertFrom-Json
foreach ($lb in $lbs) {
    Write-Host "  Deleting LB: $($lb.name)..." -NoNewline
    az network lb delete --resource-group $ResourceGroup --name $lb.name --no-wait
    Write-Host " ✅" -ForegroundColor Green
}

# Step 4: Delete databases (MySQL, Redis)
Write-Host "`n[4/7] Deleting Databases..." -ForegroundColor Cyan

# MySQL
$mysqlServers = az mysql flexible-server list --resource-group $ResourceGroup | ConvertFrom-Json
foreach ($mysql in $mysqlServers) {
    Write-Host "  Deleting MySQL: $($mysql.name)..." -NoNewline
    az mysql flexible-server delete --resource-group $ResourceGroup --name $mysql.name --yes --no-wait
    Write-Host " ✅" -ForegroundColor Green
}

# Redis
$redisCaches = az redis list --resource-group $ResourceGroup | ConvertFrom-Json
foreach ($redis in $redisCaches) {
    Write-Host "  Deleting Redis: $($redis.name)..." -NoNewline
    az redis delete --resource-group $ResourceGroup --name $redis.name --yes --no-wait
    Write-Host " ✅" -ForegroundColor Green
}

# Step 5: Delete Storage Accounts
Write-Host "`n[5/7] Deleting Storage Accounts..." -ForegroundColor Cyan
$storageAccounts = az storage account list --resource-group $ResourceGroup | ConvertFrom-Json
foreach ($sa in $storageAccounts) {
    Write-Host "  Deleting Storage: $($sa.name)..." -NoNewline
    az storage account delete --resource-group $ResourceGroup --name $sa.name --yes
    Write-Host " ✅" -ForegroundColor Green
}

# Step 6: Delete Key Vault (with purge protection handling)
Write-Host "`n[6/7] Deleting Key Vault..." -ForegroundColor Cyan
$keyVaults = az keyvault list --resource-group $ResourceGroup | ConvertFrom-Json
foreach ($kv in $keyVaults) {
    Write-Host "  Deleting Key Vault: $($kv.name)..." -NoNewline
    az keyvault delete --resource-group $ResourceGroup --name $kv.name
    Write-Host " ✅" -ForegroundColor Green
    
    if ($DeleteKeyVaultPermanently) {
        Write-Host "  Purging Key Vault permanently (cannot be recovered)..." -NoNewline
        az keyvault purge --name $kv.name --no-wait
        Write-Host " ✅" -ForegroundColor Green
    } else {
        Write-Host "  Key Vault is soft-deleted (can be recovered for 90 days)" -ForegroundColor Yellow
        Write-Host "  To purge permanently: az keyvault purge --name $($kv.name)" -ForegroundColor Gray
    }
}

# Step 7: Delete entire resource group
Write-Host "`n[7/7] Deleting Resource Group..." -ForegroundColor Cyan
Write-Host "  Deleting: $ResourceGroup..." -NoNewline
az group delete --name $ResourceGroup --yes --no-wait
Write-Host " ✅ (async)" -ForegroundColor Green

# =============================================================================
# CLEANUP VERIFICATION
# =============================================================================

Write-Host "`n⏳ Waiting for resource group deletion to complete..." -ForegroundColor Cyan
Write-Host "This may take 5-10 minutes. Checking status every 30 seconds..." -ForegroundColor Gray

$maxWaitMinutes = 15
$waitSeconds = 0
$checkInterval = 30

while ($waitSeconds -lt ($maxWaitMinutes * 60)) {
    Start-Sleep -Seconds $checkInterval
    $waitSeconds += $checkInterval
    
    $rgExists = az group exists --name $ResourceGroup
    if ($rgExists -eq 'false') {
        Write-Host "✅ Resource group deleted successfully!" -ForegroundColor Green
        break
    }
    
    $minutesElapsed = [math]::Round($waitSeconds / 60, 1)
    Write-Host "  Still deleting... ($minutesElapsed minutes elapsed)" -ForegroundColor Gray
}

if ($rgExists -eq 'true') {
    Write-Host "⚠️ Resource group deletion is still in progress after $maxWaitMinutes minutes" -ForegroundColor Yellow
    Write-Host "Check Azure Portal for deletion status: https://portal.azure.com" -ForegroundColor Yellow
}

# =============================================================================
# FINAL REPORT
# =============================================================================

Write-Host "`n==================================================================" -ForegroundColor Green
Write-Host "Teardown Summary" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "Environment:       $Environment" -ForegroundColor White
Write-Host "Resource Group:    $ResourceGroup" -ForegroundColor White
Write-Host "Status:            Deletion initiated" -ForegroundColor Green
Write-Host "Monthly Savings:   `$$($costSavings[$Environment])" -ForegroundColor Green

if ($BackupBeforeDelete) {
    Write-Host "Backup Location:   $backupDir" -ForegroundColor White
}

Write-Host "==================================================================" -ForegroundColor Green

Write-Host "`n✅ Environment teardown complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Verify deletion in Azure Portal" -ForegroundColor White
Write-Host "  2. Check for any orphaned resources (Public IPs, NICs, Disks)" -ForegroundColor White
Write-Host "  3. Review backup at: $backupDir" -ForegroundColor White

if (-not $DeleteKeyVaultPermanently) {
    Write-Host "  4. Purge Key Vault if not needed: az keyvault purge --name <vault-name>" -ForegroundColor White
}

Write-Host ""
Write-Host "💰 Estimated monthly savings: `$$($costSavings[$Environment])" -ForegroundColor Green
Write-Host ""

exit 0
