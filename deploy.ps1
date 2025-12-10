<#
.SYNOPSIS
    Deploys the Azure Communication Services solution.

.DESCRIPTION
    This script deploys a Well-Architected Azure Communication Services solution
    including ACS, Email Service, Key Vault, and Log Analytics.

.PARAMETER Environment
    The target environment (dev, staging, prod).

.PARAMETER Location
    Azure region for deployment. If not specified, an interactive menu will be shown.

.PARAMETER ResourceGroupName
    Name of the resource group (created if not exists).

.EXAMPLE
    ./deploy.ps1 -Environment dev -Location swedencentral

.EXAMPLE
    ./deploy.ps1 -Environment prod -Location westus2 -ResourceGroupName rg-acs-prod-001

.EXAMPLE
    ./deploy.ps1 -Environment dev
    # Shows interactive location selection menu
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment = 'dev',

    [Parameter(Mandatory = $false)]
    [string]$Location = '',

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = ''
)

# ============================================================================
# CONFIGURATION
# ============================================================================

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Available locations with their display names and data locations
$AvailableLocations = @{
    # Europe
    'swedencentral'      = @{ DisplayName = 'Sweden Central'; DataLocation = 'Europe'; Region = 'Europe' }
    'germanywestcentral' = @{ DisplayName = 'Germany West Central'; DataLocation = 'Germany'; Region = 'Europe' }
    'northeurope'        = @{ DisplayName = 'North Europe (Ireland)'; DataLocation = 'Europe'; Region = 'Europe' }
    'westeurope'         = @{ DisplayName = 'West Europe (Netherlands)'; DataLocation = 'Europe'; Region = 'Europe' }
    'uksouth'            = @{ DisplayName = 'UK South'; DataLocation = 'UK'; Region = 'Europe' }
    'ukwest'             = @{ DisplayName = 'UK West'; DataLocation = 'UK'; Region = 'Europe' }
    'francecentral'      = @{ DisplayName = 'France Central'; DataLocation = 'France'; Region = 'Europe' }
    'switzerlandnorth'   = @{ DisplayName = 'Switzerland North'; DataLocation = 'Switzerland'; Region = 'Europe' }
    'norwayeast'         = @{ DisplayName = 'Norway East'; DataLocation = 'Norway'; Region = 'Europe' }
    # Americas
    'eastus'             = @{ DisplayName = 'East US'; DataLocation = 'United States'; Region = 'Americas' }
    'eastus2'            = @{ DisplayName = 'East US 2'; DataLocation = 'United States'; Region = 'Americas' }
    'westus'             = @{ DisplayName = 'West US'; DataLocation = 'United States'; Region = 'Americas' }
    'westus2'            = @{ DisplayName = 'West US 2'; DataLocation = 'United States'; Region = 'Americas' }
    'westus3'            = @{ DisplayName = 'West US 3'; DataLocation = 'United States'; Region = 'Americas' }
    'centralus'          = @{ DisplayName = 'Central US'; DataLocation = 'United States'; Region = 'Americas' }
    'southcentralus'     = @{ DisplayName = 'South Central US'; DataLocation = 'United States'; Region = 'Americas' }
    'canadacentral'      = @{ DisplayName = 'Canada Central'; DataLocation = 'Canada'; Region = 'Americas' }
    'canadaeast'         = @{ DisplayName = 'Canada East'; DataLocation = 'Canada'; Region = 'Americas' }
    'brazilsouth'        = @{ DisplayName = 'Brazil South'; DataLocation = 'Brazil'; Region = 'Americas' }
    # Asia Pacific
    'australiaeast'      = @{ DisplayName = 'Australia East'; DataLocation = 'Australia'; Region = 'Asia Pacific' }
    'australiasoutheast' = @{ DisplayName = 'Australia Southeast'; DataLocation = 'Australia'; Region = 'Asia Pacific' }
    'japaneast'          = @{ DisplayName = 'Japan East'; DataLocation = 'Japan'; Region = 'Asia Pacific' }
    'japanwest'          = @{ DisplayName = 'Japan West'; DataLocation = 'Japan'; Region = 'Asia Pacific' }
    'koreacentral'       = @{ DisplayName = 'Korea Central'; DataLocation = 'Korea'; Region = 'Asia Pacific' }
    'southeastasia'      = @{ DisplayName = 'Southeast Asia (Singapore)'; DataLocation = 'Singapore'; Region = 'Asia Pacific' }
    'eastasia'           = @{ DisplayName = 'East Asia (Hong Kong)'; DataLocation = 'Singapore'; Region = 'Asia Pacific' }
    'centralindia'       = @{ DisplayName = 'Central India'; DataLocation = 'India'; Region = 'Asia Pacific' }
    # Middle East & Africa
    'uaenorth'           = @{ DisplayName = 'UAE North'; DataLocation = 'UAE'; Region = 'Middle East & Africa' }
    'southafricanorth'   = @{ DisplayName = 'South Africa North'; DataLocation = 'South Africa'; Region = 'Middle East & Africa' }
}

