// =============================================================================
// Patio Application - Load Balancer Module
// =============================================================================
// Purpose: Deploy Standard Load Balancer for web tier (if enabled)
// Compliance: net-001 v2.0.0 (Standard SKU, single-zone for non-critical)
// Note: Only deployed for staging and production environments
// =============================================================================

// PARAMETERS
// -----------------------------------------------------------------------------

@description('Environment name (dev, staging, prod)')
param environment string

@description('Azure region')
param location string

@description('Load balancer name')
param loadBalancerName string

@description('Public IP resource ID')
param publicIpId string

@description('Common tags')
param tags object

@description('Backend pool name')
param backendPoolName string = 'web-backend-pool'

@description('Health probe port')
param healthProbePort int = 80

@description('Health probe protocol')
@allowed(['Http', 'Https', 'Tcp'])
param healthProbeProtocol string = 'Http'

@description('Health probe path (for HTTP/HTTPS probes)')
param healthProbePath string = '/health'

// VARIABLES
// -----------------------------------------------------------------------------

// Standard SKU for Standard Public IP (per net-001 v2.0.0)
var loadBalancerSku = 'Standard'

// Frontend IP configuration
var frontendIpConfig = {
  name: 'LoadBalancerFrontEnd'
  properties: {
    publicIPAddress: {
      id: publicIpId
    }
  }
}

// Backend address pool
var backendAddressPool = {
  name: backendPoolName
}

// Health probe configuration
var healthProbe = {
  name: 'health-probe'
  properties: {
    protocol: healthProbeProtocol
    port: healthProbePort
    requestPath: healthProbeProtocol != 'Tcp' ? healthProbePath : null
    intervalInSeconds: 15
    numberOfProbes: 2
  }
}

// Load balancing rule (HTTPS traffic to backend)
var loadBalancingRule = {
  name: 'https-lb-rule'
  properties: {
    frontendIPConfiguration: {
      id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, frontendIpConfig.name)
    }
    backendAddressPool: {
      id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, backendPoolName)
    }
    probe: {
      id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, healthProbe.name)
    }
    protocol: 'Tcp'
    frontendPort: 443
    backendPort: 443
    enableFloatingIP: false
    idleTimeoutInMinutes: 15
    enableTcpReset: true
  }
}

// HTTP to HTTPS redirect rule
var httpRedirectRule = {
  name: 'http-lb-rule'
  properties: {
    frontendIPConfiguration: {
      id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, frontendIpConfig.name)
    }
    backendAddressPool: {
      id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, backendPoolName)
    }
    probe: {
      id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, healthProbe.name)
    }
    protocol: 'Tcp'
    frontendPort: 80
    backendPort: 80
    enableFloatingIP: false
    idleTimeoutInMinutes: 15
    enableTcpReset: true
  }
}

// RESOURCES
// -----------------------------------------------------------------------------

// Load Balancer Resource
resource loadBalancer 'Microsoft.Network/loadBalancers@2024-05-01' = {
  name: loadBalancerName
  location: location
  tags: union(tags, {
    Purpose: 'web-tier-load-balancing'
    Tier: 'web'
  })
  sku: {
    name: loadBalancerSku
    tier: 'Regional' // Regional tier for single-zone deployment (non-critical per cost-001)
  }
  properties: {
    frontendIPConfigurations: [
      frontendIpConfig
    ]
    backendAddressPools: [
      backendAddressPool
    ]
    probes: [
      healthProbe
    ]
    loadBalancingRules: [
      loadBalancingRule
      httpRedirectRule
    ]
  }
}

// OUTPUTS
// -----------------------------------------------------------------------------

@description('Load balancer resource ID')
output loadBalancerId string = loadBalancer.id

@description('Load balancer name')
output loadBalancerName string = loadBalancer.name

@description('Backend pool ID')
output backendPoolId string = loadBalancer.properties.backendAddressPools[0].id

@description('Frontend IP configuration ID')
output frontendIpConfigId string = loadBalancer.properties.frontendIPConfigurations[0].id

@description('Load balancer public IP address (via Public IP resource)')
output loadBalancerPublicIp string = reference(publicIpId, '2023-05-01').ipAddress
