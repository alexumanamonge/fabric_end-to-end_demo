// ---------------------------------------------------------------------------
// Azure SQL logical server + single database.
// Instantiated twice by main.bicep:
//   - sqldb-ops : source for Fabric MIRRORING (customers, products)
//   - sqldb-etl : source for Fabric ETL / Copy Job (orders, support_tickets)
//                 (stands in for SQL Managed Instance - see infra/README.md)
// ---------------------------------------------------------------------------

@description('Logical SQL server name. Must be globally unique.')
param sqlServerName string

@description('Database name to create on the server.')
param databaseName string

@description('Azure region.')
param location string

@description('SQL administrator login. Local auth is DISABLED (Entra-only) but a login is kept for API compatibility.')
param administratorLogin string

@description('SQL administrator password. Never used - local auth is disabled - but kept for API compatibility.')
@secure()
param administratorLoginPassword string

@description('Microsoft Entra admin object id (sid) for the server. Required (Entra-only auth).')
param aadAdminObjectId string

@description('Microsoft Entra admin login / display name.')
param aadAdminLogin string

@description('Entra principal type of the admin: User, Group, or Application (managed identity = Application).')
@allowed([
  'User'
  'Group'
  'Application'
])
param aadAdminPrincipalType string = 'Application'

@description('SKU name for the database (e.g. GP_S_Gen5_2 serverless, or S0).')
param databaseSkuName string = 'GP_S_Gen5_2'

@description('SKU tier for the database.')
param databaseSkuTier string = 'GeneralPurpose'

@description('Resource tags.')
param tags object = {}

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  identity: {
    // System-assigned managed identity - useful for Fabric mirroring scenarios.
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    // Public network access is DISABLED to satisfy org policy; the server is
    // reached only through its private endpoint (see infra/modules/network.bicep
    // + privateEndpoint.bicep). No firewall rules are created (they are denied
    // when the public endpoint is disabled).
    publicNetworkAccess: 'Disabled'
    // Microsoft Entra-only authentication (SQL auth disabled) to satisfy org policy.
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: aadAdminPrincipalType
      login: aadAdminLogin
      sid: aadAdminObjectId
      tenantId: subscription().tenantId
      azureADOnlyAuthentication: true
    }
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: databaseName
  location: location
  tags: tags
  sku: {
    name: databaseSkuName
    tier: databaseSkuTier
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    // System Versioning / CDC-friendly defaults; mirroring reads the change feed.
    zoneRedundant: false
    readScale: 'Disabled'
  }
}

@description('SQL server resource id (used to create the private endpoint).')
output sqlServerId string = sqlServer.id

@description('SQL server resource name.')
output sqlServerName string = sqlServer.name

@description('Fully qualified domain name of the SQL server.')
output fullyQualifiedDomainName string = sqlServer.properties.fullyQualifiedDomainName

@description('Database name.')
output databaseName string = sqlDatabase.name

@description('System-assigned managed identity principal id of the server.')
output serverPrincipalId string = sqlServer.identity.principalId