# Function to show location selection menu
function Show-LocationMenu {
    Write-Host ""
    Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |  SELECT DEPLOYMENT LOCATION                                            |" -ForegroundColor Cyan
    Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
    
    $regions = $AvailableLocations.Values | Select-Object -ExpandProperty Region -Unique | Sort-Object
    $index = 1
    $locationMap = @{}
    
    foreach ($region in $regions) {
        Write-Host "  $region" -ForegroundColor Yellow
        $regionLocations = $AvailableLocations.GetEnumerator() | Where-Object { $_.Value.Region -eq $region } | Sort-Object { $_.Value.DisplayName }
        foreach ($loc in $regionLocations) {
            $locationMap[$index] = $loc.Key
            Write-Host "    [$index] $($loc.Value.DisplayName) ($($loc.Key))" -ForegroundColor White
            $index++
        }
        Write-Host ""
    }
    
    Write-Host "  Enter the number of your choice (1-$($index-1)): " -ForegroundColor Cyan -NoNewline
    $selection = Read-Host
    
    if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -lt $index) {
        return $locationMap[[int]$selection]
    }
    else {
        Write-Host "  [!] Invalid selection. Using default: swedencentral" -ForegroundColor Yellow
        return 'swedencentral'
    }
}

# Handle location selection
if ([string]::IsNullOrEmpty($Location)) {
    $Location = Show-LocationMenu
}
elseif (-not $AvailableLocations.ContainsKey($Location)) {
    Write-Host "  [!] Location '$Location' is not in the predefined list." -ForegroundColor Yellow
    Write-Host "      Proceeding with the specified location anyway." -ForegroundColor Yellow
}

# Get data location for the selected location
if ($AvailableLocations.ContainsKey($Location)) {
    $DataLocation = $AvailableLocations[$Location].DataLocation
    $LocationDisplayName = $AvailableLocations[$Location].DisplayName
}
else {
    $DataLocation = 'Europe'  # Default fallback
    $LocationDisplayName = $Location
}

# Script location
$ScriptPath = $PSScriptRoot
$BicepFile = Join-Path $ScriptPath 'bicep/main.bicep'
$ParameterFile = Join-Path $ScriptPath "bicep/main.$Environment.bicepparam"

# Generate resource group name if not provided
if ([string]::IsNullOrEmpty($ResourceGroupName)) {
    $ResourceGroupName = "rg-acs-solution-$Environment-001"
}

# ============================================================================
# BANNER
# ============================================================================

Write-Host ""
Write-Host "    +=========================================================================+" -ForegroundColor Cyan
Write-Host "    |   AZURE COMMUNICATION SERVICES SOLUTION                               |" -ForegroundColor Cyan
Write-Host "    |   Well-Architected Framework Aligned Deployment                       |" -ForegroundColor Cyan
Write-Host "    +=========================================================================+" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# PREREQUISITES CHECK
# ============================================================================

Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "  |  PREREQUISITES CHECK                                                   |" -ForegroundColor DarkGray
Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host ""

