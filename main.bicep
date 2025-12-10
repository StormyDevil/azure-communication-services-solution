// ============================================================================
// Azure Communication Services Solution
// Aligned with Cloud Adoption Framework, Well-Architected Framework, and
// Azure Landing Zone principles
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// PARAMETERS
// ============================================================================

@description('The base name for all resources. Used to generate unique names.')
@minLength(3)
@maxLength(20)
param baseName string = 'acssoln'

@description('Environment name (dev, staging, prod)')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string = 'dev'

@description('Azure region for resources. ACS is a global service but data residency matters.')
@allowed([
  'swedencentral'
  'germanywestcentral'
  'northeurope'
  'westeurope'
])
param location string = 'swedencentral'

@description('Data location for ACS data residency compliance')
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
param dataLocation string = 'Europe'

@description('Enable email capabilities')
param enableEmail bool = true

@description('Enable SMS capabilities (requires phone number provisioning separately)')
param enableSms bool = true

@description('Enable diagnostic logging')
param enableDiagnostics bool = true

@description('Enable Event Grid for webhooks and event handling')
param enableEventGrid bool = true

@description('Enable Application Insights for application monitoring')
param enableAppInsights bool = true

@description('Enable storage account for recordings and attachments')
param enableStorage bool = true

@description('Webhook endpoint URL for Event Grid events (optional)')
param eventWebhookEndpoint string = ''

@description('Resource owner for cost allocation')
param owner string = 'Partner Solutions Team'

@description('Cost center for billing allocation')
param costCenter string = 'IT-Communications'

// ============================================================================
// VARIABLES
// ============================================================================

// Unique suffix for globally unique resource names
var uniqueSuffix = uniqueString(resourceGroup().id)

// Resource naming following Azure naming conventions
var acsName = 'acs-${baseName}-${environment}-${take(uniqueSuffix, 6)}'
var emailServiceName = 'email-${baseName}-${environment}-${take(uniqueSuffix, 6)}'
var logAnalyticsName = 'log-${baseName}-${environment}-${take(uniqueSuffix, 6)}'
var keyVaultName = 'kv-${take(baseName, 6)}-${take(environment, 3)}-${take(uniqueSuffix, 6)}'
var eventGridName = 'evgt-${baseName}-${environment}-${take(uniqueSuffix, 6)}'
var appInsightsName = 'appi-${baseName}-${environment}-${take(uniqueSuffix, 6)}'
var storageAccountName = 'st${take(replace(baseName, '-', ''), 10)}${take(environment, 3)}${take(uniqueSuffix, 6)}'

// Standard tags for governance and cost management (CAF best practice)
var resourceTags = {
  Environment: environment
  ManagedBy: 'Bicep'
  Project: 'ACS-Solution'
  Owner: owner
  CostCenter: costCenter
  DataClassification: 'Confidential'
}

// ============================================================================
// MODULES
// ============================================================================

// Deploy Log Analytics Workspace for centralized monitoring
module logAnalytics 'modules/log-analytics.bicep' = if (enableDiagnostics) {
  name: 'deploy-log-analytics'
  params: {
    name: logAnalyticsName
    location: location
    tags: resourceTags
  }
}

// Deploy Key Vault for secure secret storage
module keyVault 'modules/key-vault.bicep' = {
  name: 'deploy-key-vault'
  params: {
    name: keyVaultName
    location: location
    tags: resourceTags
    enableDiagnostics: enableDiagnostics
    logAnalyticsWorkspaceId: enableDiagnostics ? logAnalytics.outputs.workspaceId : ''
  }
}

// Deploy Azure Communication Services
module communicationServices 'modules/communication-services.bicep' = {
  name: 'deploy-communication-services'
  params: {
    name: acsName
    dataLocation: dataLocation
    tags: resourceTags
    enableDiagnostics: enableDiagnostics
    logAnalyticsWorkspaceId: enableDiagnostics ? logAnalytics.outputs.workspaceId : ''
  }
}

// Deploy Email Service (if enabled)
module emailService 'modules/email-service.bicep' = if (enableEmail) {
  name: 'deploy-email-service'
  params: {
    name: emailServiceName
    dataLocation: dataLocation
    tags: resourceTags
    communicationServicesName: communicationServices.outputs.name
  }
}

