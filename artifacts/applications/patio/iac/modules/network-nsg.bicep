// =============================================================================
// Patio Application - Network Security Group Module
// =============================================================================
// Purpose: Deploy NSGs for web, database, and cache tiers with security rules
// Uses: AVM wrapper for NSG (avm-wrapper-nsg)
// Compliance: ac-001 (access control), dp-001 (encryption), net-001 v2.0.0
// =============================================================================

// PARAMETERS
// -----------------------------------------------------------------------------

@description('Environment name (dev, staging, prod)')
param environment string

@description('Azure region')
param location string

@description('NSG names')
param nsgNames object

@description('Security rules from security baseline')
param webNsgRules array
param databaseNsgRules array
param cacheNsgRules array

@description('Common tags')
param tags object

// MODULES
// -----------------------------------------------------------------------------

// Determine environment tier for AVM wrapper (dev or prod only)
var avmEnvironment = environment == 'dev' ? 'dev' : 'prod'

// Web Tier NSG
module webNsg '../../../../infrastructure/iac-modules/avm-wrapper-nsg/main.bicep' = {
  name: 'nsg-web-${environment}-deployment'
  params: {
    nsgName: nsgNames.web
    environment: avmEnvironment
    location: location
    customRules: webNsgRules
    additionalTags: union(tags, {
      Tier: 'web'
      Purpose: 'web-tier-security'
    })
  }
}

// Database Tier NSG
module databaseNsg '../../../../infrastructure/iac-modules/avm-wrapper-nsg/main.bicep' = {
  name: 'nsg-database-${environment}-deployment'
  params: {
    nsgName: nsgNames.database
    environment: avmEnvironment
    location: location
    customRules: databaseNsgRules
    additionalTags: union(tags, {
      Tier: 'database'
      Purpose: 'database-tier-security'
    })
  }
}

// Cache Tier NSG
module cacheNsg '../../../../infrastructure/iac-modules/avm-wrapper-nsg/main.bicep' = {
  name: 'nsg-cache-${environment}-deployment'
  params: {
    nsgName: nsgNames.cache
    environment: avmEnvironment
    location: location
    customRules: cacheNsgRules
    additionalTags: union(tags, {
      Tier: 'cache'
      Purpose: 'cache-tier-security'
    })
  }
}

// OUTPUTS
// -----------------------------------------------------------------------------

@description('NSG resource IDs')
output nsgIds object = {
  web: webNsg.outputs.nsgId
  database: databaseNsg.outputs.nsgId
  cache: cacheNsg.outputs.nsgId
}

@description('NSG names')
output nsgNames object = {
  web: webNsg.outputs.nsgName
  database: databaseNsg.outputs.nsgName
  cache: cacheNsg.outputs.nsgName
}
