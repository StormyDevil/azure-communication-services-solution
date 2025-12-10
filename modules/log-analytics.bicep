// ============================================================================
// Log Analytics Workspace Module
// Provides centralized logging and monitoring for ACS solution
// ============================================================================

@description('Name of the Log Analytics workspace')
param name string

@description('Azure region for the workspace')
param location string

@description('Resource tags')
param tags object

@description('Retention period in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('SKU for the workspace')
@allowed([
  'PerGB2018'
  'Free'
  'Standalone'
  'PerNode'
])
param sku string = 'PerGB2018'

// ============================================================================
// RESOURCES
// ============================================================================

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1 // Unlimited for production; set limit for dev
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('The resource ID of the Log Analytics workspace')
output workspaceId string = logAnalyticsWorkspace.id

@description('The name of the Log Analytics workspace')
output name string = logAnalyticsWorkspace.name

@description('The customer ID (workspace ID) for agent configuration')
output customerId string = logAnalyticsWorkspace.properties.customerId
