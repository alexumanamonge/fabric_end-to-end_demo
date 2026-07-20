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

@description('SQL administrator login name.')
param administratorLogin string

@description('SQL administrator password.')
@secure()
param administratorLoginPassword string

@description('Entra ID (Azure AD) admin object id. Leave empty to skip AAD admin.')
param aadAdminObjectId string = ''

@description('Entra ID (Azure AD) admin display name / login.')
param aadAdminLogin string = ''

@description('SKU name for the database (e.g. GP_S_Gen5_2 serverless, or S0).')
param databaseSkuName string = 'GP_S_Gen5_2'

@description('SKU tier for the database.')
param databaseSkuTier string = 'GeneralPurpose'

@description('Client public IP to allow through the firewall (for the seeding script). Empty to skip.')
param clientIpAddress string = ''

@description('Resource tags.')
param tags object = {}

var hasAadAdmin = !empty(aadAdminObjectId)
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
    // Keep SQL auth enabled so the seeding script and Fabric connections can use it.
    administrators: hasAadAdmin ? {
      administratorType: 'ActiveDirectory'
      principalType: 'User'
      login: aadAdminLogin
      sid: aadAdminObjectId
      tenantId: subscription().tenantId
      azureADOnlyAuthentication: false
    } : null
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
