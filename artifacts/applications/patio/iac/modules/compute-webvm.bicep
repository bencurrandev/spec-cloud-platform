// =============================================================================
// Patio Application - Web Tier VM Module
// =============================================================================
// Purpose: Deploy Linux VMs for LAMP stack (Apache, PHP 8.1, MySQL client)
// Uses: AVM wrapper for Linux VM (avm-wrapper-linux-vm)
// Compliance: compute-001 v2.0.0, ac-001 (SSH keys only), dp-001 (encryption)
// =============================================================================

// PARAMETERS
// -----------------------------------------------------------------------------

@description('Environment name (dev, staging, prod)')
param environment string

@description('Azure region')
param location string

@description('VM name prefix')
param vmNamePrefix string

@description('VM count')
param vmCount int

@description('VM SKU (per compute-001 v2.0.0)')
param vmSize string

@description('Admin username')
param adminUsername string

@description('SSH public key for authentication (per ac-001: SSH keys only)')
@secure()
param sshPublicKey string

@description('Subnet ID for VMs')
param subnetId string

@description('Load balancer backend pool ID (optional)')
param loadBalancerBackendPoolId string = ''

@description('Common tags')
param tags object

@description('Custom script URI for LAMP stack installation')
param customScriptUri string = ''

@description('Key Vault URI for managed identity access')
param keyVaultUri string = ''

@description('Workload criticality tier')
param workloadCriticality string = 'non-critical'

// VARIABLES
// -----------------------------------------------------------------------------

// Determine environment tier for AVM wrapper (dev or prod only)
var avmEnvironment = environment == 'dev' ? 'dev' : 'prod'

// MODULES
// -----------------------------------------------------------------------------

// Deploy web tier VMs
@batchSize(1) // Deploy VMs sequentially to avoid resource contention
module webVMs '../../../../infrastructure/iac-modules/avm-wrapper-linux-vm/main.bicep' = [for i in range(0, vmCount): {
  name: 'vm-web-${environment}-${padLeft(i + 1, 3, '0')}-deployment'
  params: {
    vmName: '${vmNamePrefix}-${padLeft(i + 1, 3, '0')}'
    environment: avmEnvironment
    workloadCriticality: workloadCriticality
    location: location
    vmSize: vmSize
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    subnetId: subnetId
    osDiskSizeGB: 64
    osDiskType: environment == 'prod' ? 'Premium_LRS' : 'StandardSSD_LRS'
    enableDiskEncryption: environment == 'prod'
    additionalTags: union(tags, {
      Tier: 'web'
      Role: 'lamp-server'
      Instance: padLeft(i + 1, 3, '0')
    })
  }
}]

// Configure custom script extension for LAMP stack installation
resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = [for i in range(0, vmCount): if (!empty(customScriptUri)) {
  name: '${vmNamePrefix}-${padLeft(i + 1, 3, '0')}/install-lamp-stack'
  location: location
  dependsOn: [
    webVMs[i]
  ]
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        customScriptUri
      ]
    }
    protectedSettings: {
      commandToExecute: 'bash install-lamp-stack.sh ${environment}'
    }
  }
}]

// OUTPUTS
// -----------------------------------------------------------------------------

@description('VM resource IDs')
output vmIds array = [for i in range(0, vmCount): webVMs[i].outputs.vmId]

@description('VM names')
output vmNames array = [for i in range(0, vmCount): webVMs[i].outputs.vmName]

@description('Private IP addresses')
output privateIpAddresses array = [for i in range(0, vmCount): webVMs[i].outputs.privateIpAddress]

@description('Managed identity principal IDs (for RBAC assignments)')
output principalIds array = [for i in range(0, vmCount): webVMs[i].outputs.identityPrincipalId]
