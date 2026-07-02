// =============================================================================
// Patio Application - Main Infrastructure Orchestration
// =============================================================================
// Purpose: Orchestrate all infrastructure modules for Patio application
// Description: Deploys VNet, compute, database, storage, security, and cache
// Compliance: All 21 upstream specifications
// =============================================================================

targetScope = 'resourceGroup'

// PARAMETERS
// -----------------------------------------------------------------------------

@description('Environment name (dev, staging, prod)')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string

@description('Azure region for deployment (US regions only per comp-001, limited to centralus or eastus for AVM compatibility)')
@allowed([
  'eastus'
  'centralus'
])
param location string = 'eastus'

@description('Workload criticality tier per cost-001')
@allowed([
  'non-critical'
  'moderate'
  'critical'
])
param workloadCriticality string = 'non-critical'

@description('Administrator email for notifications')
param adminEmail string

@description('MySQL administrator username')
param mysqlAdminUsername string = 'patioAdmin'

@description('MySQL administrator password (secure parameter)')
@secure()
param mysqlAdminPassword string

@description('Number of web VMs to deploy')
@minValue(1)
@maxValue(3)
param webVmCount int

@description('VM SKU size')
param vmSize string

@description('MySQL SKU name')
param mysqlSkuName string

@description('MySQL SKU tier')
param mysqlSkuTier string

@description('Redis SKU name')
param redisSku string

@description('Redis SKU family')
param redisSkuFamily string

@description('Redis capacity')
param redisCapacity int

@description('SSH public key for VM access')
param sshPublicKey string

@description('Tenant ID for Key Vault RBAC')
param tenantId string = subscription().tenantId

@description('Object IDs for Key Vault administrators')
param keyVaultAdminObjectIds array = []

// VARIABLES (from shared-variables module)
// -----------------------------------------------------------------------------

module sharedVars './shared-variables.bicep' = {
  name: 'shared-variables'
  params: {
    environment: environment
    location: location
    workloadCriticality: workloadCriticality
  }
}

// Common tags
var tags = sharedVars.outputs.commonTags

// Resource names
var vnetName = sharedVars.outputs.resourceNames.vnet
var nsgWebName = sharedVars.outputs.resourceNames.nsgWeb
var nsgDatabaseName = sharedVars.outputs.resourceNames.nsgDatabase
var nsgCacheName = sharedVars.outputs.resourceNames.nsgCache
var publicIpName = sharedVars.outputs.resourceNames.publicIp
var loadBalancerName = sharedVars.outputs.resourceNames.loadBalancer
var mysqlServerName = sharedVars.outputs.resourceNames.mysqlServer
var storagePhotosName = sharedVars.outputs.resourceNames.storagePhotos
var storageLogsName = sharedVars.outputs.resourceNames.storageLogs
var keyVaultName = sharedVars.outputs.resourceNames.keyVault
var redisCacheName = sharedVars.outputs.resourceNames.redis

// Network configuration
var vnetAddressPrefix = sharedVars.outputs.networkConfig.vnetAddressPrefix
var subnetWebAddressPrefix = sharedVars.outputs.networkConfig.subnets.web.addressPrefix
var subnetDatabaseAddressPrefix = sharedVars.outputs.networkConfig.subnets.database.addressPrefix
var subnetCacheAddressPrefix = sharedVars.outputs.networkConfig.subnets.cache.addressPrefix

// =============================================================================
// PHASE 1: NETWORKING
// =============================================================================

// Deploy Virtual Network with 3 subnets
module vnet './modules/network-vnet.bicep' = {
  name: 'vnet-deployment'
  params: {
    vnetName: vnetName
    location: location
    workloadCriticality: workloadCriticality
    environment: environment
    addressPrefix: vnetAddressPrefix
    subnetWebAddressPrefix: subnetWebAddressPrefix
    subnetDatabaseAddressPrefix: subnetDatabaseAddressPrefix
    subnetCacheAddressPrefix: subnetCacheAddressPrefix
    tags: tags
  }
}

