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
// A Windows "VNet data gateway" VM in the spoke lets Fabric reach the private
// SQL endpoints and also runs the demo seed from inside the VNet. The hub VNet
// and VNet peering are OUT OF SCOPE for this template.
//
// Subscription-scoped so a single deployment creates both resource groups and
// all resources. Fabric capacity + workspace are created manually by the user.
// ===========================================================================

targetScope = 'subscription'

@description('Azure region for all resources.')
param location string = 'eastus2'

@description('Name of the workload resource group to create (SQL, storage, identity). Use any name allowed by Azure.')
param resourceGroupName string = 'rg-fabric-e2e-demo'

@description('Name of the NETWORKING resource group to create (spoke VNet, private endpoints, gateway VM). Hub-spoke: hub + peering are out of scope.')
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

@description('Name of the user-assigned managed identity that acts as the SQL Entra admin and runs the seed script. Default is collision-safe.')
param seedIdentityName string = 'id-fabric-seed-${uniqueString(subscription().subscriptionId, resourceGroupName)}'

@description('Automatically seed the SQL databases and upload the Shortcut file as part of the deployment (runs a deployment script). Set false to seed later with scripts/Seed-Data.ps1.')
param seedData bool = true

@description('Base raw URL the automated seed step downloads seed files from (data/sql/*.sql, data/blob/reference/regions/regions.csv).')
param seedSourceUrl string = 'https://raw.githubusercontent.com/alexumanamonge/fabric_end-to-end_demo/main'

@description('Unique token that forces the seed deployment script to re-run on each deployment.')
param seedForceUpdateTag string = utcNow()

@description('SQL administrator login. Local auth is DISABLED (Entra-only); kept only for ARM API compatibility.')
param sqlAdminLogin string = 'fabricadmin'

@description('SQL administrator password. Never used (Entra-only auth); has a generated default so no input is required. Kept for ARM API compatibility.')
@secure()
param sqlAdminPassword string = 'P${uniqueString(subscription().subscriptionId, resourceGroupName, 'sqlpwd')}q!7Z'

@description('Object id of the deploying user (your Entra objectId) to grant db_owner on both databases. Empty to skip the grant.')
param aadAdminObjectId string = ''

@description('UPN / login of the deploying user, used for the db_owner grant. Empty to skip the grant.')
param aadAdminLogin string = ''

// --- Networking (spoke) -----------------------------------------------------
@description('Name of the spoke virtual network to create in the networking RG.')
param vnetName string = 'vnet-fabric-spoke'

@description('Address space for the spoke VNet.')
param vnetAddressPrefix string = '10.20.0.0/16'

@description('Subnet prefix for the SQL private endpoints.')
param privateEndpointSubnetPrefix string = '10.20.1.0/24'

@description('Subnet prefix for the VNet data gateway VM.')
param gatewaySubnetPrefix string = '10.20.2.0/24'

@description('Name of the private endpoint for the operational SQL server.')
param opsPrivateEndpointName string = 'pe-sql-ops'

@description('Name of the private endpoint for the ETL SQL server.')
param etlPrivateEndpointName string = 'pe-sql-etl'

// --- Gateway VM -------------------------------------------------------------
@description('Name of the VNet data gateway VM.')
param gatewayVmName string = 'vm-fabric-gw'

@description('Gateway VM size.')
param gatewayVmSize string = 'Standard_D2s_v3'

@description('Gateway VM administrator username.')
param vmAdminUsername string = 'fabricadmin'

@description('Gateway VM administrator password. Generated default so no input is required; reset in the portal to RDP and install the data gateway.')
@secure()
param vmAdminPassword string = 'Gw!${uniqueString(subscription().subscriptionId, networkResourceGroupName, 'vmpwd')}Aa9'

@description('Your public IP, allowed to RDP (3389) to the gateway VM. Empty = no inbound RDP rule (use Bastion / add later).')
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

resource rgNet 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: networkResourceGroupName
  location: location
  tags: tags
}

// --- User-assigned managed identity -----------------------------------------
// Acts as the single Entra admin on both SQL servers (Entra-only auth) AND as
// the runtime identity of the seed deployment script, so seeding needs no
// SQL password - it authenticates with an Entra access token.
module identity 'modules/identity.bicep' = {
  scope: rg
  name: 'seedIdentity'
  params: {
    name: seedIdentityName
    location: location
    tags: tags
  }
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
    aadAdminObjectId: identity.outputs.principalId
    aadAdminLogin: identity.outputs.name
    aadAdminPrincipalType: 'Application'
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
    aadAdminObjectId: identity.outputs.principalId
    aadAdminLogin: identity.outputs.name
    aadAdminPrincipalType: 'Application'
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
    gatewaySubnetPrefix: gatewaySubnetPrefix
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

// --- VNet data gateway VM (networking RG) ------------------------------------
// Fabric reaches the private SQL endpoints via an on-prem data gateway installed
// on this VM (MANUAL). It also runs the demo seed from inside the VNet when
// seedData=true (depends on the private endpoints being ready so DNS resolves).
module gatewayVm 'modules/gatewayVm.bicep' = {
  scope: rgNet
  name: 'gatewayVm'
  dependsOn: [
    peOps
    peEtl
  ]
  params: {
    vmName: gatewayVmName
    location: location
    subnetId: network.outputs.gatewaySubnetId
    uamiId: identity.outputs.id
    uamiClientId: identity.outputs.clientId
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
    vmSize: gatewayVmSize
    clientIpAddress: clientIpAddress
    seedData: seedData
    storageResourceGroupName: resourceGroupName
    storageAccountName: storage.outputs.storageAccountName
    containerName: storage.outputs.containerName
    opsSqlServerFqdn: sqlOps.outputs.fullyQualifiedDomainName
    opsDatabaseName: sqlOps.outputs.databaseName
    etlSqlServerFqdn: sqlEtl.outputs.fullyQualifiedDomainName
    etlDatabaseName: sqlEtl.outputs.databaseName
    grantObjectId: aadAdminObjectId
    grantLogin: aadAdminLogin
    seedSourceUrl: seedSourceUrl
    seedForceUpdateTag: seedForceUpdateTag
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

output seedIdentityName string = identity.outputs.name
output seedIdentityPrincipalId string = identity.outputs.principalId

output vnetName string = vnetName
output gatewayVmName string = gatewayVm.outputs.vmName
output gatewayVmPublicIp string = gatewayVm.outputs.publicIpAddress
output gatewayVmPrivateIp string = gatewayVm.outputs.privateIpAddress
output vmAdminUsername string = vmAdminUsername
