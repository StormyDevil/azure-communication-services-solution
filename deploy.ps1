<#
.SYNOPSIS
    Deploys the Azure Communication Services solution.

.DESCRIPTION
    This script deploys a Well-Architected Azure Communication Services solution
    including ACS, Email Service, Key Vault, and Log Analytics.

.PARAMETER Environment
    The target environment (dev, staging, prod).

.PARAMETER Location
    Azure region for deployment.

.PARAMETER ResourceGroupName
    Name of the resource group (created if not exists).

.EXAMPLE
    ./deploy.ps1 -Environment dev -Location swedencentral

.EXAMPLE
    ./deploy.ps1 -Environment prod -Location swedencentral -ResourceGroupName rg-acs-prod-001
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment = 'dev',

    [Parameter(Mandatory = $false)]
    [ValidateSet('swedencentral', 'germanywestcentral', 'northeurope', 'westeurope')]
    [string]$Location = 'swedencentral',

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = ''
)

# ============================================================================
# CONFIGURATION
# ============================================================================

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script location
$ScriptPath = $PSScriptRoot
$BicepFile = Join-Path $ScriptPath 'main.bicep'
$ParameterFile = Join-Path $ScriptPath "main.$Environment.bicepparam"

# Generate resource group name if not provided
if ([string]::IsNullOrEmpty($ResourceGroupName)) {
    $ResourceGroupName = "rg-acs-solution-$Environment-001"
}

# ============================================================================
# BANNER
# ============================================================================

Write-Host @"

    ╔═══════════════════════════════════════════════════════════════════════╗
    ║   AZURE COMMUNICATION SERVICES SOLUTION                               ║
    ║   Well-Architected Framework Aligned Deployment                       ║
    ╚═══════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# ============================================================================
# PREREQUISITES CHECK
# ============================================================================

Write-Host "  ┌────────────────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
Write-Host "  │  PREREQUISITES CHECK                                               │" -ForegroundColor DarkGray
Write-Host "  └────────────────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
Write-Host ""

# Check Azure CLI
Write-Host "  [1/3] " -ForegroundColor DarkGray -NoNewline
Write-Host "Checking Azure CLI..." -ForegroundColor Yellow
try {
    $azVersion = az version 2>&1 | ConvertFrom-Json
    Write-Host "      └─ Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Gray
    Write-Host "  ✓ " -ForegroundColor Green -NoNewline
    Write-Host "Azure CLI installed" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ " -ForegroundColor Red -NoNewline
    Write-Host "Azure CLI not found. Install from https://aka.ms/installazurecli" -ForegroundColor Red
    exit 1
}

# Check Bicep CLI
Write-Host "  [2/3] " -ForegroundColor DarkGray -NoNewline
Write-Host "Checking Bicep CLI..." -ForegroundColor Yellow
try {
    $bicepVersion = az bicep version 2>&1
    Write-Host "      └─ $bicepVersion" -ForegroundColor Gray
    Write-Host "  ✓ " -ForegroundColor Green -NoNewline
    Write-Host "Bicep CLI installed" -ForegroundColor Green
}
catch {
    Write-Host "  ⚠ " -ForegroundColor Yellow -NoNewline
    Write-Host "Installing Bicep CLI..." -ForegroundColor Yellow
    az bicep install
}

# Check Azure login
Write-Host "  [3/3] " -ForegroundColor DarkGray -NoNewline
Write-Host "Checking Azure login..." -ForegroundColor Yellow
try {
    $account = az account show 2>&1 | ConvertFrom-Json
    Write-Host "      └─ Subscription: $($account.name)" -ForegroundColor Gray
    Write-Host "      └─ Tenant: $($account.tenantId)" -ForegroundColor Gray
    Write-Host "  ✓ " -ForegroundColor Green -NoNewline
    Write-Host "Logged in as: $($account.user.name)" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ " -ForegroundColor Red -NoNewline
    Write-Host "Not logged in. Running 'az login'..." -ForegroundColor Red
    az login
}

Write-Host ""

