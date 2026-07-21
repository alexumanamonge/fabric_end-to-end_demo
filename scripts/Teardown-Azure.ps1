<#
.SYNOPSIS
  Tears down all Azure source resources for the Fabric end-to-end demo.

.DESCRIPTION
  Deletes the resource group created by Deploy-Azure.ps1. This removes both Azure
  SQL databases and the storage account. Fabric items are NOT affected (delete the
  Fabric workspace manually if you want a full reset).

.EXAMPLE
  .\scripts\Teardown-Azure.ps1 -ResourceGroupName rg-fabric-e2e-demo
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string] $ResourceGroupName = 'rg-fabric-e2e-demo',
  [switch] $NoWait
)

$ErrorActionPreference = 'Stop'

$exists = az group exists --name $ResourceGroupName -o tsv
if ($exists -ne 'true') {
  Write-Host "Resource group '$ResourceGroupName' does not exist. Nothing to do." -ForegroundColor Yellow
  return
}

if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Delete resource group")) {
  Write-Host "Deleting resource group '$ResourceGroupName'..." -ForegroundColor Yellow
  $waitArg = if ($NoWait) { '--no-wait' } else { '' }
  az group delete --name $ResourceGroupName --yes $waitArg
  Write-Host "Teardown requested. (Use -NoWait to return immediately.)" -ForegroundColor Green
}
