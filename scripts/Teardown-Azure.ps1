<#
.SYNOPSIS
  Tears down all Azure source resources for the Fabric end-to-end demo.

.DESCRIPTION
  Deletes BOTH resource groups created by Deploy-Azure.ps1: the workload RG (Azure
  SQL + storage) and the networking RG (spoke VNet, private endpoints, Fabric-
  delegated subnet). Fabric items are NOT affected - delete the Fabric workspace and
  the managed virtual network data gateway manually if you want a full reset. The
  networking RG is deleted first so the private endpoints release their link to the
  SQL servers.

.EXAMPLE
  .\scripts\Teardown-Azure.ps1 -ResourceGroupName rg-fabric-e2e-demo `
    -NetworkResourceGroupName rg-fabric-e2e-network
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string] $ResourceGroupName = 'rg-fabric-e2e-demo',
  [string] $NetworkResourceGroupName = 'rg-fabric-e2e-network',
  [switch] $NoWait
)

$ErrorActionPreference = 'Stop'

function Remove-Rg([string] $name) {
  $exists = az group exists --name $name -o tsv
  if ($exists -ne 'true') {
    Write-Host "Resource group '$name' does not exist. Skipping." -ForegroundColor Yellow
    return
  }
  if ($PSCmdlet.ShouldProcess($name, "Delete resource group")) {
    Write-Host "Deleting resource group '$name'..." -ForegroundColor Yellow
    if ($NoWait) { az group delete --name $name --yes --no-wait }
    else         { az group delete --name $name --yes }
  }
}

# Delete networking RG first (private endpoints reference the SQL servers).
Remove-Rg $NetworkResourceGroupName
Remove-Rg $ResourceGroupName
Write-Host "Teardown requested. (Use -NoWait to return immediately.)" -ForegroundColor Green
