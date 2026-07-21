using 'main.bicep'

// -------------------------------------------------------------------------
// Optional parameter file. All resource names have collision-safe defaults in
// main.bicep, so you can deploy with NO parameters. Override any you like here.
//
// Authentication is Microsoft Entra ID-only (no SQL password) AND the SQL servers
// are private-endpoint-only (public network access disabled). A spoke VNet,
// private endpoints, and a subnet DELEGATED to Fabric (for the managed virtual
// network data gateway) are deployed to a SEPARATE networking resource group
// (hub + peering are out of scope). No VM/ACI is deployed - Fabric provisions its
// own managed gateway into the delegated subnet, and you seed the databases from
// Fabric with your own account (you are set as the SQL Entra admin).
// -------------------------------------------------------------------------

param location = 'eastus2'

// Resource groups (both are created for you).
param resourceGroupName = 'rg-fabric-e2e-demo'
param networkResourceGroupName = 'rg-fabric-e2e-network'

// Name every resource however you like (defaults in main.bicep are collision-safe).
// param opsSqlServerName   = 'sql-contoso-ops'
// param etlSqlServerName   = 'sql-contoso-etl'
// param storageAccountName = 'stcontosoref01'
// param opsDatabaseName    = 'sqldb-ops'
// param etlDatabaseName    = 'sqldb-etl'
// param containerName      = 'reference'

// Spoke networking (hub + peering are out of scope for this template).
// param vnetName                     = 'vnet-fabric-spoke'
// param vnetAddressPrefix            = '10.20.0.0/16'
// param privateEndpointSubnetPrefix  = '10.20.1.0/24'
// param fabricGatewaySubnetPrefix    = '10.20.2.0/24'

// SQL Entra admin. Leave empty to use the DEPLOYING USER (recommended) so you can
// seed the databases from Fabric with your own account. Override to set a Group
// (aadAdminPrincipalType='Group') or service principal ('Application').
param aadAdminObjectId = ''
param aadAdminLogin = ''
// param aadAdminPrincipalType = 'User'
