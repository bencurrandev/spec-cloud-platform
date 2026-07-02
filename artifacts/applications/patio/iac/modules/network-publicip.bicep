// =============================================================================
// Patio Application - Public IP Module
// =============================================================================
// Purpose: Deploy static public IP for load balancer
// Uses: AVM wrapper for Public IP (avm-wrapper-public-ip)
// Compliance: net-001 v2.0.0
// =============================================================================

// PARAMETERS
// -----------------------------------------------------------------------------

@description('Environment name (dev, staging, prod)')
param environment string

@description('Azure region')
param location string

@description('Public IP name')
param publicIpName string

@description('Common tags')
param tags object

@description('DNS label for public IP (optional)')
param dnsLabel string = ''

// MODULES
// -----------------------------------------------------------------------------

// Determine environment tier for AVM wrapper (dev or prod only)
var avmEnvironment = environment == 'dev' ? 'dev' : 'prod'

// Deploy Public IP using AVM wrapper
module publicIpDeployment '../../../../infrastructure/iac-modules/avm-wrapper-public-ip/main.bicep' = {
  name: 'pip-${environment}-deployment'
  params: {
    publicIpName: publicIpName
    environment: avmEnvironment
    location: location
    dnsLabel: dnsLabel
    additionalTags: union(tags, {
      Purpose: 'load-balancer-frontend'
    })
  }
}

// OUTPUTS
// -----------------------------------------------------------------------------

@description('Public IP resource ID')
output publicIpId string = publicIpDeployment.outputs.publicIpId

@description('Public IP address')
output publicIpAddress string = publicIpDeployment.outputs.ipAddress

@description('Public IP FQDN (if DNS label provided)')
output fqdn string = empty(dnsLabel) ? '' : publicIpDeployment.outputs.fqdn
