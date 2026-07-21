<#
.SYNOPSIS
  One-command deploy of the Azure source systems for the Fabric end-to-end demo
  (Microsoft Entra ID-only authentication).

.DESCRIPTION
  1. (Optional) regenerates deterministic demo data.
  2. Deploys infra\main.bicep at subscription scope. This creates TWO resource
     groups:
       - workload RG : managed identity, both Entra-only Azure SQL servers/DBs
                       (public network access DISABLED), and the storage account.
       - network  RG : spoke VNet + subnets, SQL private endpoints + private DNS,
                       and a Windows "VNet data gateway" VM.
  3. Seeds the two Azure SQL databases and uploads the shortcut reference files
     from inside the VNet (the gateway VM's Custom Script Extension) using an
     Entra access token - no SQL password anywhere.
  4. Grants you (the deploying user) db_owner on both databases.

  The SQL servers are Entra-only AND private-endpoint-only to satisfy org policy.
  Hub-spoke: only the SPOKE VNet is deployed here; hub + peering are out of scope.
  After deploy you must MANUALLY install the on-premises data gateway on the VM
  and register it, so Fabric can reach the private SQL endpoints - see
  docs\networking-gateway.md.

  Fabric capacity and workspace are created manually - see
  docs\fabric-workspace-setup.md.

.EXAMPLE
  .\scripts\Deploy-Azure.ps1 -ResourceGroupName rg-fabric-e2e-demo `
    -NetworkResourceGroupName rg-fabric-e2e-network -Location eastus2

.NOTES
  Prerequisites: Azure CLI (az login done). Seeding runs on the gateway VM, so no
  local SqlServer module / sqlcmd is required.
#>
[CmdletBinding()]
param(
  [string] $ResourceGroupName = 'rg-fabric-e2e-demo',
  [string] $NetworkResourceGroupName = 'rg-fabric-e2e-network',
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

# --- 2. Capture your identity (db_owner grant) + client IP (VM RDP rule) ------
$objectId = az ad signed-in-user show --query id -o tsv 2>$null
$upn      = az ad signed-in-user show --query userPrincipalName -o tsv 2>$null
try   { $clientIp = (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 10) }
catch { $clientIp = ''; Write-Warning "Could not detect public IP; skipping VM RDP allow rule." }

$seedData = (-not $SkipSeed).ToString().ToLower()

# --- 3. Deploy Bicep (subscription scope; creates BOTH resource groups) -------
Write-Host "Deploying Bicep (workload RG: identity/SQL/storage; network RG: VNet/PE/gateway VM)..." -ForegroundColor Green
$deployJson = az deployment sub create `
  --name $deploymentName `
  --location $Location `
  --template-file (Join-Path $repoRoot 'infra\main.bicep') `
  --parameters resourceGroupName=$ResourceGroupName `
               networkResourceGroupName=$NetworkResourceGroupName `
               location=$Location `
               aadAdminObjectId=$objectId `
               aadAdminLogin=$upn `
               clientIpAddress=$clientIp `
               seedData=$seedData `
  --query properties.outputs -o json
if ($LASTEXITCODE -ne 0) { throw "Bicep deployment failed." }

$o = $deployJson | ConvertFrom-Json
$outputs = [ordered]@{
  resourceGroupName        = $o.resourceGroupName.value
  networkResourceGroupName = $o.networkResourceGroupName.value
  location                 = $o.location.value
  opsSqlServerFqdn         = $o.opsSqlServerFqdn.value
  opsDatabaseName          = $o.opsDatabaseName.value
  etlSqlServerFqdn         = $o.etlSqlServerFqdn.value
  etlDatabaseName          = $o.etlDatabaseName.value
  storageAccountName       = $o.storageAccountName.value
  storageDfsEndpoint       = $o.storageDfsEndpoint.value
  storageContainerName     = $o.storageContainerName.value
  sqlAdminLogin            = $o.sqlAdminLogin.value
  seedIdentityName         = $o.seedIdentityName.value
  vnetName                 = $o.vnetName.value
  gatewayVmName            = $o.gatewayVmName.value
  gatewayVmPublicIp        = $o.gatewayVmPublicIp.value
  gatewayVmPrivateIp       = $o.gatewayVmPrivateIp.value
  vmAdminUsername          = $o.vmAdminUsername.value
}

Write-Host "`nDeployment outputs:" -ForegroundColor Green
$outputs.GetEnumerator() | ForEach-Object { "  {0,-26} {1}" -f $_.Key, $_.Value }

# Persist outputs for the Fabric setup docs / later reruns.
$outFile = Join-Path $repoRoot 'infra\deployment-outputs.json'
$outputs | ConvertTo-Json | Set-Content -Path $outFile -Encoding utf8
Write-Host "Saved outputs to $outFile" -ForegroundColor Green

if ($SkipSeed) {
  Write-Host "`nSeeding was skipped (-SkipSeed). Re-run the gateway VM seed extension, or run scripts\vm-seed.ps1 on the VM." -ForegroundColor Yellow
} else {
  Write-Host "`nThe gateway VM is seeding the databases from inside the VNet (check C:\seed-log.txt on the VM)." -ForegroundColor Green
  Write-Host "You were granted db_owner (Entra) on both databases." -ForegroundColor Green
}

Write-Host "`nNext steps:" -ForegroundColor Green
Write-Host "  1. Install the on-premises data gateway on VM '$($outputs.gatewayVmName)' - see docs\networking-gateway.md."
Write-Host "  2. Create the Fabric capacity + workspace - see docs\fabric-workspace-setup.md."
Write-Host "  3. Wire up ingestion through the gateway - see docs\ingestion-*.md."
