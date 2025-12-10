// ============================================================================
// Event Grid Module
// Handles ACS events for delivery reports, call events, chat messages, etc.
// ============================================================================

@description('Name of the Event Grid System Topic')
param name string

@description('Azure region for the Event Grid topic')
param location string

@description('Resource tags')
param tags object

@description('Communication Services resource ID to subscribe to')
param communicationServicesId string

@description('Communication Services resource name')
param communicationServicesName string

@description('Enable diagnostic logging')
param enableDiagnostics bool = true

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

@description('Webhook endpoint URL for event delivery (optional)')
param webhookEndpoint string = ''

@description('Azure Function resource ID for event handling (optional)')
param functionAppId string = ''

// ============================================================================
// RESOURCES
// ============================================================================

// Event Grid System Topic for ACS events
resource eventGridTopic 'Microsoft.EventGrid/systemTopics@2024-06-01-preview' = {
  name: name
  location: location
  tags: tags
  properties: {
    source: communicationServicesId
    topicType: 'Microsoft.Communication.CommunicationServices'
  }
}

// Event subscription for SMS events (delivery reports)
resource smsEventSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2024-06-01-preview' = if (!empty(webhookEndpoint)) {
  parent: eventGridTopic
  name: 'sms-events'
  properties: {
    destination: {
      endpointType: 'WebHook'
      properties: {
        endpointUrl: webhookEndpoint
      }
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Communication.SMSReceived'
        'Microsoft.Communication.SMSDeliveryReportReceived'
      ]
    }
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
  }
}

// Event subscription for Email events
resource emailEventSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2024-06-01-preview' = if (!empty(webhookEndpoint)) {
  parent: eventGridTopic
  name: 'email-events'
  properties: {
    destination: {
      endpointType: 'WebHook'
      properties: {
        endpointUrl: webhookEndpoint
      }
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Communication.EmailDeliveryReportReceived'
        'Microsoft.Communication.EmailEngagementTrackingReportReceived'
      ]
    }
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
  }
}

// Event subscription for Chat events
resource chatEventSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2024-06-01-preview' = if (!empty(webhookEndpoint)) {
  parent: eventGridTopic
  name: 'chat-events'
  properties: {
    destination: {
      endpointType: 'WebHook'
      properties: {
        endpointUrl: webhookEndpoint
      }
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Communication.ChatMessageReceived'
        'Microsoft.Communication.ChatThreadCreated'
        'Microsoft.Communication.ChatThreadDeleted'
        'Microsoft.Communication.ChatThreadParticipantAdded'
        'Microsoft.Communication.ChatThreadParticipantRemoved'
      ]
    }
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
  }
}

// Event subscription for Call events
resource callEventSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2024-06-01-preview' = if (!empty(webhookEndpoint)) {
  parent: eventGridTopic
  name: 'call-events'
  properties: {
    destination: {
      endpointType: 'WebHook'
      properties: {
        endpointUrl: webhookEndpoint
      }
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Communication.CallStarted'
        'Microsoft.Communication.CallEnded'
        'Microsoft.Communication.RecordingFileStatusUpdated'
      ]
    }
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
  }
}

// Diagnostic settings for Event Grid topic
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: 'diag-${name}'
  scope: eventGridTopic
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

@description('The resource ID of the Event Grid System Topic')
output resourceId string = eventGridTopic.id

@description('The name of the Event Grid System Topic')
output name string = eventGridTopic.name

@description('The Event Grid system topic source')
output source string = eventGridTopic.properties.source