# Check Azure CLI
Write-Host "  [1/3] " -ForegroundColor DarkGray -NoNewline
Write-Host "Checking Azure CLI..." -ForegroundColor Yellow
try {
    $azVersion = az version 2>&1 | ConvertFrom-Json
    Write-Host "      -> Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Gray
    Write-Host "  [OK] " -ForegroundColor Green -NoNewline
    Write-Host "Azure CLI installed" -ForegroundColor Green
}
catch {
    Write-Host "  [X] " -ForegroundColor Red -NoNewline
    Write-Host "Azure CLI not found. Install from https://aka.ms/installazurecli" -ForegroundColor Red
    exit 1
}

# Check Bicep CLI
Write-Host "  [2/3] " -ForegroundColor DarkGray -NoNewline
Write-Host "Checking Bicep CLI..." -ForegroundColor Yellow
try {
    $bicepVersion = az bicep version 2>&1
    Write-Host "      -> $bicepVersion" -ForegroundColor Gray
    Write-Host "  [OK] " -ForegroundColor Green -NoNewline
    Write-Host "Bicep CLI installed" -ForegroundColor Green
}
catch {
    Write-Host "  [!] " -ForegroundColor Yellow -NoNewline
    Write-Host "Installing Bicep CLI..." -ForegroundColor Yellow
    az bicep install
}

# Check Azure login
Write-Host "  [3/3] " -ForegroundColor DarkGray -NoNewline
Write-Host "Checking Azure login..." -ForegroundColor Yellow
try {
    $account = az account show 2>&1 | ConvertFrom-Json
    Write-Host "      -> Subscription: $($account.name)" -ForegroundColor Gray
    Write-Host "      -> Tenant: $($account.tenantId)" -ForegroundColor Gray
    Write-Host "  [OK] " -ForegroundColor Green -NoNewline
    Write-Host "Logged in as: $($account.user.name)" -ForegroundColor Green
}
catch {
    Write-Host "  [X] " -ForegroundColor Red -NoNewline
    Write-Host "Not logged in. Running 'az login'..." -ForegroundColor Red
    az login
}

Write-Host ""

# ============================================================================
# DEPLOYMENT CONFIGURATION
# ============================================================================

Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "  |  DEPLOYMENT CONFIGURATION                                              |" -ForegroundColor DarkGray
Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host ""
Write-Host "      Environment:     $Environment" -ForegroundColor White
Write-Host "      Location:        $LocationDisplayName ($Location)" -ForegroundColor White
Write-Host "      Data Location:   $DataLocation" -ForegroundColor White
Write-Host "      Resource Group:  $ResourceGroupName" -ForegroundColor White
Write-Host "      Bicep File:      $BicepFile" -ForegroundColor White
Write-Host "      Parameters:      $ParameterFile" -ForegroundColor White
Write-Host ""

# ============================================================================
# BICEP VALIDATION
# ============================================================================

Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "  |  BICEP VALIDATION                                                      |" -ForegroundColor DarkGray
Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host ""

Write-Host "  [1/2] " -ForegroundColor DarkGray -NoNewline
Write-Host "Building Bicep template..." -ForegroundColor Yellow
$buildResult = az bicep build --file $BicepFile 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [X] " -ForegroundColor Red -NoNewline
    Write-Host "Bicep build failed:" -ForegroundColor Red
    Write-Host $buildResult -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] " -ForegroundColor Green -NoNewline
Write-Host "Bicep build successful" -ForegroundColor Green

Write-Host "  [2/2] " -ForegroundColor DarkGray -NoNewline
Write-Host "Linting Bicep template..." -ForegroundColor Yellow
$lintResult = az bicep lint --file $BicepFile 2>&1
# Treat warnings as non-blocking
if ($lintResult -match "Error") {
    Write-Host "  [X] " -ForegroundColor Red -NoNewline
    Write-Host "Bicep lint errors found:" -ForegroundColor Red
    Write-Host $lintResult -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] " -ForegroundColor Green -NoNewline
Write-Host "Bicep lint passed" -ForegroundColor Green
Write-Host ""

# ============================================================================
# RESOURCE GROUP CREATION
# ============================================================================

Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "  |  RESOURCE GROUP                                                        |" -ForegroundColor DarkGray
Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host ""

