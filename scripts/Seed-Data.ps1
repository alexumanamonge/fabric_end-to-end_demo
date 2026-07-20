<#
.SYNOPSIS
  Seeds the Azure source systems for the Fabric end-to-end demo.

.DESCRIPTION
  - Runs the two SQL seed scripts (data\sql\ops_seed.sql, etl_seed.sql) against the
    two Azure SQL databases.
  - Uploads the shortcut reference files (data\blob\reference\*) to the Storage account.

  SQL execution uses Invoke-Sqlcmd (SqlServer module) when available, otherwise
  falls back to sqlcmd.exe. Blob upload uses the Azure CLI with the account key.

.NOTES
  Run Deploy-Azure.ps1 first (it calls this script automatically), or run this
  standalone by passing the values from the Bicep deployment outputs.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $ResourceGroupName,
  [Parameter(Mandatory)] [string] $OpsServerFqdn,
  [Parameter(Mandatory)] [string] $OpsDatabase,
  [Parameter(Mandatory)] [string] $EtlServerFqdn,
  [Parameter(Mandatory)] [string] $EtlDatabase,
  [Parameter(Mandatory)] [string] $SqlAdminLogin,
  [Parameter(Mandatory)] [string] $SqlAdminPassword,
  [Parameter(Mandatory)] [string] $StorageAccountName,
  [string] $ContainerName = 'reference'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$sqlDir   = Join-Path $repoRoot 'data\sql'
$blobDir  = Join-Path $repoRoot 'data\blob\reference'

function Invoke-SqlFile {
  param([string] $ServerFqdn, [string] $Database, [string] $InputFile)

  Write-Host "  -> $Database  ($([System.IO.Path]::GetFileName($InputFile)))" -ForegroundColor Cyan

  if (Get-Command Invoke-Sqlcmd -ErrorAction SilentlyContinue) {
    Invoke-Sqlcmd -ServerInstance $ServerFqdn -Database $Database `
      -Username $SqlAdminLogin -Password $SqlAdminPassword `
      -InputFile $InputFile -TrustServerCertificate -QueryTimeout 300 -ConnectionTimeout 60
  }
  elseif (Get-Command sqlcmd -ErrorAction SilentlyContinue) {
    & sqlcmd -S $ServerFqdn -d $Database -U $SqlAdminLogin -P $SqlAdminPassword `
      -i $InputFile -b -l 60
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd failed for $Database (exit $LASTEXITCODE)" }
  }
  else {
    throw "Neither Invoke-Sqlcmd (SqlServer module) nor sqlcmd.exe is available. Install one to seed SQL. See infra\README.md."
  }
}

Write-Host "Seeding Azure SQL databases..." -ForegroundColor Green
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
