<#
.SYNOPSIS
  One-command deploy of the Azure source systems for the Fabric end-to-end demo
  (Microsoft Entra ID-only authentication).

.DESCRIPTION
  1. (Optional) regenerates deterministic demo data.
  2. Deploys infra\main.bicep at subscription scope (creates the resource group,
     a user-assigned managed identity that is the SQL Entra admin, both SQL
     servers/DBs, and the storage account).
  3. Seeds the two Azure SQL databases and uploads the shortcut reference files
     via an in-template deployment script that authenticates with an Entra
     access token - no SQL password anywhere.
  4. Grants you (the deploying user) db_owner on both databases.

  There is NO SQL password: the servers use Entra-only authentication to satisfy
  the "Azure SQL requires Entra-only auth" org policy.

  Fabric capacity and workspace are created manually - see
  docs\fabric-workspace-setup.md.

.EXAMPLE
  .\scripts\Deploy-Azure.ps1 -ResourceGroupName rg-fabric-e2e-demo -Location eastus2

.NOTES
  Prerequisites: Azure CLI (az login done). Seeding runs in Azure (deployment
  script), so no local SqlServer module / sqlcmd is required.
#>
[CmdletBinding()]
param(
  [string] $ResourceGroupName = 'rg-fabric-e2e-demo',
  [string] $Location = 'eastus2',
  [switch] $SkipDataGen,
  [switch] $SkipSeed
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$deploymentName = "fabric-demo-source"

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

# --- 2. Capture your identity (Entra admin grant) + client IP (firewall) -----
$objectId = az ad signed-in-user show --query id -o tsv 2>$null
$upn      = az ad signed-in-user show --query userPrincipalName -o tsv 2>$null
try   { $clientIp = (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 10) }
catch { $clientIp = ''; Write-Warning "Could not detect public IP; skipping client firewall rule." }

$seedData = (-not $SkipSeed).ToString().ToLower()

# --- 3. Deploy Bicep (subscription scope) ------------------------------------
Write-Host "Deploying Bicep (resource group, managed identity, SQL, storage, seed)..." -ForegroundColor Green
$deployJson = az deployment sub create `
  --name $deploymentName `
  --location $Location `
  --template-file (Join-Path $repoRoot 'infra\main.bicep') `
  --parameters resourceGroupName=$ResourceGroupName location=$Location `
               aadAdminObjectId=$objectId `
               aadAdminLogin=$upn `
               clientIpAddress=$clientIp `
               seedData=$seedData `
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
  seedIdentityName     = $o.seedIdentityName.value
}

Write-Host "`nDeployment outputs:" -ForegroundColor Green
$outputs.GetEnumerator() | ForEach-Object { "  {0,-20} {1}" -f $_.Key, $_.Value }

# Persist outputs for the Fabric setup docs / later reruns.
$outFile = Join-Path $repoRoot 'infra\deployment-outputs.json'
$outputs | ConvertTo-Json | Set-Content -Path $outFile -Encoding utf8
Write-Host "Saved outputs to $outFile" -ForegroundColor Green

if ($SkipSeed) {
  Write-Host "`nSeeding was skipped (-SkipSeed). Seed later with scripts\Seed-Data.ps1." -ForegroundColor Yellow
} else {
  Write-Host "`nDatabases seeded and you were granted db_owner (Entra) by the deployment script." -ForegroundColor Green
}

Write-Host "`nDone. Next: create the Fabric capacity + workspace and wire up ingestion." -ForegroundColor Green
Write-Host "See docs\fabric-workspace-setup.md and docs\ingestion-*.md." -ForegroundColor Green
