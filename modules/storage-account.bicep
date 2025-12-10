// ============================================================================
// Storage Account Module
// For call recordings, chat attachments, and other media storage
// ============================================================================

@description('Name of the Storage Account')
param name string

@description('Azure region for the storage account')
param location string

@description('Resource tags')
param tags object

@description('Storage account SKU')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_ZRS'
  'Standard_RAGRS'
  'Premium_LRS'
])
param sku string = 'Standard_LRS'

@description('Enable diagnostic logging')
param enableDiagnostics bool = true

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

// ============================================================================
// RESOURCES
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: sku
  }
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false // Use Azure AD auth only (security best practice)
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow' // Consider 'Deny' with private endpoints for production
    }
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Blob service for recordings storage
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Container for call recordings
resource recordingsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'call-recordings'
  properties: {
    publicAccess: 'None'
  }
}

// Container for chat attachments
resource chatAttachmentsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'chat-attachments'
  properties: {
    publicAccess: 'None'
  }
}

// Container for email attachments
resource emailAttachmentsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'email-attachments'
  properties: {
    publicAccess: 'None'
  }
}

// Diagnostic settings
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: 'diag-${name}'
  scope: storageAccount
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'Transaction'
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

@description('The resource ID of the Storage Account')
output resourceId string = storageAccount.id

@description('The name of the Storage Account')
output name string = storageAccount.name

@description('The primary blob endpoint')
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob

@description('The recordings container URL')
output recordingsContainerUrl string = '${storageAccount.properties.primaryEndpoints.blob}call-recordings'
