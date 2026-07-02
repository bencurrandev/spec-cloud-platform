// =============================================================================
// Patio Application - Security Baseline Configuration
// =============================================================================
// Purpose: Centralized security controls, NSG rules, RBAC definitions
// Compliance: ac-001 (access control), dp-001 (data protection), audit-001 (logging)
// Version: 1.0.0
// =============================================================================

// PARAMETERS
// -----------------------------------------------------------------------------

@description('Environment name (dev, staging, prod)')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string

@description('VNet address prefix for calculating subnet CIDR blocks')
param vnetAddressPrefix string

@description('Web subnet address prefix')
param webSubnetPrefix string

@description('Database subnet address prefix')
param databaseSubnetPrefix string

@description('Cache subnet address prefix')
param cacheSubnetPrefix string

// NETWORK SECURITY GROUP RULES
// -----------------------------------------------------------------------------
// Per ac-001: Deny by default, allow explicitly, SSH keys only

// Web Tier NSG Rules
var webNsgSecurityRules = [
  {
    name: 'AllowHTTPSInbound'
    properties: {
      description: 'Allow HTTPS traffic from internet'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: webSubnetPrefix
      access: 'Allow'
      priority: 100
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowHTTPInbound'
    properties: {
      description: 'Allow HTTP traffic (will redirect to HTTPS)'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '80'
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: webSubnetPrefix
      access: 'Allow'
      priority: 110
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowSSHFromBastionOnly'
    properties: {
      description: 'Allow SSH only from Azure Bastion subnet (when deployed) or specific admin IPs'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '22'
      sourceAddressPrefix: 'AzureBastionSubnet' // Update with Bastion subnet or admin IP range
      destinationAddressPrefix: webSubnetPrefix
      access: 'Allow'
      priority: 120
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowLoadBalancerProbe'
    properties: {
      description: 'Allow Azure Load Balancer health probes'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: 'AzureLoadBalancer'
      destinationAddressPrefix: webSubnetPrefix
      access: 'Allow'
      priority: 130
      direction: 'Inbound'
    }
  }
  {
    name: 'DenyAllInbound'
    properties: {
      description: 'Deny all other inbound traffic (explicit deny)'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Deny'
      priority: 4096
      direction: 'Inbound'
    }
  }
  // Outbound rules
  {
    name: 'AllowMySQLOutbound'
    properties: {
      description: 'Allow outbound connections to MySQL database subnet'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '3306'
      sourceAddressPrefix: webSubnetPrefix
      destinationAddressPrefix: databaseSubnetPrefix
      access: 'Allow'
      priority: 100
      direction: 'Outbound'
    }
  }
  {
    name: 'AllowRedisOutbound'
    properties: {
      description: 'Allow outbound connections to Redis cache subnet'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '6379'
      sourceAddressPrefix: webSubnetPrefix
      destinationAddressPrefix: cacheSubnetPrefix
      access: 'Allow'
      priority: 110
      direction: 'Outbound'
    }
  }
  {
    name: 'AllowHTTPSOutbound'
    properties: {
      description: 'Allow outbound HTTPS for weather API, payment gateway, email service'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: webSubnetPrefix
      destinationAddressPrefix: 'Internet'
      access: 'Allow'
      priority: 120
      direction: 'Outbound'
    }
  }
  {
    name: 'AllowDNSOutbound'
    properties: {
      description: 'Allow DNS resolution'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '53'
      sourceAddressPrefix: webSubnetPrefix
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 130
      direction: 'Outbound'
    }
  }
  {
    name: 'AllowStorageOutbound'
    properties: {
      description: 'Allow outbound to Azure Storage (blob photos)'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: webSubnetPrefix
      destinationAddressPrefix: 'Storage'
      access: 'Allow'
      priority: 140
      direction: 'Outbound'
    }
  }
  {
    name: 'AllowKeyVaultOutbound'
    properties: {
      description: 'Allow outbound to Azure Key Vault for secrets'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: webSubnetPrefix
      destinationAddressPrefix: 'AzureKeyVault'
      access: 'Allow'
      priority: 150
      direction: 'Outbound'
    }
  }
  {
    name: 'AllowMonitorOutbound'
    properties: {
      description: 'Allow outbound to Azure Monitor for logging/metrics'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: webSubnetPrefix
      destinationAddressPrefix: 'AzureMonitor'
      access: 'Allow'
      priority: 160
      direction: 'Outbound'
    }
  }
]

// Database Tier NSG Rules
var databaseNsgSecurityRules = [
  {
    name: 'AllowMySQLFromWebSubnet'
    properties: {
      description: 'Allow MySQL connections from web subnet only'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '3306'
      sourceAddressPrefix: webSubnetPrefix
      destinationAddressPrefix: databaseSubnetPrefix
      access: 'Allow'
      priority: 100
      direction: 'Inbound'
    }
  }
  {
    name: 'DenyAllInbound'
    properties: {
      description: 'Deny all other inbound traffic to database'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Deny'
      priority: 4096
      direction: 'Inbound'
    }
  }
]

// Cache Tier NSG Rules
var cacheNsgSecurityRules = [
  {
    name: 'AllowRedisFromWebSubnet'
    properties: {
      description: 'Allow Redis connections from web subnet only'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '6379'
      sourceAddressPrefix: webSubnetPrefix
      destinationAddressPrefix: cacheSubnetPrefix
      access: 'Allow'
      priority: 100
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowRedisTLSFromWebSubnet'
    properties: {
      description: 'Allow Redis TLS connections from web subnet'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '6380'
      sourceAddressPrefix: webSubnetPrefix
      destinationAddressPrefix: cacheSubnetPrefix
      access: 'Allow'
      priority: 110
      direction: 'Inbound'
    }
  }
  {
    name: 'DenyAllInbound'
    properties: {
      description: 'Deny all other inbound traffic to cache'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Deny'
      priority: 4096
      direction: 'Inbound'
    }
  }
]

// RBAC ROLE DEFINITIONS
// -----------------------------------------------------------------------------
// Per ac-001: Role-based access control for application users

// Application RBAC roles (implemented in application code, documented here)
var applicationRoles = {
  customer: {
    name: 'Customer'
    description: 'Book patios, view bookings, manage profile'
    permissions: [
      'patio:search'
      'patio:view'
      'booking:create'
      'booking:view-own'
      'booking:cancel-own'
      'profile:update-own'
    ]
  }
  businessOwner: {
    name: 'Business Owner'
    description: 'Create/manage patios, configure pricing, view analytics'
    permissions: [
      'patio:create'
      'patio:update-own'
      'patio:delete-own'
      'pricing:configure'
      'booking:view-for-own-patios'
      'analytics:view-own'
    ]
    requireMfa: true // Per ac-001: MFA required for business owners
  }
  admin: {
    name: 'Administrator'
    description: 'Manage users, moderate content, system configuration'
    permissions: [
      'user:manage'
      'patio:moderate'
      'booking:view-all'
      'system:configure'
      'analytics:view-all'
    ]
    requireMfa: true // Per ac-001: MFA required for admins
  }
}

// Azure RBAC role assignments for infrastructure
var infrastructureRoles = {
  // VM Managed Identity → Key Vault
  keyVaultSecretsUser: {
    roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
    description: 'Allow VMs to read secrets from Key Vault via managed identity'
  }
  
  // VM Managed Identity → Storage Account
  storageBlobDataContributor: {
    roleDefinitionId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
    description: 'Allow VMs to read/write blobs (patio photos) via managed identity'
  }
  
  // Monitoring identity → Log Analytics
  monitoringMetricsPublisher: {
    roleDefinitionId: '3913510d-42f4-4e42-8a64-420c390055eb' // Monitoring Metrics Publisher
    description: 'Allow publishing custom metrics to Azure Monitor'
  }
}

// SSH KEY CONFIGURATION
// -----------------------------------------------------------------------------
// Per ac-001: SSH keys only, no password authentication

var sshConfig = {
  disablePasswordAuthentication: true // REQUIRED: No password auth allowed
  requireSshKeys: true
  sshKeyComment: 'Patio application infrastructure access key'
}

// ENCRYPTION CONFIGURATION
// -----------------------------------------------------------------------------
// Per dp-001 v1.0.0: AES-256 at rest, TLS 1.2+ in transit

var encryptionStandards = {
  // Disk encryption for VMs
  vmDiskEncryption: {
    enabled: true
    encryptionAlgorithm: 'AES-256' // Per dp-001
    encryptionAtHostEnabled: false // Not required for non-critical tier (cost optimization)
  }
  
  // Storage encryption
  storageEncryption: {
    requireInfrastructureEncryption: environment == 'prod' ? true : false
    enabled: true
    keyType: 'Microsoft.Storage' // Microsoft-managed keys
  }
  
  // TLS requirements
  tlsConfig: {
    minimumVersion: '1.2' // Per dp-001: TLS 1.2 minimum
    allowedProtocols: ['1.2', '1.3']
  }
  
  // MySQL encryption
  mysqlEncryption: {
    sslEnforcement: 'Enabled'
    minimalTlsVersion: 'TLS1_2'
  }
  
  // Redis encryption
  redisEncryption: {
    enableNonSslPort: false // Disabled: force encrypted connections
    minimumTlsVersion: '1.2'
  }
}

// AUDIT LOGGING CONFIGURATION
// -----------------------------------------------------------------------------
// Per audit-001: 90-day log retention, centralized logging

var auditConfig = {
  // Log categories to enable
  enabledLogs: [
    'Administrative' // All administrative operations (create, update, delete)
    'Security' // Security-related events (authentication, authorization)
    'ServiceHealth' // Service health events
    'Alert' // Alerts and incidents
  ]
  
  // Retention policy
  logRetentionDays: 90 // Per audit-001
  
  // Diagnostic settings categories
  diagnosticCategories: {
    logs: [
      'Administrative'
      'Security'
      'ServiceHealth'
      'Alert'
      'Policy'
    ]
    metrics: [
      'AllMetrics'
    ]
  }
  
  // Events to audit in application
  applicationAuditEvents: [
    'user.login'
    'user.logout'
    'user.login.failed'
    'user.password.reset'
    'booking.created'
    'booking.modified'
    'booking.cancelled'
    'patio.created'
    'patio.updated'
    'patio.deleted'
    'pricing.updated'
    'admin.action'
  ]
}

// KEY VAULT SECRETS CONFIGURATION
// -----------------------------------------------------------------------------
// Per dp-001: Centralized secret management

var keyVaultSecrets = {
  // Secrets to be created (values injected via pipeline, not hardcoded)
  secretNames: [
    'mysql-admin-password'
    'mysql-connection-string'
    'redis-primary-key'
    'redis-connection-string'
    'weather-api-key'
    'payment-gateway-key'
    'sendgrid-api-key'
    'app-secret-key'
    'session-encryption-key'
  ]
  
  // Secret rotation policy
  rotationPolicy: {
    rotationIntervalDays: 90 // Rotate secrets every 90 days
    expirationNoticeDays: 30 // Alert 30 days before expiration
  }
  
  // Access policies
  enableRbac: true // Use RBAC instead of access policies (per ac-001)
  enableSoftDelete: true
  softDeleteRetentionDays: 90
  enablePurgeProtection: environment == 'prod' ? true : false // Production only
}

// OUTPUTS
// -----------------------------------------------------------------------------
// Export all security configurations for use in other modules

output webNsgSecurityRules array = webNsgSecurityRules
output databaseNsgSecurityRules array = databaseNsgSecurityRules
output cacheNsgSecurityRules array = cacheNsgSecurityRules
output applicationRoles object = applicationRoles
output infrastructureRoles object = infrastructureRoles
output sshConfig object = sshConfig
output encryptionStandards object = encryptionStandards
output auditConfig object = auditConfig
output keyVaultSecrets object = keyVaultSecrets
