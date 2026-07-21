using 'main.bicep'

// -------------------------------------------------------------------------
// Optional parameter file. All resource names have collision-safe defaults in
// main.bicep, so you can deploy with NO parameters. Override any you like here.
//
// Authentication is Microsoft Entra ID-only - there is NO SQL password to set.
// A user-assigned managed identity is created automatically and made the SQL
// Entra admin; the in-template seed script authenticates with an Entra token.
// -------------------------------------------------------------------------

param location = 'eastus2'

// Name every resource however you like (defaults in main.bicep are collision-safe).
param resourceGroupName = 'rg-fabric-e2e-demo'
// param opsSqlServerName   = 'sql-contoso-ops'
// param etlSqlServerName   = 'sql-contoso-etl'
// param storageAccountName = 'stcontosoref01'
// param opsDatabaseName    = 'sqldb-ops'
// param etlDatabaseName    = 'sqldb-etl'
// param containerName      = 'reference'
// param seedIdentityName   = 'id-fabric-seed-contoso'

// Set your Entra ID user objectId + UPN to be granted db_owner on both databases
// (so you can query / configure Fabric mirroring). Leave empty to skip the grant.
param aadAdminObjectId = ''
param aadAdminLogin = ''

// Set to your machine's public IP so a local re-seed (Seed-Data.ps1) can connect.
// The in-template seed reaches SQL via the AllowAllAzureServices firewall rule.
param clientIpAddress = ''
