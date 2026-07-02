// =============================================================================
// Patio Application - Shared Variables & Configuration
// =============================================================================
// Purpose: Centralized variables, naming conventions, and common configuration
// Compliance: artifact-001 (naming), cost-001 (tagging), comp-001 (data residency)
// Version: 1.0.0
// =============================================================================

// PARAMETERS
// -----------------------------------------------------------------------------

@description('Environment name (dev, staging, prod)')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string

@description('Azure region for deployment (US regions only per comp-001)')
@allowed([
  'eastus'
  'eastus2'
  'westus2'
  'centralus'
])
param location string = 'eastus'

@description('Application name')
param applicationName string = 'patio'

@description('Workload criticality tier per cost-001')
@allowed([
  'non-critical'
  'moderate'
  'critical'
])
param workloadCriticality string = 'non-critical'

// NAMING CONVENTIONS
// -----------------------------------------------------------------------------
// Per artifact-001: Standardized resource naming
// Format: <resource-type>-<app>-<env>-<location>-<instance>

var namingPrefix = '${applicationName}-${environment}'
var locationShort = {
  eastus: 'eus'
  eastus2: 'eus2'
  westus2: 'wus2'
  centralus: 'cus'
}[location]

// Resource naming patterns
var resourceNames = {
  // Resource Group
  resourceGroup: 'rg-${namingPrefix}-${location}'
  
  // Networking
  vnet: 'vnet-${namingPrefix}-${locationShort}'
  nsgWeb: 'nsg-${namingPrefix}-web-${locationShort}'
  nsgDatabase: 'nsg-${namingPrefix}-db-${locationShort}'
  nsgCache: 'nsg-${namingPrefix}-cache-${locationShort}'
  publicIp: 'pip-${namingPrefix}-${locationShort}'
  loadBalancer: 'lb-${namingPrefix}-${locationShort}'
  
  // Compute
  vmWeb: 'vm-${namingPrefix}-web' // Appends -001, -002, etc. per instance
  availabilitySet: 'avset-${namingPrefix}-web-${locationShort}'
  
  // Database
  mysqlServer: 'mysql-${namingPrefix}-${locationShort}'
  mysqlDatabase: 'patiodb'
  
  // Cache
  redis: 'redis-${namingPrefix}-${locationShort}'
  
  // Storage
  // Storage account names: no hyphens, max 24 chars, lowercase only
  storagePhotos: take('st${applicationName}${environment}photos${locationShort}', 24)
  storageLogs: take('st${applicationName}${environment}logs${locationShort}', 24)
  containerPhotos: 'patio-photos'
  containerLogs: 'application-logs'
  
  // Security
  keyVault: 'kv-${namingPrefix}-${locationShort}'
  
  // Monitoring
  logAnalytics: 'log-${namingPrefix}-${locationShort}'
  applicationInsights: 'appi-${namingPrefix}-${locationShort}'
  
  // Networking subnets
  subnetWeb: 'snet-web'
  subnetDatabase: 'snet-database'
  subnetCache: 'snet-cache'
}

// COMMON TAGS
// -----------------------------------------------------------------------------
// Per cost-001: Required tags for cost tracking and governance

var commonTags = {
  Environment: environment
  Application: applicationName
  CostCenter: environment == 'prod' ? 'revenue-operations' : 'engineering'
  Compliance: 'NIST-800-171'
  Tier: 'application'
  Workload: 'non-critical'
  Owner: 'platform-team'
  ManagedBy: 'bicep-iac'
  IaCRepo: 'spec-cloud-platform'
  DataClassification: environment == 'prod' ? 'customer-data' : 'test-data'
}

// NETWORK CONFIGURATION
// -----------------------------------------------------------------------------

