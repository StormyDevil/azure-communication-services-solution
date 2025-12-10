// ============================================================================
// Azure Communication Services Module
// Core communication platform for voice, video, SMS, chat, and email
// ============================================================================

@description('Name of the Communication Services resource')
param name string

@description('Data location for data residency compliance')
@allowed([
  'Europe'
  'Germany'
  'United States'
  'UK'
  'France'
  'Switzerland'
  'Norway'
  'Australia'
  'Japan'
  'Brazil'
  'Canada'
  'India'
  'Korea'
  'Singapore'
  'South Africa'
  'UAE'
])
param dataLocation string

@description('Resource tags')
param tags object

@description('Enable diagnostic logging')
param enableDiagnostics bool = true

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

// ============================================================================
// RESOURCES
// ============================================================================

// Azure Communication Services resource
// Note: Location is always 'global' for ACS; dataLocation controls data residency
resource communicationServices 'Microsoft.Communication/communicationServices@2023-04-01' = {
  name: name
  location: 'global'
  tags: tags
  properties: {
    dataLocation: dataLocation
  }
}

// Diagnostic settings for monitoring and troubleshooting
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: 'diag-${name}'
  scope: communicationServices
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

@description('The resource ID of the Communication Services')
output resourceId string = communicationServices.id

@description('The name of the Communication Services')
output name string = communicationServices.name

@description('The endpoint of the Communication Services')
output endpoint string = 'https://${communicationServices.name}.communication.azure.com'

#disable-next-line outputs-should-not-contain-secrets
@description('The connection string for the Communication Services (stored in Key Vault)')
output connectionString string = communicationServices.listKeys().primaryConnectionString

@description('The data location of the Communication Services')
output dataLocation string = communicationServices.properties.dataLocation
