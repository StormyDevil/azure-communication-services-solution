// ============================================================================
// Store Secrets Module
// Securely stores ACS connection strings in Key Vault
// ============================================================================

@description('Name of the Key Vault')
param keyVaultName string

@description('ACS connection string to store')
@secure()
param acsConnectionString string

@description('ACS endpoint to store')
param acsEndpoint string

// ============================================================================
// RESOURCES
// ============================================================================

// Reference existing Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// Store ACS connection string
resource acsConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'acs-connection-string'
  properties: {
    value: acsConnectionString
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Store ACS endpoint
resource acsEndpointSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'acs-endpoint'
  properties: {
    value: acsEndpoint
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('The URI for the connection string secret')
output connectionStringSecretUri string = acsConnectionStringSecret.properties.secretUri

@description('The URI for the endpoint secret')
output endpointSecretUri string = acsEndpointSecret.properties.secretUri
