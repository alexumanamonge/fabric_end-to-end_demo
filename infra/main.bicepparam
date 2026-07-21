using 'main.bicep'

// -------------------------------------------------------------------------
// Optional parameter file. All resource names have collision-safe defaults in
// main.bicep, so you can deploy with NO parameters. Override any you like here.
//
// Authentication is Microsoft Entra ID-only (no SQL password) AND the SQL servers
// are private-endpoint-only (public network access disabled). A spoke VNet,
// private endpoints, and a "VNet data gateway" VM are deployed to a SEPARATE
// networking resource group (hub + peering are out of scope). The in-VNet gateway
// VM runs the seed and lets Fabric reach the private SQL endpoints.
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
// param seedIdentityName   = 'id-fabric-seed-contoso'

// Spoke networking (hub + peering are out of scope for this template).
// param vnetName                     = 'vnet-fabric-spoke'
// param vnetAddressPrefix            = '10.20.0.0/16'
// param privateEndpointSubnetPrefix  = '10.20.1.0/24'
// param gatewaySubnetPrefix          = '10.20.2.0/24'

// Gateway VM (Fabric reaches private SQL through the on-prem data gateway on it).
// param gatewayVmName  = 'vm-fabric-gw'
// param gatewayVmSize  = 'Standard_D2s_v3'
// param vmAdminUsername = 'fabricadmin'
// vmAdminPassword has a generated default; reset in the portal to RDP the VM.

// Set your Entra ID user objectId + UPN to be granted db_owner on both databases
// (so you can query / configure Fabric mirroring). Leave empty to skip the grant.
param aadAdminObjectId = ''
param aadAdminLogin = ''

// Set to your machine's public IP to allow RDP (3389) to the gateway VM.
param clientIpAddress = ''

