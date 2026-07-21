<#
.SYNOPSIS
  One-command deploy of the Azure source systems for the Fabric end-to-end demo
  (Microsoft Entra ID-only auth + private endpoints, no VM).

.DESCRIPTION
  1. (Optional) regenerates deterministic demo data.
  2. Deploys infra\main.bicep at subscription scope. This creates TWO resource
     groups:
       - workload RG : both Entra-only Azure SQL servers/DBs (public network access
                       DISABLED) and the storage account.
       - network  RG : spoke VNet + subnets, SQL private endpoints + private DNS,
                       and a subnet DELEGATED to Fabric for its managed virtual
                       network data gateway. No VM/ACI is deployed.
  3. Uploads the Shortcut reference file to the (public) storage account.

  The SQL servers are Entra-only AND private-endpoint-only to satisfy org policy.
  The DEPLOYING USER is set as the SQL Entra admin, so after you connect Fabric's
  managed VNet data gateway you can seed the databases from Fabric with your own
  account - see docs\networking-gateway.md (there is no in-VNet VM to seed from).

  Hub-spoke: only the SPOKE VNet is deployed here; hub + peering are out of scope.
  Fabric capacity and workspace are created manually - see
  docs\fabric-workspace-setup.md.

.EXAMPLE
  .\scripts\Deploy-Azure.ps1 -ResourceGroupName rg-fabric-e2e-demo `
    -NetworkResourceGroupName rg-fabric-e2e-network -Location eastus2

.NOTES
  Prerequisites: Azure CLI (az login done). SQL seeding happens later from Fabric,
  so no local SqlServer module / sqlcmd is required.
#>
[CmdletBinding()]
param(
  [string] $ResourceGroupName = 'rg-fabric-e2e-demo',
  [string] $NetworkResourceGroupName = 'rg-fabric-e2e-network',
  [string] $Location = 'eastus2',
  [switch] $SkipDataGen,
  [switch] $SkipBlobUpload
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

# --- 2. Capture your identity (set as SQL Entra admin) -----------------------
# main.bicep defaults the SQL admin to the deployer, but we pass it explicitly so
# the same admin is used whether you deploy from CLI or the portal button.
$objectId = az ad signed-in-user show --query id -o tsv 2>$null
$upn      = az ad signed-in-user show --query userPrincipalName -o tsv 2>$null

# --- 3. Deploy Bicep (subscription scope; creates BOTH resource groups) -------
Write-Host "Deploying Bicep (workload RG: SQL/storage; network RG: VNet/PE/Fabric-delegated subnet)..." -ForegroundColor Green
$params = @(
  "resourceGroupName=$ResourceGroupName",
  "networkResourceGroupName=$NetworkResourceGroupName",
  "location=$Location"
)
if ($objectId) { $params += "aadAdminObjectId=$objectId" }
if ($upn)      { $params += "aadAdminLogin=$upn" }

$deployJson = az deployment sub create `
  --name $deploymentName `
  --location $Location `
  --template-file (Join-Path $repoRoot 'infra\main.bicep') `
  --parameters $params `
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
  sqlEntraAdminLogin       = $o.sqlEntraAdminLogin.value
  vnetName                 = $o.vnetName.value
  fabricGatewaySubnetName  = $o.fabricGatewaySubnetName.value
}

Write-Host "`nDeployment outputs:" -ForegroundColor Green
$outputs.GetEnumerator() | ForEach-Object { "  {0,-26} {1}" -f $_.Key, $_.Value }

# Persist outputs for the Fabric setup docs / later reruns.
$outFile = Join-Path $repoRoot 'infra\deployment-outputs.json'
$outputs | ConvertTo-Json | Set-Content -Path $outFile -Encoding utf8
Write-Host "Saved outputs to $outFile" -ForegroundColor Green

# --- 4. Upload the Shortcut reference file (public storage; no VNet needed) ----
if (-not $SkipBlobUpload) {
  Write-Host "`nUploading Shortcut reference file to storage..." -ForegroundColor Green
  & (Join-Path $PSScriptRoot 'Seed-Data.ps1') `
      -ResourceGroupName $outputs.resourceGroupName `
      -StorageAccountName $outputs.storageAccountName `
      -ContainerName $outputs.storageContainerName
}

Write-Host "`nNext steps:" -ForegroundColor Green
Write-Host "  1. Create the Fabric capacity + workspace - see docs\fabric-workspace-setup.md."
Write-Host "  2. Create Fabric's MANAGED virtual network data gateway on subnet"
Write-Host "     '$($outputs.fabricGatewaySubnetName)' in VNet '$($outputs.vnetName)' - see docs\networking-gateway.md."
Write-Host "  3. Seed the SQL databases from Fabric (you are the SQL Entra admin:"
Write-Host "     $($outputs.sqlEntraAdminLogin)) - see docs\networking-gateway.md."
Write-Host "  4. Wire up ingestion through the gateway - see docs\ingestion-*.md."
