using 'main.bicep'

// ============================================================================
// Azure Communication Services Solution - Production Parameters
// ============================================================================

// Base configuration
param baseName = 'acssoln'
param environment = 'prod'
param location = 'swedencentral'
param dataLocation = 'Europe'

// Feature flags - all capabilities enabled for production
param enableEmail = true
param enableSms = true
param enableDiagnostics = true

// Governance
param owner = 'Partner Solutions Team'
param costCenter = 'IT-Communications'
