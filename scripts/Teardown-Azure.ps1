<#
.SYNOPSIS
  Tears down all Azure source resources for the Fabric end-to-end demo.

.DESCRIPTION
  Deletes the resource group created by Deploy-Azure.ps1. This removes both Azure
  SQL databases and the storage account. Fabric items are NOT affected (delete the
  Fabric workspace manually if you want a full reset).

.EXAMPLE
  .\scripts\Teardown-Azure.ps1 -NamePrefix fabdemo
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string] $NamePrefix = 'fabdemo',
  [string] $ResourceGroupName,
  [switch] $NoWait
)

$ErrorActionPreference = 'Stop'

if (-not $ResourceGroupName) { $ResourceGroupName = "rg-$NamePrefix-source" }

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