var networkConfig = {
  vnetAddressPrefix: environment == 'dev' ? '10.0.0.0/16' : environment == 'staging' ? '10.1.0.0/16' : '10.2.0.0/16'
  subnets: {
    web: {
      addressPrefix: environment == 'dev' ? '10.0.1.0/24' : environment == 'staging' ? '10.1.1.0/24' : '10.2.1.0/24'
      name: resourceNames.subnetWeb
    }
    database: {
      addressPrefix: environment == 'dev' ? '10.0.2.0/24' : environment == 'staging' ? '10.1.2.0/24' : '10.2.2.0/24'
      name: resourceNames.subnetDatabase
      delegations: [
        {
          name: 'MySQLFlexibleServerDelegation'
          properties: {
            serviceName: 'Microsoft.DBforMySQL/flexibleServers'
          }
        }
      ]
    }
    cache: {
      addressPrefix: environment == 'dev' ? '10.0.3.0/24' : environment == 'staging' ? '10.1.3.0/24' : '10.2.3.0/24'
      name: resourceNames.subnetCache
      privateEndpointNetworkPolicies: 'Disabled'
    }
  }
}

// ENCRYPTION STANDARDS
// -----------------------------------------------------------------------------
// Per dp-001 v1.0.0: AES-256 encryption at rest, TLS 1.2+ in transit

var encryptionConfig = {
  // Storage encryption (always enabled on Azure Storage, using Microsoft-managed keys)
  storageEncryption: {
    services: {
      blob: {
        enabled: true
        keyType: 'Account'
      }
      file: {
        enabled: true
        keyType: 'Account'
      }
    }
    keySource: 'Microsoft.Storage'
  }
  
  // TLS version requirements
  minimumTlsVersion: 'TLS1_2'
  
  // MySQL encryption
  mysqlSslEnforcement: 'Enabled'
  mysqlMinimalTlsVersion: 'TLS1_2'
  
  // Redis encryption
  redisEnableNonSslPort: false
  redisMinimumTlsVersion: '1.2'
}

// COMPLIANCE CONFIGURATION
// -----------------------------------------------------------------------------
// Per comp-001: NIST 800-171 compliance requirements

var complianceConfig = {
  // Data residency: US regions only
  allowedLocations: [
    'eastus'
    'eastus2'
    'westus2'
    'centralus'
  ]
  
  // Backup and retention (per audit-001)
  logRetentionDays: 90 // 90-day audit log retention
  backupRetentionDays: 7 // 7-day backup retention (per stor-001)
  
  // Soft delete for Key Vault (production only)
  keyVaultSoftDeleteRetentionDays: 90
  keyVaultPurgeProtection: environment == 'prod' ? true : false
}

// COST CONSTRAINTS
// -----------------------------------------------------------------------------
// Per cost-001 v2.0.0: Non-critical tier budget limits

var costConfig = {
  // Monthly budget limits per environment
  monthlyBudget: environment == 'dev' ? 50 : environment == 'staging' ? 75 : 100
  
  // VM sizing per environment (per compute-001 v2.0.0)
  vmSku: environment == 'dev' ? 'Standard_B2s' : 'Standard_D2s_v3'
  vmCount: environment == 'dev' ? 1 : 2
  
  // MySQL sizing per environment
  mysqlSku: environment == 'dev' ? {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  } : {
    name: 'Standard_D2ds_v4'
    tier: 'GeneralPurpose'
  }
  mysqlStorageGB: environment == 'dev' ? 20 : 100
  
  // Redis sizing per environment
  redisSku: environment == 'dev' ? {
    name: 'Basic'
    family: 'C'
    capacity: 0 // C0 = 250MB
  } : {
    name: 'Standard'
    family: 'C'
    capacity: 1 // C1 = 1GB
  }
  
  // Storage SKU (per stor-001 v2.0.0)
  storageSku: 'Standard_LRS' // Standard LRS for non-critical tier
}

// OUTPUTS
// -----------------------------------------------------------------------------
// Export all shared configurations for use in other modules

output resourceNames object = resourceNames
output commonTags object = commonTags
output networkConfig object = networkConfig
output encryptionConfig object = encryptionConfig
output complianceConfig object = complianceConfig
output costConfig object = costConfig
output environment string = environment
output location string = location
output locationShort string = locationShort
