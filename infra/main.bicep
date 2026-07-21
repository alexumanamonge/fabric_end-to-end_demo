// ===========================================================================
// Fabric End-to-End Demo - Azure source infrastructure
// ---------------------------------------------------------------------------
// Deploys the external source systems that feed the three Fabric ingestion
// patterns:
//   1. Azure SQL DB  sqldb-ops  -> Fabric MIRRORING       (customers, products)
//   2. Storage (ADLS Gen2)      -> OneLake SHORTCUT        (regions reference)
//   3. Azure SQL DB  sqldb-etl  -> Fabric ETL / Copy Job   (orders, tickets)
//
// Subscription-scoped so a single deployment creates the resource group and
// all resources. Fabric capacity + workspace are created manually by the user.
// ===========================================================================

targetScope = 'subscription'

@description('Azure region for all resources.')
param location string = 'eastus2'

@description('Name of the resource group to create. Use any name allowed by Azure.')
param resourceGroupName string = 'rg-fabric-e2e-demo'

@description('Name of the operational SQL logical server (Mirroring source). Globally unique; lowercase letters, numbers, and hyphens. Default is collision-safe - replace with your own name if you prefer.')
param opsSqlServerName string = 'sql-ops-${uniqueString(subscription().subscriptionId, resourceGroupName)}'

@description('Operational database name (Mirroring source).')
param opsDatabaseName string = 'sqldb-ops'

@description('Name of the ETL SQL logical server (Copy Job source). Globally unique; lowercase letters, numbers, and hyphens. Default is collision-safe - replace with your own name if you prefer.')
param etlSqlServerName string = 'sql-etl-${uniqueString(subscription().subscriptionId, resourceGroupName)}'

@description('ETL database name (Copy Job source).')
param etlDatabaseName string = 'sqldb-etl'

@description('Storage account name (Shortcut source). Globally unique, 3-24 lowercase alphanumerics. Default is collision-safe - replace with your own name if you prefer.')
@minLength(3)
@maxLength(24)
param storageAccountName string = 'stfabric${uniqueString(subscription().subscriptionId, resourceGroupName)}'

@description('Blob container that holds the Shortcut reference files.')
param containerName string = 'reference'

@description('Automatically seed the SQL databases and upload the Shortcut file as part of the deployment (runs a deployment script). Set false to seed later with scripts/Seed-Data.ps1.')
param seedData bool = true

@description('Base raw URL the automated seed step downloads seed files from (data/sql/*.sql, data/blob/reference/regions/regions.csv).')
param seedSourceUrl string = 'https://raw.githubusercontent.com/alexumanamonge/fabric_end-to-end_demo/main'

@description('Unique token that forces the seed deployment script to re-run on each deployment.')
param seedForceUpdateTag string = utcNow()

@description('SQL administrator login.')
param sqlAdminLogin string = 'fabricadmin'

@description('SQL administrator password. Provide via secure parameter / Key Vault, never commit.')
@secure()
param sqlAdminPassword string

@description('Entra ID admin object id (your user objectId). Empty to skip AAD admin.')
param aadAdminObjectId string = ''

@description('Entra ID admin login / display name (your UPN).')
param aadAdminLogin string = ''

@description('Client public IP to allow through SQL firewall for seeding. Empty to skip.')
param clientIpAddress string = ''

var tags = {
  workload: 'fabric-end-to-end-demo'
  environment: 'demo'
  managedBy: 'bicep'
}

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// --- Source 1: operational DB for mirroring ---------------------------------
module sqlOps 'modules/sqlServer.bicep' = {
  scope: rg
  name: 'sqlOps'
  params: {
    sqlServerName: opsSqlServerName
    databaseName: opsDatabaseName
    location: location
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    aadAdminObjectId: aadAdminObjectId
    aadAdminLogin: aadAdminLogin
    clientIpAddress: clientIpAddress
    tags: tags
  }
}

// --- Source 2: storage (ADLS Gen2) for shortcut -----------------------------
module storage 'modules/storage.bicep' = {
  scope: rg
  name: 'storage'
  params: {
    storageAccountName: storageAccountName
    location: location
    containerName: containerName
    tags: tags
  }
}

// --- Source 3: ETL DB (stands in for SQL MI) --------------------------------
module sqlEtl 'modules/sqlServer.bicep' = {
  scope: rg
  name: 'sqlEtl'
  params: {
    sqlServerName: etlSqlServerName
    databaseName: etlDatabaseName
    location: location
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    aadAdminObjectId: aadAdminObjectId
    aadAdminLogin: aadAdminLogin
    clientIpAddress: clientIpAddress
    tags: tags
  }
}

// --- Automated seeding (optional) -------------------------------------------
// Loads the SQL tables and uploads the Shortcut file via a deployment script,
// so the one-click button deployment is turn-key. Skipped when seedData=false
// (e.g. scripts/Deploy-Azure.ps1 seeds locally instead).
module seed 'modules/seed.bicep' = if (seedData) {
  scope: rg
  name: 'seedDemoData'
  params: {
    location: location
    opsSqlServerFqdn: sqlOps.outputs.fullyQualifiedDomainName
    opsDatabaseName: sqlOps.outputs.databaseName
    etlSqlServerFqdn: sqlEtl.outputs.fullyQualifiedDomainName
    etlDatabaseName: sqlEtl.outputs.databaseName
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    storageAccountName: storage.outputs.storageAccountName
    containerName: storage.outputs.containerName
    seedSourceUrl: seedSourceUrl
    forceUpdateTag: seedForceUpdateTag
    tags: tags
  }
}

// --- Outputs consumed by the seeding script and the Fabric setup docs -------
output resourceGroupName string = rg.name
output location string = location

output opsSqlServerFqdn string = sqlOps.outputs.fullyQualifiedDomainName
output opsDatabaseName string = sqlOps.outputs.databaseName

output etlSqlServerFqdn string = sqlEtl.outputs.fullyQualifiedDomainName
output etlDatabaseName string = sqlEtl.outputs.databaseName

output storageAccountName string = storage.outputs.storageAccountName
output storageDfsEndpoint string = storage.outputs.dfsEndpoint
output storageContainerName string = storage.outputs.containerName

output sqlAdminLogin string = sqlAdminLogin