// Store connection string in Key Vault
module storeSecrets 'modules/store-secrets.bicep' = {
  name: 'store-secrets'
  params: {
    keyVaultName: keyVaultName
    acsConnectionString: communicationServices.outputs.connectionString
    acsEndpoint: communicationServices.outputs.endpoint
  }
  dependsOn: [
    keyVault
    communicationServices
  ]
}

// Deploy Event Grid for ACS events (webhooks, delivery reports)
module eventGrid 'modules/event-grid.bicep' = if (enableEventGrid) {
  name: 'deploy-event-grid'
  params: {
    name: eventGridName
    location: location
    tags: resourceTags
    communicationServicesId: communicationServices.outputs.resourceId
    communicationServicesName: communicationServices.outputs.name
    enableDiagnostics: enableDiagnostics
    logAnalyticsWorkspaceId: enableDiagnostics ? logAnalytics.outputs.workspaceId : ''
    webhookEndpoint: eventWebhookEndpoint
  }
}

// Deploy Application Insights for application monitoring
module appInsights 'modules/app-insights.bicep' = if (enableAppInsights && enableDiagnostics) {
  name: 'deploy-app-insights'
  params: {
    name: appInsightsName
    location: location
    tags: resourceTags
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

// Deploy Storage Account for recordings and attachments
module storageAccount 'modules/storage-account.bicep' = if (enableStorage) {
  name: 'deploy-storage-account'
  params: {
    name: storageAccountName
    location: location
    tags: resourceTags
    enableDiagnostics: enableDiagnostics
    logAnalyticsWorkspaceId: enableDiagnostics ? logAnalytics.outputs.workspaceId : ''
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('The name of the Communication Services resource')
output communicationServicesName string = communicationServices.outputs.name

@description('The endpoint of the Communication Services resource')
output communicationServicesEndpoint string = communicationServices.outputs.endpoint

@description('The resource ID of the Communication Services resource')
output communicationServicesResourceId string = communicationServices.outputs.resourceId

@description('The name of the Email Service (if deployed)')
output emailServiceName string = enableEmail ? emailService.outputs.name : 'Not deployed'

@description('The email domain (if deployed)')
output emailDomain string = enableEmail ? emailService.outputs.domainName : 'Not deployed'

@description('The Key Vault name where secrets are stored')
output keyVaultName string = keyVault.outputs.name

@description('The Key Vault URI')
output keyVaultUri string = keyVault.outputs.uri

@description('The Log Analytics workspace ID (if diagnostics enabled)')
output logAnalyticsWorkspaceId string = enableDiagnostics ? logAnalytics.outputs.workspaceId : 'Not deployed'

@description('The Event Grid topic name (if deployed)')
output eventGridTopicName string = enableEventGrid ? eventGrid.outputs.name : 'Not deployed'

@description('The Application Insights name (if deployed)')
output appInsightsName string = (enableAppInsights && enableDiagnostics) ? appInsights.outputs.name : 'Not deployed'

@description('The Storage Account name (if deployed)')
output storageAccountName string = enableStorage ? storageAccount.outputs.name : 'Not deployed'

@description('Resource group name')
output resourceGroupName string = resourceGroup().name

@description('Deployment summary')
output deploymentSummary object = {
  communicationServices: {
    name: communicationServices.outputs.name
    endpoint: communicationServices.outputs.endpoint
    dataLocation: dataLocation
    capabilities: {
      sms: enableSms
      email: enableEmail
      voiceVideo: true
      chat: true
    }
  }
  eventProcessing: {
    eventGridEnabled: enableEventGrid
    eventGridTopic: enableEventGrid ? eventGridName : 'Not deployed'
    webhookEndpoint: !empty(eventWebhookEndpoint) ? 'Configured' : 'Not configured'
  }
  storage: {
    enabled: enableStorage
    accountName: enableStorage ? storageAccountName : 'Not deployed'
    containers: enableStorage ? [
      'call-recordings'
      'chat-attachments'
      'email-attachments'
    ] : []
  }
  monitoring: {
    diagnosticsEnabled: enableDiagnostics
    logAnalyticsWorkspace: enableDiagnostics ? logAnalyticsName : 'Not deployed'
    appInsights: (enableAppInsights && enableDiagnostics) ? appInsightsName : 'Not deployed'
  }
  security: {
    keyVault: keyVaultName
    secretsStored: [
      'acs-connection-string'
      'acs-endpoint'
    ]
  }
}