$rgExists = az group exists --name $ResourceGroupName 2>&1
if ($rgExists -eq 'true') {
    Write-Host "  [OK] " -ForegroundColor Green -NoNewline
    Write-Host "Resource group '$ResourceGroupName' already exists" -ForegroundColor Green
}
else {
    if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Create resource group")) {
        Write-Host "  Creating resource group '$ResourceGroupName' in '$Location'..." -ForegroundColor Yellow
        az group create --name $ResourceGroupName --location $Location --tags Environment=$Environment ManagedBy=Bicep Project=ACS-Solution | Out-Null
        Write-Host "  [OK] " -ForegroundColor Green -NoNewline
        Write-Host "Resource group created" -ForegroundColor Green
    }
}
Write-Host ""

# ============================================================================
# WHAT-IF ANALYSIS
# ============================================================================

Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "  |  WHAT-IF ANALYSIS                                                      |" -ForegroundColor DarkGray
Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host ""

Write-Host "  Running what-if analysis..." -ForegroundColor Yellow
$whatIfResult = az deployment group what-if `
    --resource-group $ResourceGroupName `
    --template-file $BicepFile `
    --parameters $ParameterFile `
    --parameters location=$Location dataLocation="$DataLocation" `
    --no-pretty-print 2>&1

$whatIfText = $whatIfResult -join "`n"
$createCount = [regex]::Matches($whatIfText, "(?m)^\s*\+\s").Count
$modifyCount = [regex]::Matches($whatIfText, "(?m)^\s*~\s").Count
$deleteCount = [regex]::Matches($whatIfText, "(?m)^\s*-\s").Count

Write-Host ""
Write-Host "  |  Change Summary:" -ForegroundColor White
Write-Host "  |  + Create: $createCount resources" -ForegroundColor Green
Write-Host "  |  ~ Modify: $modifyCount resources" -ForegroundColor Yellow
Write-Host "  |  - Delete: $deleteCount resources" -ForegroundColor Red
Write-Host ""

# ============================================================================
# DEPLOYMENT CONFIRMATION
# ============================================================================

if (-not $WhatIfPreference) {
    Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "  |  DEPLOYMENT CONFIRMATION                                               |" -ForegroundColor DarkGray
    Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
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

    Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "  |  DEPLOYING RESOURCES                                                   |" -ForegroundColor DarkGray
    Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host ""

    $deploymentName = "acs-solution-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-Host "  Deployment name: $deploymentName" -ForegroundColor Gray
    Write-Host "  Starting deployment..." -ForegroundColor Yellow
    Write-Host ""

    $deploymentResult = az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file $BicepFile `
        --parameters $ParameterFile `
        --parameters location=$Location dataLocation="$DataLocation" `
        --name $deploymentName `
        --output json 2>&1 | ConvertFrom-Json

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [X] " -ForegroundColor Red -NoNewline
        Write-Host "Deployment failed!" -ForegroundColor Red
        Write-Host $deploymentResult -ForegroundColor Red
        exit 1
    }

    Write-Host "  [OK] " -ForegroundColor Green -NoNewline
    Write-Host "Deployment successful!" -ForegroundColor Green
    Write-Host ""

    # ============================================================================
    # DEPLOYMENT OUTPUTS
    # ============================================================================

    Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "  |  DEPLOYMENT OUTPUTS                                                    |" -ForegroundColor DarkGray
    Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
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

    Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "  |  NEXT STEPS                                                            |" -ForegroundColor DarkGray
    Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  1. Link email domain to Communication Services (if using email)" -ForegroundColor White
    Write-Host '     az communication update --name [acs-name] --linked-domains [domain-id]' -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Provision phone numbers (if using SMS/Voice)" -ForegroundColor White
    Write-Host '     Visit Azure Portal -> Communication Services -> Phone Numbers' -ForegroundColor Gray
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

Write-Host ""
Write-Host "    +=========================================================================+" -ForegroundColor Cyan
Write-Host "    |   DEPLOYMENT COMPLETE                                                 |" -ForegroundColor Cyan
Write-Host "    +=========================================================================+" -ForegroundColor Cyan
Write-Host ""
