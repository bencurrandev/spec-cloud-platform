// =============================================================================
// Patio Application - Key Vault Module
// =============================================================================
// Purpose: Deploy Azure Key Vault for secrets management
// Uses: AVM wrapper for Key Vault (avm-wrapper-key-vault)
// Compliance: ac-001 (RBAC), dp-001 (encryption), sec-001 (secret management)
// =============================================================================

// PARAMETERS
// -----------------------------------------------------------------------------

@description('Environment name (dev, staging, prod)')
param environment string

@description('Azure region (US regions only per comp-001)')
param location string

@description('Key Vault name')
param keyVaultName string

@description('Tenant ID for Azure AD')
param tenantId string

@description('Common tags')
param tags object

@description('Enable purge protection (required for prod)')
param enablePurgeProtection bool = false

@description('Soft delete retention days')
param softDeleteRetentionDays int = 90

@description('Object IDs for Key Vault administrators')
param administratorObjectIds array = []

@description('Enable RBAC authorization (recommended over access policies)')
param enableRbacAuthorization bool = true

// VARIABLES
// -----------------------------------------------------------------------------

// SKU (Standard for non-critical tier per cost-001)
var sku = 'standard'

// Network ACLs (private endpoint recommended for prod)
var networkAcls = {
  defaultAction: environment == 'prod' ? 'Deny' : 'Allow'
  bypass: 'AzureServices'
  virtualNetworkRules: []
  ipRules: []
}

// MODULES
// -----------------------------------------------------------------------------

// Determine environment tier for AVM wrapper (dev or prod only)
var avmEnvironment = environment == 'dev' ? 'dev' : 'prod'

// Deploy Key Vault using AVM wrapper
module keyVault '../../../../infrastructure/iac-modules/avm-wrapper-key-vault/main.bicep' = {
  name: 'keyvault-${environment}-deployment'
  params: {
    keyVaultName: keyVaultName
    environment: avmEnvironment
    location: location
    softDeleteRetentionDays: softDeleteRetentionDays
    subnetIds: [] // Will be configured after VNet deployment
    additionalTags: union(tags, {
      Tier: 'security'
      Purpose: 'secrets-management'
      Compliance: 'ac-001-v1.0.0,dp-001-v1.0.0'
    })
  }
}

// OUTPUTS
// -----------------------------------------------------------------------------

@description('Key Vault resource ID')
output keyVaultId string = keyVault.outputs.keyVaultId

@description('Key Vault name')
output keyVaultName string = keyVault.outputs.keyVaultName

@description('Key Vault URI')
output keyVaultUri string = keyVault.outputs.keyVaultUri

@description('Key Vault tenant ID')
output tenantId string = tenantId
