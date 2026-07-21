<#
.SYNOPSIS
  One-command deploy of the Azure source systems for the Fabric end-to-end demo.

.DESCRIPTION
  1. (Optional) regenerates deterministic demo data.
  2. Deploys infra\main.bicep at subscription scope (creates the resource group).
  3. Seeds the two Azure SQL databases and uploads the shortcut reference files.

  Fabric capacity and workspace are created manually - see docs\fabric-workspace-setup.md.

.EXAMPLE
  $env:SQL_ADMIN_PASSWORD = 'Ch@ngeMe-StrongP@ss1'
  .\scripts\Deploy-Azure.ps1 -ResourceGroupName rg-fabric-e2e-demo -Location eastus2

.NOTES
  Prerequisites: Azure CLI (az login done), Bicep, and either the SqlServer
  PowerShell module or sqlcmd.exe for seeding.
#>
[CmdletBinding()]
param(
  [string] $ResourceGroupName = 'rg-fabric-e2e-demo',
  [string] $Location = 'eastus2',
  [string] $SqlAdminLogin = 'fabricadmin',
  [string] $SqlAdminPassword = $env:SQL_ADMIN_PASSWORD,
  [switch] $SkipDataGen,
  [switch] $SkipSeed
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$deploymentName = "fabric-demo-source"

if (-not $SqlAdminPassword) {
  throw "Provide the SQL admin password via -SqlAdminPassword or `$env:SQL_ADMIN_PASSWORD."
}

# --- 0. Confirm az login -----------------------------------------------------
$account = az account show --query "{sub:name, id:id}" -o json 2>$null | ConvertFrom-Json
if (-not $account) { throw "Run 'az login' and 'az account set --subscription <id>' first." }
Write-Host "Subscription: $($account.sub) ($($account.id))" -ForegroundColor Green

# --- 1. Generate demo data ---------------------------------------------------
if (-not $SkipDataGen) {
  Write-Host "Generating demo data..." -ForegroundColor Green
  python (Join-Path $repoRoot 'scripts\generate_demo_data.py')
  if ($LASTEXITCODE -ne 0) { throw "Data generation failed." }
}

# --- 2. Capture identity + client IP for AAD admin and firewall --------------
$objectId = az ad signed-in-user show --query id -o tsv 2>$null
$upn      = az ad signed-in-user show --query userPrincipalName -o tsv 2>$null
try   { $clientIp = (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 10) }
catch { $clientIp = ''; Write-Warning "Could not detect public IP; skipping client firewall rule." }

# --- 3. Deploy Bicep (subscription scope) ------------------------------------
Write-Host "Deploying Bicep (this creates the resource group and all resources)..." -ForegroundColor Green
$deployJson = az deployment sub create `
  --name $deploymentName `
  --location $Location `
  --template-file (Join-Path $repoRoot 'infra\main.bicep') `
  --parameters resourceGroupName=$ResourceGroupName location=$Location `
               sqlAdminLogin=$SqlAdminLogin `
               sqlAdminPassword=$SqlAdminPassword `
               aadAdminObjectId=$objectId `
               aadAdminLogin=$upn `
               clientIpAddress=$clientIp `
               seedData=false `
  --query properties.outputs -o json
if ($LASTEXITCODE -ne 0) { throw "Bicep deployment failed." }

$o = $deployJson | ConvertFrom-Json
$outputs = [ordered]@{
  resourceGroupName    = $o.resourceGroupName.value
  location             = $o.location.value
  opsSqlServerFqdn     = $o.opsSqlServerFqdn.value
  opsDatabaseName      = $o.opsDatabaseName.value
  etlSqlServerFqdn     = $o.etlSqlServerFqdn.value
  etlDatabaseName      = $o.etlDatabaseName.value
  storageAccountName   = $o.storageAccountName.value
  storageDfsEndpoint   = $o.storageDfsEndpoint.value
  storageContainerName = $o.storageContainerName.value
  sqlAdminLogin        = $o.sqlAdminLogin.value
}

Write-Host "`nDeployment outputs:" -ForegroundColor Green
$outputs.GetEnumerator() | ForEach-Object { "  {0,-20} {1}" -f $_.Key, $_.Value }

# Persist outputs for the Fabric setup docs / later reruns.
$outFile = Join-Path $repoRoot 'infra\deployment-outputs.json'
$outputs | ConvertTo-Json | Set-Content -Path $outFile -Encoding utf8
Write-Host "Saved outputs to $outFile" -ForegroundColor Green

# --- 4. Seed data ------------------------------------------------------------
if (-not $SkipSeed) {
  & (Join-Path $PSScriptRoot 'Seed-Data.ps1') `
    -ResourceGroupName $outputs.resourceGroupName `
    -OpsServerFqdn     $outputs.opsSqlServerFqdn `
    -OpsDatabase       $outputs.opsDatabaseName `
    -EtlServerFqdn     $outputs.etlSqlServerFqdn `
    -EtlDatabase       $outputs.etlDatabaseName `
    -SqlAdminLogin     $outputs.sqlAdminLogin `
    -SqlAdminPassword  $SqlAdminPassword `
    -StorageAccountName $outputs.storageAccountName `
    -ContainerName     $outputs.storageContainerName
}

Write-Host "`nDone. Next: create the Fabric capacity + workspace and wire up ingestion." -ForegroundColor Green
Write-Host "See docs\fabric-workspace-setup.md and docs\ingestion-*.md." -ForegroundColor Green
