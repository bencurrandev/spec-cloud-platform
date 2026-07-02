// =============================================================================
// Patio Application - Virtual Network Module
// =============================================================================
// Purpose: Deploy VNet with subnets for web, database, and cache tiers
// Uses: AVM wrapper for Virtual Network (avm-wrapper-vnet)
// Compliance: net-001 v2.0.0 (single-zone non-critical), comp-001 (US regions)
// =============================================================================

// PARAMETERS
// -----------------------------------------------------------------------------

@description('Environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string

@description('Azure region (US regions only per comp-001, limited to centralus or eastus for AVM compatibility)')
@allowed(['eastus', 'centralus'])
param location string

@description('VNet name')
param vnetName string

@description('VNet address prefix')
param addressPrefix string

@description('Web subnet address prefix')
param subnetWebAddressPrefix string

@description('Database subnet address prefix')
param subnetDatabaseAddressPrefix string

@description('Cache subnet address prefix')
param subnetCacheAddressPrefix string

@description('Workload criticality tier')
param workloadCriticality string

@description('Common tags')
param tags object

// VARIABLES
// -----------------------------------------------------------------------------

// Subnet names
var subnetWebName = 'snet-web'
var subnetDatabaseName = 'snet-database'
var subnetCacheName = 'snet-cache'

// Convert subnet parameters to array format required by AVM wrapper
var subnetArray = [
  {
    name: subnetWebName
    addressPrefix: subnetWebAddressPrefix
  }
  {
    name: subnetDatabaseName
    addressPrefix: subnetDatabaseAddressPrefix
    delegations: [
      {
        name: 'MySQLFlexibleServerDelegation'
        properties: {
          serviceName: 'Microsoft.DBforMySQL/flexibleServers'
        }
      }
    ]
  }
  {
    name: subnetCacheName
    addressPrefix: subnetCacheAddressPrefix
    privateEndpointNetworkPolicies: 'Disabled'
  }
]

// MODULES
// -----------------------------------------------------------------------------

// Deploy VNet using AVM wrapper
module vnetDeployment '../../../../infrastructure/iac-modules/avm-wrapper-vnet/main.bicep' = {
  name: 'vnet-${environment}-deployment'
  params: {
    vnetName: vnetName
    workloadCriticality: workloadCriticality
    addressPrefix: addressPrefix
    environment: environment == 'dev' ? 'dev' : 'prod'
    location: location
    subnets: subnetArray
    nsgIds: {} // NSGs will be associated separately
    enableDdosProtection: false // Not required for non-critical tier (cost optimization)
    additionalTags: tags
  }
}

// OUTPUTS
// -----------------------------------------------------------------------------

@description('VNet resource ID')
output vnetId string = vnetDeployment.outputs.vnetId

@description('VNet name')
output vnetName string = vnetDeployment.outputs.vnetName

@description('Web subnet ID')
output subnetWebId string = vnetDeployment.outputs.subnetIds[0]

@description('Database subnet ID')
output subnetDatabaseId string = vnetDeployment.outputs.subnetIds[1]

@description('Cache subnet ID')
output subnetCacheId string = vnetDeployment.outputs.subnetIds[2]

@description('Subnet names')
output subnetNames object = {
  web: subnetWebName
  database: subnetDatabaseName
  cache: subnetCacheName
}
