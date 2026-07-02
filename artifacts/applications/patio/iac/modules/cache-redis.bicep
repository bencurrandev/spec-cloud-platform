// =============================================================================
// Patio Application - Redis Cache Module
// =============================================================================
// Purpose: Deploy Azure Cache for Redis (session storage, weather cache)
// Uses: Azure Cache for Redis (no AVM wrapper available)
// Compliance: dp-001 (encryption), stor-001 (persistence), cost-001 (SKU sizing)
// =============================================================================

// PARAMETERS
// -----------------------------------------------------------------------------

@description('Environment name (dev, staging, prod)')
param environment string

@description('Azure region (US regions only per comp-001)')
param location string

@description('Redis cache name')
param redisCacheName string

@description('Redis SKU (Basic, Standard, Premium)')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param redisSku string

@description('Redis SKU family (C, P)')
@allowed([
  'C'
  'P'
])
param redisSkuFamily string

@description('Redis capacity (0-6)')
@minValue(0)
@maxValue(6)
param redisCapacity int

@description('Common tags')
param tags object

@description('Enable non-SSL port (not recommended for production)')
param enableNonSslPort bool = false

@description('Subnet ID for private endpoint (Premium SKU only)')
param subnetId string = ''

@description('Minimum TLS version')
@allowed([
  '1.0'
  '1.1'
  '1.2'
])
param minimumTlsVersion string = '1.2'

// VARIABLES
// -----------------------------------------------------------------------------

// Redis configuration
var redisConfiguration = {
  'maxmemory-policy': 'allkeys-lru' // Evict least recently used keys when memory full
  'maxmemory-reserved': '50' // Reserve 50MB for memory management
  'maxfragmentationmemory-reserved': '50' // Reserve 50MB for fragmentation
}

// Firewall rules (if not using private endpoint)
var firewallRules = environment == 'prod' ? [] : [
  {
    name: 'AllowAllAzureIPs'
    startIP: '0.0.0.0'
    endIP: '0.0.0.0' // Special range that allows all Azure IPs
  }
]

// RESOURCES
// -----------------------------------------------------------------------------

// Deploy Azure Cache for Redis
resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: redisCacheName
  location: location
  tags: union(tags, {
    Tier: 'cache'
    Purpose: 'session-and-weather-cache'
    DataClassification: 'session-data'
  })
  properties: {
    sku: {
      name: redisSku
      family: redisSkuFamily
      capacity: redisCapacity
    }
    enableNonSslPort: enableNonSslPort
    minimumTlsVersion: minimumTlsVersion
    publicNetworkAccess: environment == 'prod' ? 'Disabled' : 'Enabled'
    redisConfiguration: redisConfiguration
    redisVersion: '6' // Redis 6.x (latest stable)
    
    // Private endpoint configuration (Premium SKU only)
    subnetId: redisSku == 'Premium' && !empty(subnetId) ? subnetId : null
    
    // Replication (Standard/Premium SKUs)
    replicasPerMaster: redisSku == 'Standard' || redisSku == 'Premium' ? 1 : null
  }
}

// Firewall rules (if not using private endpoint in dev/staging)
resource redisFirewallRule 'Microsoft.Cache/redis/firewallRules@2023-08-01' = [for (rule, index) in firewallRules: if (!empty(firewallRules)) {
  name: rule.name
  parent: redisCache
  properties: {
    startIP: rule.startIP
    endIP: rule.endIP
  }
}]

// DIAGNOSTIC SETTINGS
// -----------------------------------------------------------------------------

// Enable diagnostic logs for Redis cache (per audit-001)
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'redis-diagnostics'
  scope: redisCache
  properties: {
    logs: [
      {
        category: 'ConnectedClientList'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
  }
}

// OUTPUTS
// -----------------------------------------------------------------------------

@description('Redis cache resource ID')
output redisCacheId string = redisCache.id

@description('Redis cache name')
output redisCacheName string = redisCache.name

@description('Redis host name')
output redisHostName string = redisCache.properties.hostName

@description('Redis SSL port')
output redisSslPort int = redisCache.properties.sslPort

@description('Redis port (non-SSL)')
output redisPort int = redisCache.properties.port

// NOTE: Redis keys should be retrieved from Key Vault, not from outputs
// Keys are automatically stored in Key Vault by deployment pipeline
