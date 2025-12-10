using 'main.bicep'

// ============================================================================
// Azure Communication Services Solution - Development Parameters
// ============================================================================

// Base configuration
param baseName = 'acssoln'
param environment = 'dev'
param location = 'swedencentral'
param dataLocation = 'Europe'

// Feature flags
param enableEmail = true
param enableSms = true
param enableDiagnostics = true

// Governance
param owner = 'Partner Solutions Team'
param costCenter = 'IT-Communications'
