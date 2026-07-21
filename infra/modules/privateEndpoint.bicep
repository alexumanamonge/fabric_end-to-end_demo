// ---------------------------------------------------------------------------
// Private endpoint for an Azure SQL logical server, plus a private DNS zone group
// so the server FQDN resolves to the private IP. Deployed into the networking RG
// (same RG as the spoke VNet / DNS zone). Called once per SQL server.
// ---------------------------------------------------------------------------

@description('Name of the private endpoint.')
param name string

@description('Azure region.')
param location string

@description('Resource id of the subnet that hosts the private endpoint.')
param subnetId string

@description('Resource id of the target Azure SQL logical server.')
param sqlServerId string

@description('Resource id of the SQL private DNS zone (privatelink.database.windows.net).')
param sqlPrivateDnsZoneId string

@description('Resource tags.')
param tags object = {}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-conn'
        properties: {
          privateLinkServiceId: sqlServerId
          groupIds: [ 'sqlServer' ]
        }
      }
    ]
  }
}

resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sql'
        properties: {
          privateDnsZoneId: sqlPrivateDnsZoneId
        }
      }
    ]
  }
}

@description('Resource id of the private endpoint.')
output privateEndpointId string = privateEndpoint.id