# ============================================================================
# DEPLOYMENT CONFIGURATION
# ============================================================================

Write-Host "  ┌────────────────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
Write-Host "  │  DEPLOYMENT CONFIGURATION                                          │" -ForegroundColor DarkGray
Write-Host "  └────────────────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
Write-Host ""
Write-Host "      Environment:     $Environment" -ForegroundColor White
Write-Host "      Location:        $Location" -ForegroundColor White
Write-Host "      Resource Group:  $ResourceGroupName" -ForegroundColor White
Write-Host "      Bicep File:      $BicepFile" -ForegroundColor White
Write-Host "      Parameters:      $ParameterFile" -ForegroundColor White
Write-Host ""

# ============================================================================
# BICEP VALIDATION
# ============================================================================

Write-Host "  ┌────────────────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
Write-Host "  │  BICEP VALIDATION                                                  │" -ForegroundColor DarkGray
Write-Host "  └────────────────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
Write-Host ""

Write-Host "  [1/2] " -ForegroundColor DarkGray -NoNewline
Write-Host "Building Bicep template..." -ForegroundColor Yellow
$buildResult = az bicep build --file $BicepFile 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ " -ForegroundColor Red -NoNewline
    Write-Host "Bicep build failed:" -ForegroundColor Red
    Write-Host $buildResult -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ " -ForegroundColor Green -NoNewline
Write-Host "Bicep build successful" -ForegroundColor Green

Write-Host "  [2/2] " -ForegroundColor DarkGray -NoNewline
Write-Host "Linting Bicep template..." -ForegroundColor Yellow
$lintResult = az bicep lint --file $BicepFile 2>&1
# Treat warnings as non-blocking
if ($lintResult -match "Error") {
    Write-Host "  ✗ " -ForegroundColor Red -NoNewline
    Write-Host "Bicep lint errors found:" -ForegroundColor Red
    Write-Host $lintResult -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ " -ForegroundColor Green -NoNewline
Write-Host "Bicep lint passed" -ForegroundColor Green
Write-Host ""

# ============================================================================
# RESOURCE GROUP CREATION
# ============================================================================

Write-Host "  ┌────────────────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
Write-Host "  │  RESOURCE GROUP                                                    │" -ForegroundColor DarkGray
Write-Host "  └────────────────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
Write-Host ""

$rgExists = az group exists --name $ResourceGroupName 2>&1
if ($rgExists -eq 'true') {
    Write-Host "  ✓ " -ForegroundColor Green -NoNewline
    Write-Host "Resource group '$ResourceGroupName' already exists" -ForegroundColor Green
}
else {
    if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Create resource group")) {
        Write-Host "  Creating resource group '$ResourceGroupName' in '$Location'..." -ForegroundColor Yellow
        az group create --name $ResourceGroupName --location $Location --tags Environment=$Environment ManagedBy=Bicep Project=ACS-Solution | Out-Null
        Write-Host "  ✓ " -ForegroundColor Green -NoNewline
        Write-Host "Resource group created" -ForegroundColor Green
    }
}
Write-Host ""

# ============================================================================
# WHAT-IF ANALYSIS
# ============================================================================

Write-Host "  ┌────────────────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
Write-Host "  │  WHAT-IF ANALYSIS                                                  │" -ForegroundColor DarkGray
Write-Host "  └────────────────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
Write-Host ""

Write-Host "  Running what-if analysis..." -ForegroundColor Yellow
$whatIfResult = az deployment group what-if `
    --resource-group $ResourceGroupName `
    --template-file $BicepFile `
    --parameters $ParameterFile `
    --no-pretty-print 2>&1

$whatIfText = $whatIfResult -join "`n"
$createCount = [regex]::Matches($whatIfText, "(?m)^\s*\+\s").Count
$modifyCount = [regex]::Matches($whatIfText, "(?m)^\s*~\s").Count
$deleteCount = [regex]::Matches($whatIfText, "(?m)^\s*-\s").Count

