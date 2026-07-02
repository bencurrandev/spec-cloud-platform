// =============================================================================
// Patio Application - Key Vault Secrets Initialization
// =============================================================================
// Purpose: Initialize placeholder secrets in Key Vault
// Note: Replace placeholder values with actual secrets before production deployment
// Compliance: dp-001 (encryption), sec-001 (secret management)
// =============================================================================

// PARAMETERS
// -----------------------------------------------------------------------------

@description('Key Vault name')
param keyVaultName string

@description('MySQL administrator password')
@secure()
param mysqlAdminPassword string

@description('Laravel/Symfony application key (32 characters base64)')
@secure()
param appKey string

@description('Redis connection string')
@secure()
param redisConnectionString string

@description('Weather API key (e.g., OpenWeatherMap)')
@secure()
param weatherApiKey string

@description('Payment gateway API key (placeholder)')
@secure()
param paymentGatewayApiKey string

@description('SMTP password for email notifications')
@secure()
param smtpPassword string

// RESOURCES
// -----------------------------------------------------------------------------

// Reference existing Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

// MySQL administrator password
resource mysqlAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: 'mysql-admin-password'
  parent: keyVault
  properties: {
    value: mysqlAdminPassword
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Application encryption key (Laravel APP_KEY or Symfony APP_SECRET)
resource appKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: 'app-key'
  parent: keyVault
  properties: {
    value: appKey
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Redis connection string (includes password)
resource redisConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: 'redis-connection-string'
  parent: keyVault
  properties: {
    value: redisConnectionString
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Weather API key (OpenWeatherMap or similar)
resource weatherApiKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: 'weather-api-key'
  parent: keyVault
  properties: {
    value: weatherApiKey
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Payment gateway API key (Stripe, PayPal, etc.)
resource paymentGatewayApiKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: 'payment-gateway-api-key'
  parent: keyVault
  properties: {
    value: paymentGatewayApiKey
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// SMTP password for email notifications
resource smtpPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: 'smtp-password'
  parent: keyVault
  properties: {
    value: smtpPassword
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// JWT signing key for API authentication
resource jwtSigningKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: 'jwt-signing-key'
  parent: keyVault
  properties: {
    value: uniqueString(resourceGroup().id, 'jwt-signing-key') // Generate unique key
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// MySQL connection string (without password - password retrieved separately)
resource mysqlConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: 'mysql-connection-string'
  parent: keyVault
  properties: {
    value: 'placeholder-will-be-set-after-mysql-deployment'
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Storage account connection string for photo uploads
resource storagePhotosConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: 'storage-photos-connection-string'
  parent: keyVault
  properties: {
    value: 'placeholder-will-be-set-after-storage-deployment'
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Storage account connection string for logs
resource storageLogsConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: 'storage-logs-connection-string'
  parent: keyVault
  properties: {
    value: 'placeholder-will-be-set-after-storage-deployment'
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// OUTPUTS
// -----------------------------------------------------------------------------

@description('List of secret names created')
output secretNames array = [
  'mysql-admin-password'
  'app-key'
  'redis-connection-string'
  'weather-api-key'
  'payment-gateway-api-key'
  'smtp-password'
  'jwt-signing-key'
  'mysql-connection-string'
  'storage-photos-connection-string'
  'storage-logs-connection-string'
]

@description('Number of secrets created')
output secretCount int = 10