// Deploy Network Security Groups
module nsgs './modules/network-nsg.bicep' = {
  name: 'nsg-deployment'
  params: {
    environment: environment
    location: location
    nsgNames: {
      web: nsgWebName
      database: nsgDatabaseName
      cache: nsgCacheName
    }
    webNsgRules: []  // Placeholder - should come from security baseline
    databaseNsgRules: []  // Placeholder - should come from security baseline
    cacheNsgRules: []  // Placeholder - should come from security baseline
    tags: tags
  }
}

// Deploy Public IP for Load Balancer
module publicIp './modules/network-publicip.bicep' = {
  name: 'publicip-deployment'
  params: {
    publicIpName: publicIpName
    location: location
    environment: environment
    tags: tags
  }
}

// Deploy Standard Load Balancer
module loadBalancer './modules/network-loadbalancer.bicep' = {
  name: 'loadbalancer-deployment'
  params: {
    environment: environment
    loadBalancerName: loadBalancerName
    location: location
    publicIpId: publicIp.outputs.publicIpId
    tags: tags
  }
}

// =============================================================================
// PHASE 2: SECURITY & SECRETS
// =============================================================================

// Deploy Key Vault (must be deployed before VMs to provide secrets)
module keyVault './modules/security-keyvault.bicep' = {
  name: 'keyvault-deployment'
  params: {
    environment: environment
    location: location
    keyVaultName: keyVaultName
    tenantId: tenantId
    tags: tags
    enablePurgeProtection: environment == 'prod'
    administratorObjectIds: keyVaultAdminObjectIds
  }
}

// Initialize Key Vault secrets (placeholder values)
module secrets './modules/security-secrets.bicep' = {
  name: 'secrets-deployment'
  dependsOn: [
    keyVault
  ]
  params: {
    keyVaultName: keyVaultName
    mysqlAdminPassword: mysqlAdminPassword
    appKey: uniqueString(resourceGroup().id, 'app-key') // Generate unique app key
    redisConnectionString: 'placeholder-updated-after-redis-deployment'
    weatherApiKey: 'placeholder-set-manually-after-deployment'
    paymentGatewayApiKey: 'placeholder-set-manually-after-deployment'
    smtpPassword: 'placeholder-set-manually-after-deployment'
  }
}

// =============================================================================
// PHASE 3: STORAGE
// =============================================================================

// Deploy Storage Account for patio photos
module storagePhotos './modules/storage-photos.bicep' = {
  name: 'storage-photos-deployment'
  params: {
    environment: environment
    location: location
    storageAccountName: storagePhotosName
    tags: tags
    enableVersioning: environment == 'prod'
  }
}

// Deploy Storage Account for application logs
module storageLogs './modules/storage-logs.bicep' = {
  name: 'storage-logs-deployment'
  params: {
    environment: environment
    location: location
    storageAccountName: storageLogsName
    tags: tags
    logRetentionDays: 90 // Per audit-001
  }
}

// =============================================================================
// PHASE 4: DATABASE
// =============================================================================

// Deploy MySQL Flexible Server
module mysql './modules/database-mysql.bicep' = {
  name: 'mysql-deployment'
  dependsOn: [
    vnet
    nsgs
  ]
  params: {
    environment: environment
    location: location
    serverName: mysqlServerName
    administratorLogin: mysqlAdminUsername
    administratorLoginPassword: mysqlAdminPassword
    skuName: mysqlSkuName
    skuTier: mysqlSkuTier
    storageSizeGB: environment == 'prod' ? 64 : 32
    backupRetentionDays: 7
    subnetId: vnet.outputs.subnetDatabaseId
    privateDnsZoneId: '' // TODO: Create private DNS zone for mysql.database.azure.com
    tags: tags
  }
}

// =============================================================================
// PHASE 5: CACHE
// =============================================================================

