<#
.SYNOPSIS
  Uploads the Shortcut reference file(s) to the demo storage account.

.DESCRIPTION
  The storage account is on the PUBLIC network, so this runs fine from your
  laptop - no VNet access is required. It uploads data\blob\reference\* (the
  regions reference data the OneLake Shortcut points at) to the blob container.

  NOTE ON SQL: the two Azure SQL databases are private-endpoint-only, so they are
  NOT seeded from here. Seed them from Fabric AFTER you connect the managed virtual
  network data gateway, using your organizational account (you are the SQL Entra
  admin). See docs\networking-gateway.md, "Seed the databases from Fabric".

.EXAMPLE
  .\scripts\Seed-Data.ps1 -ResourceGroupName rg-fabric-e2e-demo `
    -StorageAccountName stfabricxxxxx

.NOTES
  Pass the values from the Bicep deployment outputs (infra\deployment-outputs.json).
  Requires Azure CLI (az login done).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $ResourceGroupName,
  [Parameter(Mandatory)] [string] $StorageAccountName,
  [string] $ContainerName = 'reference'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$blobDir  = Join-Path $repoRoot 'data\blob\reference'

if (-not (Test-Path $blobDir)) {
  throw "Reference data folder not found: $blobDir. Run scripts\generate_demo_data.py first."
}

Write-Host "Uploading Shortcut reference files to storage..." -ForegroundColor Green
$key = az storage account keys list --account-name $StorageAccountName --resource-group $ResourceGroupName --query "[0].value" -o tsv
if (-not $key) { throw "Could not retrieve storage account key for $StorageAccountName." }

az storage blob upload-batch `
  --account-name $StorageAccountName `
  --account-key $key `
  --destination $ContainerName `
  --source $blobDir `
  --overwrite true | Out-Null

Write-Host "Upload complete." -ForegroundColor Green
Write-Host "  Blob : $StorageAccountName/$ContainerName/regions/regions.csv"
Write-Host "  SQL  : seed sqldb-ops (customers, products) and sqldb-etl (orders, support_tickets)"
Write-Host "         from Fabric via the managed VNet gateway - see docs\networking-gateway.md."
