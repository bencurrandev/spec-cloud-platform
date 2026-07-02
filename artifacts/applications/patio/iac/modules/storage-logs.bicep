// =============================================================================
// Patio Application - Log Storage Account Module
// =============================================================================
// Purpose: Deploy Azure Storage Account for application logs and audit trails
// Uses: AVM wrapper for Storage Account (avm-wrapper-storage-account)
// Compliance: audit-001 (90-day retention), dp-001 (encryption), stor-001
// =============================================================================

// PARAMETERS
// -----------------------------------------------------------------------------

@description('Environment name (dev, staging, prod)')
param environment string

@description('Azure region (US regions only per comp-001)')
param location string

@description('Storage account name (must be globally unique, lowercase, no hyphens)')
param storageAccountName string

@description('Common tags')
param tags object

@description('Log retention days (per audit-001: minimum 90 days)')
param logRetentionDays int = 90

// VARIABLES
// -----------------------------------------------------------------------------

// Container names
var applicationLogsContainer = 'application-logs'
var auditLogsContainer = 'audit-logs'
var webServerLogsContainer = 'webserver-logs'
var databaseLogsContainer = 'database-logs'

// SKU (Standard LRS for cost optimization per cost-001)
var sku = 'Standard_LRS'

// Determine environment tier for AVM wrapper (dev or prod only)
var avmEnvironment = environment == 'dev' ? 'dev' : 'prod'

// MODULES
// -----------------------------------------------------------------------------

// Deploy Storage Account using AVM wrapper
module storageAccount '../../../../infrastructure/iac-modules/avm-wrapper-storage-account/main.bicep' = {
  name: 'storage-logs-${environment}-deployment'
  params: {
    storageAccountName: storageAccountName
    environment: avmEnvironment
    location: location
    sku: sku
    kind: 'StorageV2'
    accessTier: 'Cool' // Cool tier for infrequently accessed logs (cost optimization)
    minimumTlsVersion: 'TLS1_2' // TLS 1.2 minimum (per dp-001 v1.0.0)
    enableBlobSoftDelete: environment == 'prod'
    blobSoftDeleteRetentionDays: logRetentionDays
    supportsHttpsTrafficOnly: true // HTTPS only (per dp-001)
    publicNetworkAccess: environment == 'prod' ? 'Disabled' : 'Enabled'
    networkAclsBypass: 'AzureServices'
    networkAclsDefaultAction: environment == 'prod' ? 'Deny' : 'Allow'
    subnetIds: [] // Will be configured after VNet deployment
    additionalTags: union(tags, {
      Tier: 'storage'
      Purpose: 'application-logs'
      DataClassification: environment == 'prod' ? 'audit-sensitive' : 'test-data'
      Compliance: 'audit-001-v1.0.0'
    })
  }
}

// BLOB CONTAINERS
// -----------------------------------------------------------------------------

// Container for application logs (Laravel/Symfony framework logs)
resource applicationLogsContainerResource 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  name: '${storageAccountName}/default/${applicationLogsContainer}'
  dependsOn: [
    storageAccount
  ]
  properties: {
    publicAccess: 'None'
    metadata: {
      purpose: 'application-logs'
      environment: environment
      retention: '${logRetentionDays}-days'
    }
  }
}

// Container for audit logs (user actions, security events per audit-001)
resource auditLogsContainerResource 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  name: '${storageAccountName}/default/${auditLogsContainer}'
  dependsOn: [
    storageAccount
  ]
  properties: {
    publicAccess: 'None'
    metadata: {
      purpose: 'audit-logs'
      environment: environment
      retention: '${logRetentionDays}-days'
      compliance: 'audit-001-v1.0.0'
    }
  }
}

// Container for web server logs (Apache access/error logs)
resource webServerLogsContainerResource 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  name: '${storageAccountName}/default/${webServerLogsContainer}'
  dependsOn: [
    storageAccount
  ]
  properties: {
    publicAccess: 'None'
    metadata: {
      purpose: 'webserver-logs'
      environment: environment
      retention: '${logRetentionDays}-days'
    }
  }
}

// Container for database logs (MySQL slow query logs, error logs)
resource databaseLogsContainerResource 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  name: '${storageAccountName}/default/${databaseLogsContainer}'
  dependsOn: [
    storageAccount
  ]
  properties: {
    publicAccess: 'None'
    metadata: {
      purpose: 'database-logs'
      environment: environment
      retention: '${logRetentionDays}-days'
    }
  }
}

// LIFECYCLE MANAGEMENT
// -----------------------------------------------------------------------------

// Lifecycle policy: Delete logs after retention period (90 days for audit compliance)
resource lifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2025-01-01' = {
  name: '${storageAccountName}/default'
  dependsOn: [
    storageAccount
    applicationLogsContainerResource
    auditLogsContainerResource
    webServerLogsContainerResource
    databaseLogsContainerResource
  ]
  properties: {
    policy: {
      rules: [
        {
          enabled: true
          name: 'delete-old-application-logs'
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [
                'blockBlob'
                'appendBlob'
              ]
              prefixMatch: [
                applicationLogsContainer
              ]
            }
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: logRetentionDays
                }
              }
            }
          }
        }
        {
          enabled: true
          name: 'delete-old-audit-logs'
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [
                'blockBlob'
                'appendBlob'
              ]
              prefixMatch: [
                auditLogsContainer
              ]
            }
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: logRetentionDays
                }
              }
            }
          }
        }
        {
          enabled: true
          name: 'delete-old-webserver-logs'
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [
                'blockBlob'
                'appendBlob'
              ]
              prefixMatch: [
                webServerLogsContainer
              ]
            }
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: logRetentionDays
                }
              }
            }
          }
        }
        {
          enabled: true
          name: 'delete-old-database-logs'
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [
                'blockBlob'
                'appendBlob'
              ]
              prefixMatch: [
                databaseLogsContainer
              ]
            }
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: logRetentionDays
                }
              }
            }
          }
        }
      ]
    }
  }
}

// IMMUTABLE STORAGE (for audit logs in production)
// -----------------------------------------------------------------------------

// Enable immutability policy for audit logs container in production
resource auditLogsImmutability 'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies@2025-01-01' = if (environment == 'prod') {
  name: '${storageAccountName}/default/${auditLogsContainer}/default'
  dependsOn: [
    auditLogsContainerResource
  ]
  properties: {
    immutabilityPeriodSinceCreationInDays: logRetentionDays
    allowProtectedAppendWrites: true // Allow append for logging
  }
}

// OUTPUTS
// -----------------------------------------------------------------------------

@description('Storage account resource ID')
output storageAccountId string = storageAccount.outputs.storageAccountId

@description('Storage account name')
output storageAccountName string = storageAccount.outputs.storageAccountName

@description('Primary blob endpoint')
output primaryBlobEndpoint string = storageAccount.outputs.primaryBlobEndpoint

@description('Application logs container name')
output applicationLogsContainer string = applicationLogsContainer

@description('Audit logs container name')
output auditLogsContainer string = auditLogsContainer

@description('Web server logs container name')
output webServerLogsContainer string = webServerLogsContainer

@description('Database logs container name')
output databaseLogsContainer string = databaseLogsContainer

@description('Log retention period (days)')
output logRetentionDays int = logRetentionDays
