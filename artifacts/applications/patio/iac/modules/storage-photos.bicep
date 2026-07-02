// =============================================================================
// Patio Application - Photo Storage Account Module
// =============================================================================
// Purpose: Deploy Azure Storage Account for patio photos
// Uses: AVM wrapper for Storage Account (avm-wrapper-storage-account)
// Compliance: dp-001 (encryption), stor-001 (backups/lifecycle), cost-001 (LRS)
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

@description('Enable blob versioning for data protection')
param enableVersioning bool = false

@description('Lifecycle management days (move to cool tier after N days)')
param coolTierAfterDays int = 30

@description('Lifecycle management days (delete after N days)')
param deleteAfterDays int = 365

// VARIABLES
// -----------------------------------------------------------------------------

// Container names
var photoContainerName = 'patio-photos'
var thumbnailContainerName = 'patio-thumbnails'

// SKU (Standard LRS for cost optimization per cost-001)
var sku = 'Standard_LRS'

// Determine environment tier for AVM wrapper (dev or prod only)
var avmEnvironment = environment == 'dev' ? 'dev' : 'prod'

// MODULES
// -----------------------------------------------------------------------------

// Deploy Storage Account using AVM wrapper
module storageAccount '../../../../infrastructure/iac-modules/avm-wrapper-storage-account/main.bicep' = {
  name: 'storage-photos-${environment}-deployment'
  params: {
    storageAccountName: storageAccountName
    environment: avmEnvironment
    location: location
    sku: sku
    kind: 'StorageV2'
    accessTier: 'Hot' // Hot tier for frequently accessed photos
    minimumTlsVersion: 'TLS1_2' // TLS 1.2 minimum (per dp-001 v1.0.0)
    enableBlobSoftDelete: enableVersioning
    blobSoftDeleteRetentionDays: 30
    supportsHttpsTrafficOnly: true // HTTPS only (per dp-001)
    publicNetworkAccess: 'Enabled' // Allow public for dev, deny for prod
    networkAclsBypass: 'AzureServices'
    networkAclsDefaultAction: environment == 'prod' ? 'Deny' : 'Allow'
    subnetIds: [] // Will be configured after VNet deployment
    additionalTags: union(tags, {
      Tier: 'storage'
      Purpose: 'patio-photos'
      DataClassification: 'public-content'
    })
  }
}

// BLOB CONTAINERS
// -----------------------------------------------------------------------------

// Container for full-size patio photos
resource photoContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  name: '${storageAccountName}/default/${photoContainerName}'
  dependsOn: [
    storageAccount
  ]
  properties: {
    publicAccess: 'None' // No public access
    metadata: {
      purpose: 'patio-photos'
      environment: environment
    }
  }
}

// Container for photo thumbnails (for fast loading in search results)
resource thumbnailContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  name: '${storageAccountName}/default/${thumbnailContainerName}'
  dependsOn: [
    storageAccount
  ]
  properties: {
    publicAccess: 'None'
    metadata: {
      purpose: 'patio-thumbnails'
      environment: environment
    }
  }
}

// LIFECYCLE MANAGEMENT
// -----------------------------------------------------------------------------

// Lifecycle policy: Move to cool tier after 30 days, delete after 1 year
resource lifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2025-01-01' = {
  name: '${storageAccountName}/default'
  dependsOn: [
    storageAccount
    photoContainer
    thumbnailContainer
  ]
  properties: {
    policy: {
      rules: [
        {
          enabled: true
          name: 'move-photos-to-cool'
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: [
                photoContainerName
              ]
            }
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: coolTierAfterDays
                }
                delete: {
                  daysAfterModificationGreaterThan: deleteAfterDays
                }
              }
            }
          }
        }
        {
          enabled: true
          name: 'delete-old-thumbnails'
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: [
                thumbnailContainerName
              ]
            }
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: coolTierAfterDays
                }
                delete: {
                  daysAfterModificationGreaterThan: deleteAfterDays
                }
              }
            }
          }
        }
      ]
    }
  }
}

// BLOB VERSIONING (OPTIONAL - for prod environments)
// -----------------------------------------------------------------------------

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = if (enableVersioning) {
  name: '${storageAccountName}/default'
  dependsOn: [
    storageAccount
  ]
  properties: {
    isVersioningEnabled: enableVersioning
    deleteRetentionPolicy: {
      enabled: true
      days: 7 // Keep deleted blobs for 7 days
    }
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

@description('Photo container name')
output photoContainerName string = photoContainerName

@description('Thumbnail container name')
output thumbnailContainerName string = thumbnailContainerName
