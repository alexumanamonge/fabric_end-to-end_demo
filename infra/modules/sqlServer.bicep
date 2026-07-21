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

@description('Client public IP to allow through the firewall (for the seeding script). Empty to skip.')
param clientIpAddress string = ''

@description('Resource tags.')
param tags object = {}

var hasClientIp = !empty(clientIpAddress)

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
    publicNetworkAccess: 'Enabled'
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

// Allow other Azure services (incl. Fabric) to reach the server.
resource allowAzure 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowAllAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Allow the operator's client IP so the seeding script can connect and load data.
resource allowClient 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = if (hasClientIp) {
  parent: sqlServer
  name: 'AllowClientIp'
  properties: {
    startIpAddress: clientIpAddress
    endIpAddress: clientIpAddress
  }
}

@description('SQL server resource name.')
output sqlServerName string = sqlServer.name

@description('Fully qualified domain name of the SQL server.')
output fullyQualifiedDomainName string = sqlServer.properties.fullyQualifiedDomainName

@description('Database name.')
output databaseName string = sqlDatabase.name

@description('System-assigned managed identity principal id of the server.')
output serverPrincipalId string = sqlServer.identity.principalId