// Deploy Redis Cache
module redis './modules/cache-redis.bicep' = {
  name: 'redis-deployment'
  dependsOn: [
    vnet
  ]
  params: {
    environment: environment
    location: location
    redisCacheName: redisCacheName
    redisSku: redisSku
    redisSkuFamily: redisSkuFamily
    redisCapacity: redisCapacity
    tags: tags
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    subnetId: redisSku == 'Premium' ? vnet.outputs.subnetCacheId : ''
  }
}

// =============================================================================
// PHASE 6: COMPUTE
// =============================================================================

// Deploy Web VMs (LAMP stack)
module webVms './modules/compute-webvm.bicep' = {
  name: 'webvm-deployment'
  dependsOn: [
    vnet
    nsgs
    loadBalancer
    keyVault
    mysql
    redis
    storagePhotos
    storageLogs
  ]
  params: {
    environment: environment
    location: location
    vmNamePrefix: 'vm-${environment}-web'
    vmCount: webVmCount
    vmSize: vmSize
    adminUsername: 'azureuser'
    sshPublicKey: sshPublicKey
    subnetId: vnet.outputs.subnetWebId
    loadBalancerBackendPoolId: loadBalancer.outputs.backendPoolId
    customScriptUri: '' // Set this to blob storage URL hosting install-lamp-stack.sh
    keyVaultUri: keyVault.outputs.keyVaultUri
    workloadCriticality: workloadCriticality
    tags: tags
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

@description('Load balancer public IP address')
output loadBalancerPublicIp string = publicIp.outputs.publicIpAddress

@description('Load balancer FQDN')
output loadBalancerFqdn string = publicIp.outputs.fqdn

@description('MySQL server FQDN')
output mysqlServerFqdn string = mysql.outputs.serverFqdn

@description('MySQL database name')
output mysqlDatabaseName string = mysql.outputs.databaseName

@description('Redis host name')
output redisHostName string = redis.outputs.redisHostName

@description('Redis connection string (use Key Vault for password)')
output redisConnectionInfo string = '${redis.outputs.redisHostName}:${redis.outputs.redisSslPort}'

@description('Key Vault name')
output keyVaultName string = keyVault.outputs.keyVaultName

@description('Key Vault URI')
output keyVaultUri string = keyVault.outputs.keyVaultUri

@description('Storage account name (photos)')
output storagePhotosName string = storagePhotos.outputs.storageAccountName

@description('Storage account name (logs)')
output storageLogsName string = storageLogs.outputs.storageAccountName

@description('Photo container name')
output photoContainerName string = storagePhotos.outputs.photoContainerName

@description('Application logs container name')
output applicationLogsContainer string = storageLogs.outputs.applicationLogsContainer

@description('VNet resource ID')
output vnetId string = vnet.outputs.vnetId

@description('Web subnet ID')
output webSubnetId string = vnet.outputs.subnetWebId

@description('Database subnet ID')
output databaseSubnetId string = vnet.outputs.subnetDatabaseId

@description('Cache subnet ID')
output cacheSubnetId string = vnet.outputs.subnetCacheId

@description('Number of web VMs deployed')
output webVmCount int = webVmCount

@description('Environment name')
output deployedEnvironment string = environment

@description('Deployment timestamp')
output deploymentTimestamp string = 'See deployment metadata for timestamp'

@description('Next steps')
output nextSteps string = '''
1. Update Key Vault secrets with actual values:
   - weather-api-key (OpenWeatherMap or similar)
   - payment-gateway-api-key (Stripe/PayPal)
   - smtp-password (for email notifications)

2. Initialize database schema:
   mysql -h ${mysql.outputs.serverFqdn} -u ${mysqlAdminUsername} -p patiodb < scripts/init-database.sql

3. Deploy application code to web VMs via SSH or CI/CD pipeline

4. Configure DNS to point to: ${publicIp.outputs.publicIpAddress}

5. Install SSL certificate (Let's Encrypt recommended)

6. Test application health endpoint: https://${publicIp.outputs.publicIpAddress}/health
'''
