// ---------------------------------------------------------------------------
// Automated seeding via an Azure PowerShell deployment script.
//  - Downloads the seed SQL + Shortcut file from the (public) repo raw URL.
//  - Runs data\sql\ops_seed.sql and etl_seed.sql with Invoke-Sqlcmd.
//  - Uploads regions.csv to the Shortcut storage container.
// Runs inside an Azure Container Instance managed by the deploymentScripts RP,
// which reaches SQL through the server's "AllowAllAzureServices" firewall rule.
// ---------------------------------------------------------------------------

@description('Azure region for the deployment script + its transient storage.')
param location string

@description('FQDN of the operational SQL server (Mirroring source).')
param opsSqlServerFqdn string

@description('Operational database name.')
param opsDatabaseName string

@description('FQDN of the ETL SQL server (Copy Job source).')
param etlSqlServerFqdn string

@description('ETL database name.')
param etlDatabaseName string

@description('SQL administrator login.')
param sqlAdminLogin string

@description('SQL administrator password.')
@secure()
param sqlAdminPassword string

@description('Storage account that holds the Shortcut source files.')
param storageAccountName string

@description('Blob container for the Shortcut files.')
param containerName string

@description('Base raw URL to download seed files from.')
param seedSourceUrl string

@description('Token that forces the script to re-run on each deployment.')
param forceUpdateTag string

@description('Resource tags.')
param tags object = {}

// Existing storage account so we can read its key (data-plane upload, no login).
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource seedScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'seed-demo-data'
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '11.5'
    retentionInterval: 'PT1H'
    timeout: 'PT30M'
    cleanupPreference: 'OnSuccess'
    forceUpdateTag: forceUpdateTag
    environmentVariables: [
      { name: 'OPS_FQDN', value: opsSqlServerFqdn }
      { name: 'OPS_DB', value: opsDatabaseName }
      { name: 'ETL_FQDN', value: etlSqlServerFqdn }
      { name: 'ETL_DB', value: etlDatabaseName }
      { name: 'SQL_LOGIN', value: sqlAdminLogin }
      { name: 'SQL_PASSWORD', secureValue: sqlAdminPassword }
      { name: 'STORAGE_ACCT', value: storageAccountName }
      { name: 'STORAGE_KEY', secureValue: storage.listKeys().keys[0].value }
      { name: 'CONTAINER', value: containerName }
      { name: 'SEED_BASE_URL', value: seedSourceUrl }
    ]
    scriptContent: '''
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

Write-Host "Installing SqlServer module..."
Install-Module SqlServer -Force -Scope CurrentUser -AllowClobber -Repository PSGallery | Out-Null
Import-Module SqlServer

function Get-SeedFile([string] $rel) {
  $url = "$($env:SEED_BASE_URL)/$rel"
  $out = Join-Path $env:TEMP ([System.IO.Path]::GetFileName($rel))
  Write-Host "Downloading $url"
  Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
  return $out
}

$opsSql = Get-SeedFile 'data/sql/ops_seed.sql'
$etlSql = Get-SeedFile 'data/sql/etl_seed.sql'
$regions = Get-SeedFile 'data/blob/reference/regions/regions.csv'

Write-Host "Seeding $($env:OPS_DB) on $($env:OPS_FQDN)..."
Invoke-Sqlcmd -ServerInstance $env:OPS_FQDN -Database $env:OPS_DB `
  -Username $env:SQL_LOGIN -Password $env:SQL_PASSWORD `
  -InputFile $opsSql -TrustServerCertificate -QueryTimeout 300 -ConnectionTimeout 60

Write-Host "Seeding $($env:ETL_DB) on $($env:ETL_FQDN)..."
Invoke-Sqlcmd -ServerInstance $env:ETL_FQDN -Database $env:ETL_DB `
  -Username $env:SQL_LOGIN -Password $env:SQL_PASSWORD `
  -InputFile $etlSql -TrustServerCertificate -QueryTimeout 600 -ConnectionTimeout 60

Write-Host "Uploading regions.csv to $($env:STORAGE_ACCT)/$($env:CONTAINER)..."
$ctx = New-AzStorageContext -StorageAccountName $env:STORAGE_ACCT -StorageAccountKey $env:STORAGE_KEY
Set-AzStorageBlobContent -File $regions -Container $env:CONTAINER -Blob 'regions/regions.csv' -Context $ctx -Force | Out-Null

Write-Host "Seeding complete."
$DeploymentScriptOutputs = @{
  status = 'seeded'
  opsDatabase = $env:OPS_DB
  etlDatabase = $env:ETL_DB
  shortcutBlob = "$($env:CONTAINER)/regions/regions.csv"
}
'''
  }
}

@description('Seed status output.')
output status string = seedScript.properties.outputs.status
