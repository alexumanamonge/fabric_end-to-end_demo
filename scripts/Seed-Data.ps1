<#
.SYNOPSIS
  Re-seeds the Azure source systems for the Fabric end-to-end demo using
  Microsoft Entra authentication (no SQL password).

.DESCRIPTION
  The deployment already seeds the databases automatically from the gateway VM
  (scripts\vm-seed.ps1, run by its Custom Script Extension). Use THIS helper only
  to re-run the seed by hand.

  IMPORTANT: the SQL servers are private-endpoint-only, so this script must run
  from a host INSIDE the spoke VNet - i.e. RDP into the gateway VM and run it
  there (or from another peered/VNet-connected machine). It will NOT work from a
  laptop over the public internet.

  - Authenticates to Azure SQL with YOUR Entra access token (az account
    get-access-token). You must already have db_owner on the databases - the
    deployment grants this to the deploying user automatically.
  - Runs the two SQL seed scripts (data\sql\ops_seed.sql, etl_seed.sql).
  - Uploads the shortcut reference files (data\blob\reference\*) to Storage.

  Requires the SqlServer PowerShell module (Invoke-Sqlcmd -AccessToken).

.NOTES
  Pass the values from the Bicep deployment outputs (infra\deployment-outputs.json).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $ResourceGroupName,
  [Parameter(Mandatory)] [string] $OpsServerFqdn,
  [Parameter(Mandatory)] [string] $OpsDatabase,
  [Parameter(Mandatory)] [string] $EtlServerFqdn,
  [Parameter(Mandatory)] [string] $EtlDatabase,
  [Parameter(Mandatory)] [string] $StorageAccountName,
  [string] $ContainerName = 'reference'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$sqlDir   = Join-Path $repoRoot 'data\sql'
$blobDir  = Join-Path $repoRoot 'data\blob\reference'

if (-not (Get-Command Invoke-Sqlcmd -ErrorAction SilentlyContinue)) {
  throw "The SqlServer PowerShell module is required (Invoke-Sqlcmd -AccessToken). Install with: Install-Module SqlServer -Scope CurrentUser"
}

# Acquire an Entra access token for Azure SQL using the current az login.
$token = az account get-access-token --resource https://database.windows.net/ --query accessToken -o tsv
if (-not $token) { throw "Could not obtain an Entra token. Run 'az login' first." }

function Invoke-SqlFile {
  param([string] $ServerFqdn, [string] $Database, [string] $InputFile)
  Write-Host "  -> $Database  ($([System.IO.Path]::GetFileName($InputFile)))" -ForegroundColor Cyan
  Invoke-Sqlcmd -ServerInstance $ServerFqdn -Database $Database -AccessToken $token `
    -InputFile $InputFile -TrustServerCertificate -QueryTimeout 600 -ConnectionTimeout 60
}

Write-Host "Seeding Azure SQL databases (Entra auth)..." -ForegroundColor Green
Invoke-SqlFile -ServerFqdn $OpsServerFqdn -Database $OpsDatabase -InputFile (Join-Path $sqlDir 'ops_seed.sql')
Invoke-SqlFile -ServerFqdn $EtlServerFqdn -Database $EtlDatabase -InputFile (Join-Path $sqlDir 'etl_seed.sql')

Write-Host "Uploading shortcut reference files to storage..." -ForegroundColor Green
$key = az storage account keys list --account-name $StorageAccountName --resource-group $ResourceGroupName --query "[0].value" -o tsv
if (-not $key) { throw "Could not retrieve storage account key for $StorageAccountName." }

az storage blob upload-batch `
  --account-name $StorageAccountName `
  --account-key $key `
  --destination $ContainerName `
  --source $blobDir `
  --overwrite true | Out-Null

Write-Host "Seeding complete." -ForegroundColor Green
Write-Host "  SQL  : $OpsDatabase (customers, products), $EtlDatabase (orders, support_tickets)"
Write-Host "  Blob : $StorageAccountName/$ContainerName/regions/regions.csv"
