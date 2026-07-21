// ===========================================================================
// Fabric End-to-End Demo - Azure source infrastructure
// ---------------------------------------------------------------------------
// Deploys the external source systems that feed the three Fabric ingestion
// patterns:
//   1. Azure SQL DB  sqldb-ops  -> Fabric MIRRORING       (customers, products)
//   2. Storage (ADLS Gen2)      -> OneLake SHORTCUT        (regions reference)
//   3. Azure SQL DB  sqldb-etl  -> Fabric ETL / Copy Job   (orders, tickets)
//
// Networking (hub-spoke SPOKE only): the SQL servers are Entra-only AND
// public-network-access-disabled (org policy). They are reached through private
// endpoints in a spoke VNet deployed to a SEPARATE networking resource group.
// A subnet is DELEGATED to Microsoft.PowerPlatform/vnetaccesslinks so Fabric can
// provision its own MANAGED virtual network data gateway there (no VM to run) and
// reach the private SQL endpoints. The hub VNet and VNet peering are OUT OF SCOPE.
//
// Auth / seeding: the DEPLOYING USER is set as the Microsoft Entra admin on both
// SQL servers (via deployer()), so after the managed VNet gateway is connected
// they can seed the databases from Fabric with their organizational account. No
// in-VNet compute (VM/ACI) is deployed - see docs/networking-gateway.md.
//
// Subscription-scoped so a single deployment creates both resource groups and
// all resources. Fabric capacity + workspace are created manually by the user.
// ===========================================================================

targetScope = 'subscription'

@description('Azure region for all resources.')
param location string = 'eastus2'

@description('Name of the workload resource group to create (SQL, storage). Use any name allowed by Azure.')
param resourceGroupName string = 'rg-fabric-e2e-demo'

@description('Name of the NETWORKING resource group to create (spoke VNet, private endpoints, Fabric-delegated subnet). Hub-spoke: hub + peering are out of scope.')
param networkResourceGroupName string = 'rg-fabric-e2e-network'

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

@description('SQL administrator login. Local auth is DISABLED (Entra-only); kept only for ARM API compatibility.')
param sqlAdminLogin string = 'fabricadmin'

@description('SQL administrator password. Never used (Entra-only auth); has a generated default so no input is required. Kept for ARM API compatibility.')
@secure()
param sqlAdminPassword string = 'P${uniqueString(subscription().subscriptionId, resourceGroupName, 'sqlpwd')}q!7Z'

@description('Object id of the Entra principal to set as the SQL admin on both servers. Leave empty to use the DEPLOYING USER (recommended) so you can seed from Fabric with your own account.')
param aadAdminObjectId string = ''

@description('Login / UPN of the Entra SQL admin. Leave empty to use the deploying user.')
param aadAdminLogin string = ''

@description('Entra principal type of the SQL admin: User (default, deploying user), Group, or Application (managed identity / service principal).')
@allowed([
  'User'
  'Group'
  'Application'
])
param aadAdminPrincipalType string = 'User'

// --- Networking (spoke) -----------------------------------------------------
@description('Name of the spoke virtual network to create in the networking RG.')
param vnetName string = 'vnet-fabric-spoke'

@description('Address space for the spoke VNet.')
param vnetAddressPrefix string = '10.20.0.0/16'

@description('Subnet prefix for the SQL private endpoints.')
param privateEndpointSubnetPrefix string = '10.20.1.0/24'

@description('Subnet prefix DELEGATED to Fabric for the managed virtual network data gateway.')
param fabricGatewaySubnetPrefix string = '10.20.2.0/24'

@description('Name of the private endpoint for the operational SQL server.')
param opsPrivateEndpointName string = 'pe-sql-ops'

@description('Name of the private endpoint for the ETL SQL server.')
param etlPrivateEndpointName string = 'pe-sql-etl'

var tags = {
  workload: 'fabric-end-to-end-demo'
  environment: 'demo'
  managedBy: 'bicep'
}

// The deploying user becomes the SQL Entra admin unless an explicit principal is
// passed. deployer() resolves the identity that started the deployment for both
// Azure CLI and portal ("Deploy to Azure") deployments, so no input is required.
var effectiveAdminObjectId = empty(aadAdminObjectId) ? deployer().objectId : aadAdminObjectId
var effectiveAdminLogin = empty(aadAdminLogin) ? deployer().userPrincipalName : aadAdminLogin

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

resource rgNet 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: networkResourceGroupName
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
    aadAdminObjectId: effectiveAdminObjectId
    aadAdminLogin: effectiveAdminLogin
    aadAdminPrincipalType: aadAdminPrincipalType
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
    aadAdminObjectId: effectiveAdminObjectId
    aadAdminLogin: effectiveAdminLogin
    aadAdminPrincipalType: aadAdminPrincipalType
    tags: tags
  }
}

// --- Spoke VNet + private DNS (networking RG) --------------------------------
module network 'modules/network.bicep' = {
  scope: rgNet
  name: 'spokeNetwork'
  params: {
    vnetName: vnetName
    location: location
    vnetAddressPrefix: vnetAddressPrefix
    privateEndpointSubnetPrefix: privateEndpointSubnetPrefix
    fabricGatewaySubnetPrefix: fabricGatewaySubnetPrefix
    tags: tags
  }
}

// --- Private endpoints for both SQL servers (networking RG) ------------------
module peOps 'modules/privateEndpoint.bicep' = {
  scope: rgNet
  name: 'peSqlOps'
  params: {
    name: opsPrivateEndpointName
    location: location
    subnetId: network.outputs.privateEndpointSubnetId
    sqlServerId: sqlOps.outputs.sqlServerId
    sqlPrivateDnsZoneId: network.outputs.sqlPrivateDnsZoneId
    tags: tags
  }
}

module peEtl 'modules/privateEndpoint.bicep' = {
  scope: rgNet
  name: 'peSqlEtl'
  params: {
    name: etlPrivateEndpointName
    location: location
    subnetId: network.outputs.privateEndpointSubnetId
    sqlServerId: sqlEtl.outputs.sqlServerId
    sqlPrivateDnsZoneId: network.outputs.sqlPrivateDnsZoneId
    tags: tags
  }
}

// --- Outputs consumed by the seeding script and the Fabric setup docs -------
output resourceGroupName string = rg.name
output networkResourceGroupName string = rgNet.name
output location string = location

output opsSqlServerFqdn string = sqlOps.outputs.fullyQualifiedDomainName
output opsDatabaseName string = sqlOps.outputs.databaseName

output etlSqlServerFqdn string = sqlEtl.outputs.fullyQualifiedDomainName
output etlDatabaseName string = sqlEtl.outputs.databaseName

output storageAccountName string = storage.outputs.storageAccountName
output storageDfsEndpoint string = storage.outputs.dfsEndpoint
output storageContainerName string = storage.outputs.containerName

output sqlAdminLogin string = sqlAdminLogin
output sqlEntraAdminLogin string = effectiveAdminLogin
output sqlEntraAdminObjectId string = effectiveAdminObjectId

// Values needed to create the Fabric MANAGED virtual network data gateway.
output vnetName string = network.outputs.vnetName
output fabricGatewaySubnetName string = network.outputs.fabricGatewaySubnetName
