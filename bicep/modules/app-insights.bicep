// ============================================================================
// Application Insights Module
// Enhanced monitoring for ACS applications
// ============================================================================

@description('Name of the Application Insights resource')
param name string

@description('Azure region for Application Insights')
param location string

@description('Resource tags')
param tags object

@description('Log Analytics workspace ID for backing store')
param logAnalyticsWorkspaceId string

@description('Application type')
@allowed([
  'web'
  'other'
])
param applicationType string = 'web'

// ============================================================================
// RESOURCES
// ============================================================================

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: applicationType
  properties: {
    Application_Type: applicationType
    WorkspaceResourceId: logAnalyticsWorkspaceId
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
    RetentionInDays: 90
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('The resource ID of Application Insights')
output resourceId string = appInsights.id

@description('The name of Application Insights')
output name string = appInsights.name

@description('The instrumentation key for Application Insights')
output instrumentationKey string = appInsights.properties.InstrumentationKey

@description('The connection string for Application Insights')
output connectionString string = appInsights.properties.ConnectionString