Write-Host ""
Write-Host "  │  Change Summary:" -ForegroundColor White
Write-Host "  │  + Create: $createCount resources" -ForegroundColor Green
Write-Host "  │  ~ Modify: $modifyCount resources" -ForegroundColor Yellow
Write-Host "  │  - Delete: $deleteCount resources" -ForegroundColor Red
Write-Host ""

# ============================================================================
# DEPLOYMENT CONFIRMATION
# ============================================================================

if (-not $WhatIfPreference) {
    Write-Host "  ┌────────────────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "  │  DEPLOYMENT CONFIRMATION                                           │" -ForegroundColor DarkGray
    Write-Host "  └────────────────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
    Write-Host ""

    $confirm = Read-Host "  Proceed with deployment? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "  Deployment cancelled." -ForegroundColor Yellow
        exit 0
    }
    Write-Host ""

    # ============================================================================
    # DEPLOYMENT
    # ============================================================================

    Write-Host "  ┌────────────────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "  │  DEPLOYING RESOURCES                                               │" -ForegroundColor DarkGray
    Write-Host "  └────────────────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
    Write-Host ""

    $deploymentName = "acs-solution-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-Host "  Deployment name: $deploymentName" -ForegroundColor Gray
    Write-Host "  Starting deployment..." -ForegroundColor Yellow
    Write-Host ""

    $deploymentResult = az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file $BicepFile `
        --parameters $ParameterFile `
        --name $deploymentName `
        --output json 2>&1 | ConvertFrom-Json

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ " -ForegroundColor Red -NoNewline
        Write-Host "Deployment failed!" -ForegroundColor Red
        Write-Host $deploymentResult -ForegroundColor Red
        exit 1
    }

    Write-Host "  ✓ " -ForegroundColor Green -NoNewline
    Write-Host "Deployment successful!" -ForegroundColor Green
    Write-Host ""

    # ============================================================================
    # DEPLOYMENT OUTPUTS
    # ============================================================================

    Write-Host "  ┌────────────────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "  │  DEPLOYMENT OUTPUTS                                                │" -ForegroundColor DarkGray
    Write-Host "  └────────────────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
    Write-Host ""

    $outputs = $deploymentResult.properties.outputs
    Write-Host "      Communication Services: $($outputs.communicationServicesName.value)" -ForegroundColor White
    Write-Host "      Endpoint:               $($outputs.communicationServicesEndpoint.value)" -ForegroundColor White
    Write-Host "      Email Service:          $($outputs.emailServiceName.value)" -ForegroundColor White
    Write-Host "      Email Domain:           $($outputs.emailDomain.value)" -ForegroundColor White
    Write-Host "      Key Vault:              $($outputs.keyVaultName.value)" -ForegroundColor White
    Write-Host "      Key Vault URI:          $($outputs.keyVaultUri.value)" -ForegroundColor White
    Write-Host ""

    # ============================================================================
    # NEXT STEPS
    # ============================================================================

    Write-Host "  ┌────────────────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "  │  NEXT STEPS                                                        │" -ForegroundColor DarkGray
    Write-Host "  └────────────────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  1. Link email domain to Communication Services (if using email)" -ForegroundColor White
    Write-Host "     az communication update --name <acs-name> --linked-domains <domain-id>" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Provision phone numbers (if using SMS/Voice)" -ForegroundColor White
    Write-Host "     Visit Azure Portal > Communication Services > Phone Numbers" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3. Configure RBAC for application access" -ForegroundColor White
    Write-Host "     Grant 'Contributor' role on ACS to your app's managed identity" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  4. Retrieve connection string from Key Vault" -ForegroundColor White
    Write-Host "     az keyvault secret show --vault-name $($outputs.keyVaultName.value) --name acs-connection-string" -ForegroundColor Gray
    Write-Host ""
}
else {
    Write-Host "  What-If mode: No changes were made." -ForegroundColor Yellow
}

Write-Host @"

    ╔═══════════════════════════════════════════════════════════════════════╗
    ║   DEPLOYMENT COMPLETE                                                 ║
    ╚═══════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan
