<#
.SYNOPSIS
    Cleans up Azure Communication Services solution deployments.

.DESCRIPTION
    This script removes Azure resources deployed by the deploy.ps1 script.
    It can delete specific resource groups or all ACS solution resource groups.

.PARAMETER Environment
    The target environment to clean up (dev, staging, prod).
    If not specified, will show all ACS resource groups and prompt for selection.

.PARAMETER ResourceGroupName
    Specific resource group name to delete. Overrides environment-based naming.

.PARAMETER All
    Delete ALL ACS solution resource groups (use with caution).

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER WhatIf
    Show what would be deleted without actually deleting.

.EXAMPLE
    ./cleanup.ps1 -Environment dev
    # Deletes rg-acs-solution-dev-001

.EXAMPLE
    ./cleanup.ps1 -ResourceGroupName rg-acs-custom-001
    # Deletes a specific resource group

.EXAMPLE
    ./cleanup.ps1 -All -Force
    # Deletes all ACS solution resource groups without prompting

.EXAMPLE
    ./cleanup.ps1 -WhatIf
    # Shows what would be deleted
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment = '',

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = '',

    [Parameter(Mandatory = $false)]
    [switch]$All,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# ============================================================================
# CONFIGURATION
# ============================================================================

$ErrorActionPreference = 'Stop'
$ResourceGroupPrefix = 'rg-acs-solution'

# ============================================================================
# BANNER
# ============================================================================

Write-Host ""
Write-Host "    +=========================================================================+" -ForegroundColor Red
Write-Host "    |   AZURE COMMUNICATION SERVICES - CLEANUP                               |" -ForegroundColor Red
Write-Host "    |   Resource Deletion Script                                             |" -ForegroundColor Red
Write-Host "    +=========================================================================+" -ForegroundColor Red
Write-Host ""

# ============================================================================
# PREREQUISITES CHECK
# ============================================================================

Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "  |  PREREQUISITES CHECK                                                   |" -ForegroundColor DarkGray
Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host ""

# Check Azure CLI
Write-Host "  [1/2] " -ForegroundColor DarkGray -NoNewline
Write-Host "Checking Azure CLI..." -ForegroundColor Yellow
try {
    $azVersion = az version 2>&1 | ConvertFrom-Json
    Write-Host "  [OK] " -ForegroundColor Green -NoNewline
    Write-Host "Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Green
}
catch {
    Write-Host "  [X] " -ForegroundColor Red -NoNewline
    Write-Host "Azure CLI not found. Install from https://aka.ms/installazurecli" -ForegroundColor Red
    exit 1
}

# Check Azure login
Write-Host "  [2/2] " -ForegroundColor DarkGray -NoNewline
Write-Host "Checking Azure login..." -ForegroundColor Yellow
try {
    $account = az account show 2>&1 | ConvertFrom-Json
    Write-Host "  [OK] " -ForegroundColor Green -NoNewline
    Write-Host "Logged in to: $($account.name)" -ForegroundColor Green
}
catch {
    Write-Host "  [X] " -ForegroundColor Red -NoNewline
    Write-Host "Not logged in. Running 'az login'..." -ForegroundColor Red
    az login
}

Write-Host ""

# ============================================================================
# FIND RESOURCE GROUPS
# ============================================================================

Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "  |  DISCOVERING RESOURCE GROUPS                                           |" -ForegroundColor DarkGray
Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host ""

# Get all ACS solution resource groups
$allResourceGroups = az group list --query "[?starts_with(name, '$ResourceGroupPrefix') || contains(name, 'acs')].{name:name, location:location, state:properties.provisioningState}" 2>&1 | ConvertFrom-Json

if ($null -eq $allResourceGroups -or $allResourceGroups.Count -eq 0) {
    Write-Host "  [!] No ACS solution resource groups found." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

Write-Host "  Found $($allResourceGroups.Count) resource group(s):" -ForegroundColor White
Write-Host ""

$index = 1
$rgMap = @{}
foreach ($rg in $allResourceGroups) {
    $rgMap[$index] = $rg.name
    $stateColor = if ($rg.state -eq 'Succeeded') { 'Green' } elseif ($rg.state -eq 'Deleting') { 'Yellow' } else { 'Red' }
    Write-Host "    [$index] $($rg.name)" -ForegroundColor White
    Write-Host "        Location: $($rg.location) | State: " -ForegroundColor Gray -NoNewline
    Write-Host "$($rg.state)" -ForegroundColor $stateColor
    $index++
}
Write-Host ""

# ============================================================================
# DETERMINE WHAT TO DELETE
# ============================================================================

$resourceGroupsToDelete = @()

if (-not [string]::IsNullOrEmpty($ResourceGroupName)) {
    # Specific resource group provided
    $resourceGroupsToDelete = @($ResourceGroupName)
}
elseif (-not [string]::IsNullOrEmpty($Environment)) {
    # Environment-based resource group
    $resourceGroupsToDelete = @("$ResourceGroupPrefix-$Environment-001")
}
elseif ($All) {
    # All ACS resource groups
    $resourceGroupsToDelete = $allResourceGroups | Select-Object -ExpandProperty name
}
else {
    # Interactive selection
    Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "  |  SELECT RESOURCE GROUPS TO DELETE                                      |" -ForegroundColor DarkGray
    Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Options:" -ForegroundColor White
    Write-Host "    - Enter a number (1-$($allResourceGroups.Count)) to delete a specific resource group" -ForegroundColor Gray
    Write-Host "    - Enter 'all' to delete all listed resource groups" -ForegroundColor Gray
    Write-Host "    - Enter 'q' to quit" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Your choice: " -ForegroundColor Cyan -NoNewline
    $selection = Read-Host

    if ($selection -eq 'q' -or $selection -eq 'Q') {
        Write-Host "  Cleanup cancelled." -ForegroundColor Yellow
        exit 0
    }
    elseif ($selection -eq 'all') {
        $resourceGroupsToDelete = $allResourceGroups | Select-Object -ExpandProperty name
    }
    elseif ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $allResourceGroups.Count) {
        $resourceGroupsToDelete = @($rgMap[[int]$selection])
    }
    else {
        Write-Host "  [X] Invalid selection." -ForegroundColor Red
        exit 1
    }
}

# ============================================================================
# CONFIRMATION
# ============================================================================

if ($resourceGroupsToDelete.Count -eq 0) {
    Write-Host "  [!] No resource groups selected for deletion." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor Red
Write-Host "  |  WARNING: DELETION CONFIRMATION                                        |" -ForegroundColor Red
Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor Red
Write-Host ""
Write-Host "  The following resource group(s) will be PERMANENTLY DELETED:" -ForegroundColor Red
Write-Host ""
foreach ($rg in $resourceGroupsToDelete) {
    Write-Host "    [X] $rg" -ForegroundColor Red
}
Write-Host ""
Write-Host "  This action CANNOT be undone. All resources in these groups will be lost." -ForegroundColor Yellow
Write-Host ""

if ($WhatIfPreference) {
    Write-Host "  [WhatIf] No resources were deleted (WhatIf mode)." -ForegroundColor Cyan
    exit 0
}

if (-not $Force) {
    Write-Host "  Type 'DELETE' to confirm: " -ForegroundColor Red -NoNewline
    $confirmation = Read-Host
    
    if ($confirmation -ne 'DELETE') {
        Write-Host ""
        Write-Host "  Cleanup cancelled. No resources were deleted." -ForegroundColor Yellow
        exit 0
    }
}

# ============================================================================
# DELETION
# ============================================================================

Write-Host ""
Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "  |  DELETING RESOURCES                                                    |" -ForegroundColor DarkGray
Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host ""

$successCount = 0
$failCount = 0

foreach ($rg in $resourceGroupsToDelete) {
    Write-Host "  Deleting '$rg'..." -ForegroundColor Yellow -NoNewline
    
    try {
        # Check if resource group exists
        $exists = az group exists --name $rg 2>&1
        
        if ($exists -eq 'true') {
            # Delete with --no-wait for faster execution
            az group delete --name $rg --yes --no-wait 2>&1 | Out-Null
            Write-Host " [QUEUED]" -ForegroundColor Green
            $successCount++
        }
        else {
            Write-Host " [NOT FOUND]" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-Host "    Error: $_" -ForegroundColor Red
        $failCount++
    }
}

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host ""
Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "  |  CLEANUP SUMMARY                                                       |" -ForegroundColor DarkGray
Write-Host "  +------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host ""
Write-Host "    Deletion requests queued: $successCount" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "    Failed: $failCount" -ForegroundColor Red
}
Write-Host ""
Write-Host "  Note: Resource group deletion runs in the background and may take" -ForegroundColor Gray
Write-Host "        several minutes to complete. Use the following command to check status:" -ForegroundColor Gray
Write-Host ""
Write-Host "    az group list --query `"[?starts_with(name, '$ResourceGroupPrefix')]`" -o table" -ForegroundColor Cyan
Write-Host ""

Write-Host "    +=========================================================================+" -ForegroundColor Green
Write-Host "    |   CLEANUP INITIATED                                                    |" -ForegroundColor Green
Write-Host "    +=========================================================================+" -ForegroundColor Green
Write-Host ""
