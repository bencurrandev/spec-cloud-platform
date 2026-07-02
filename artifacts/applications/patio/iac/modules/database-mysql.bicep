// =============================================================================
// Patio Application - MySQL Flexible Server Module
// =============================================================================
// Purpose: Deploy Azure Database for MySQL Flexible Server
// Uses: AVM wrapper for MySQL Flexible Server (avm-wrapper-mysql-flexibleserver)
// Compliance: dp-001 (encryption), stor-001 (backups), comp-001 (data residency)
// =============================================================================

// PARAMETERS
// -----------------------------------------------------------------------------

@description('Environment name (dev, staging, prod)')
param environment string

@description('Azure region (US regions only per comp-001)')
param location string

@description('MySQL server name')
param serverName string

@description('MySQL administrator username')
param administratorLogin string

@description('MySQL administrator password (from Key Vault)')
@secure()
param administratorLoginPassword string

@description('MySQL SKU name (e.g., B1ms, D2ds_v4)')
param skuName string

@description('MySQL SKU tier (e.g., Burstable, GeneralPurpose)')
param skuTier string

@description('Storage size in GB')
param storageSizeGB int

@description('Backup retention days')
param backupRetentionDays int

@description('MySQL version')
param mysqlVersion string = '8.0.21'

@description('Subnet ID for private endpoint')
param subnetId string

@description('Private DNS zone resource ID for MySQL')
param privateDnsZoneId string = ''

@description('Common tags')
param tags object

@description('Enable storage auto-grow')
param storageAutoGrow bool = false

// VARIABLES
// -----------------------------------------------------------------------------

// Database name for Patio application
var databaseName = 'patiodb'

// Determine environment tier for AVM wrapper (dev or prod only)
var avmEnvironment = environment == 'dev' ? 'dev' : 'prod'

// Map skuName and skuTier to AVM-compatible SKU (only two allowed values)
// If skuTier is Burstable, use Burstable_B1ms, otherwise use GeneralPurpose_D2ds_v4
var sku = (skuTier == 'Burstable') ? 'Burstable_B1ms' : 'GeneralPurpose_D2ds_v4'

// MODULES
// -----------------------------------------------------------------------------

// Deploy MySQL Flexible Server using AVM wrapper
module mysqlServer '../../../../infrastructure/iac-modules/avm-wrapper-mysql-flexibleserver/main.bicep' = {
  name: 'mysql-${environment}-deployment'
  params: {
    serverName: serverName
    environment: avmEnvironment
    location: location
    sku: sku
    administratorLogin: administratorLogin
    administratorPassword: administratorLoginPassword
    delegatedSubnetId: subnetId
    privateDnsZoneId: privateDnsZoneId
    storageSizeGB: storageSizeGB
    storageIops: 360
    storageAutogrow: storageAutoGrow
    backupRetentionDays: backupRetentionDays
    geoRedundantBackup: false
    highAvailability: false
    mysqlVersion: mysqlVersion
    additionalTags: union(tags, {
      Tier: 'database'
      Purpose: 'application-database'
      DataClassification: environment == 'prod' ? 'customer-data' : 'test-data'
    })
  }
}

// Create Patio database
resource patioDatabase 'Microsoft.DBforMySQL/flexibleServers/databases@2024-12-30' = {
  name: '${serverName}/${databaseName}'
  dependsOn: [
    mysqlServer
  ]
  properties: {
    charset: 'utf8mb4'
    collation: 'utf8mb4_unicode_ci'
  }
}

// Configure server parameters for optimization
resource serverParameters 'Microsoft.DBforMySQL/flexibleServers/configurations@2024-12-30' = {
  name: '${serverName}/max_connections'
  dependsOn: [
    mysqlServer
  ]
  properties: {
    value: '100' // Limit connections for cost control
    source: 'user-override'
  }
}

// OUTPUTS
// -----------------------------------------------------------------------------

@description('MySQL server resource ID')
output serverId string = mysqlServer.outputs.serverId

@description('MySQL server FQDN')
output serverFqdn string = mysqlServer.outputs.fqdn

@description('MySQL server name')
output serverName string = mysqlServer.outputs.serverName

@description('Database name')
output databaseName string = databaseName

@description('Administrator username')
output administratorLogin string = administratorLogin

@description('Connection string (without password)')
output connectionString string = 'Server=${mysqlServer.outputs.fqdn};Database=${databaseName};Uid=${administratorLogin};SslMode=Required;'
