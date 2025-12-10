// ============================================================================
// Key Vault Module
// Securely stores ACS connection strings and secrets
// ============================================================================

@description('Name of the Key Vault')
param name string

@description('Azure region for the Key Vault')
param location string

@description('Resource tags')
param tags object

@description('Enable diagnostic logging')
param enableDiagnostics bool = true

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

@description('SKU for Key Vault')
@allowed([
  'standard'
  'premium'
])
param sku string = 'standard'

@description('Enable soft delete (recommended for production)')
param enableSoftDelete bool = true

@description('Soft delete retention in days')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@description('Enable purge protection (recommended for production)')
param enablePurgeProtection bool = true

// ============================================================================
// RESOURCES
// ============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: sku
    }
    tenantId: subscription().tenantId
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection ? true : null
    enableRbacAuthorization: true // Use RBAC instead of access policies (WAF best practice)
    publicNetworkAccess: 'Enabled' // Consider 'Disabled' with Private Endpoints for production
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow' // Consider 'Deny' with specific IP rules for production
    }
  }
}

// Diagnostic settings for auditing and monitoring
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: 'diag-${name}'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('The resource ID of the Key Vault')
output resourceId string = keyVault.id

@description('The name of the Key Vault')
output name string = keyVault.name

@description('The URI of the Key Vault')
output uri string = keyVault.properties.vaultUri
