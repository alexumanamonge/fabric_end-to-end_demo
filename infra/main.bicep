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

@description('Short environment/prefix token used to name resources (lowercase, 3-10 chars).')
@minLength(3)
@maxLength(10)
param namePrefix string = 'fabdemo'

@description('Azure region for all resources.')
param location string = 'eastus2'

@description('Resource group name.')
param resourceGroupName string = 'rg-${namePrefix}-source'

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

@description('Deterministic suffix to keep globally-unique names stable across redeploys.')
param uniqueSuffix string = substring(uniqueString(subscription().subscriptionId, namePrefix), 0, 6)

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
    sqlServerName: 'sql-${namePrefix}-ops-${uniqueSuffix}'
    databaseName: 'sqldb-ops'
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
    storageAccountName: 'st${namePrefix}${uniqueSuffix}'
    location: location
    containerName: 'reference'
    tags: tags
  }
}

// --- Source 3: ETL DB (stands in for SQL MI) --------------------------------
module sqlEtl 'modules/sqlServer.bicep' = {
  scope: rg
  name: 'sqlEtl'
  params: {
    sqlServerName: 'sql-${namePrefix}-etl-${uniqueSuffix}'
    databaseName: 'sqldb-etl'
    location: location
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    aadAdminObjectId: aadAdminObjectId
    aadAdminLogin: aadAdminLogin
    clientIpAddress: clientIpAddress
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
