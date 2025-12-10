// ============================================================================
// Email Service Module
// Provides email sending capabilities through Azure Communication Services
// ============================================================================

@description('Name of the Email Service resource')
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

#disable-next-line no-unused-params
@description('Name of the Communication Services to link email domain (used for post-deployment linking)')
param communicationServicesName string

@description('Domain management type')
@allowed([
  'AzureManaged'
  'CustomerManaged'
])
param domainManagement string = 'AzureManaged'

@description('Enable user engagement tracking (opens, clicks)')
param enableUserEngagementTracking bool = false

// ============================================================================
// RESOURCES
// ============================================================================

// Email Service resource
resource emailService 'Microsoft.Communication/emailServices@2023-04-01' = {
  name: name
  location: 'global'
  tags: tags
  properties: {
    dataLocation: dataLocation
  }
}

// Azure-managed email domain (for quick start)
// For production, consider a custom domain for better deliverability
resource emailDomain 'Microsoft.Communication/emailServices/domains@2023-04-01' = {
  parent: emailService
  name: 'AzureManagedDomain'
  location: 'global'
  tags: tags
  properties: {
    domainManagement: domainManagement
    userEngagementTracking: enableUserEngagementTracking ? 'Enabled' : 'Disabled'
  }
}

// Sender username for the email domain
resource senderUsername 'Microsoft.Communication/emailServices/domains/senderUsernames@2023-04-01' = {
  parent: emailDomain
  name: 'donotreply'
  properties: {
    displayName: 'Do Not Reply'
    username: 'DoNotReply'
  }
}

// Additional sender for notifications
resource notificationSender 'Microsoft.Communication/emailServices/domains/senderUsernames@2023-04-01' = {
  parent: emailDomain
  name: 'notifications'
  properties: {
    displayName: 'Notifications'
    username: 'notifications'
  }
}

// Note: Linking email domain to Communication Services is done post-deployment
// via Azure CLI or Portal, as it requires updating the ACS resource with
// the linkedDomains property after the email domain is fully provisioned.
// Example: az communication update --name <acs-name> --linked-domains <domain-id>

// ============================================================================
// OUTPUTS
// ============================================================================

@description('The resource ID of the Email Service')
output resourceId string = emailService.id

@description('The name of the Email Service')
output name string = emailService.name

@description('The email domain resource ID')
output domainResourceId string = emailDomain.id

@description('The email domain name')
output domainName string = emailDomain.name

@description('The mail from address for DoNotReply')
output mailFromAddressDoNotReply string = 'DoNotReply@${emailDomain.properties.mailFromSenderDomain}'

@description('The mail from address for Notifications')
output mailFromAddressNotifications string = 'notifications@${emailDomain.properties.mailFromSenderDomain}'

@description('The sender domain for emails')
output senderDomain string = emailDomain.properties.mailFromSenderDomain
