// ---------------------------------------------------------------------------
// Spoke virtual network for the Fabric demo (hub-spoke; hub + peering are OUT of
// scope for this template). Deployed into the dedicated networking resource group.
//   - snet-privatelink : holds the SQL private endpoints (network policies off).
//   - snet-gateway     : holds the VNet data gateway VM that Fabric uses to reach
//                        the private SQL endpoints.
//   - Private DNS zone privatelink.database.windows.net + a link to this VNet so
//     the SQL FQDNs resolve to their private-endpoint IPs from inside the spoke.
// ---------------------------------------------------------------------------

@description('Name of the spoke virtual network.')
param vnetName string

@description('Azure region.')
param location string

@description('Address space for the spoke VNet.')
param vnetAddressPrefix string = '10.20.0.0/16'

@description('Subnet for the SQL private endpoints.')
param privateEndpointSubnetPrefix string = '10.20.1.0/24'

@description('Subnet for the VNet data gateway VM.')
param gatewaySubnetPrefix string = '10.20.2.0/24'

@description('Resource tags.')
param tags object = {}

var privateEndpointSubnetName = 'snet-privatelink'
var gatewaySubnetName = 'snet-gateway'
var sqlPrivateDnsZoneName = 'privatelink${environment().suffixes.sqlServerHostname}'

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [ vnetAddressPrefix ]
    }
    subnets: [
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: gatewaySubnetName
        properties: {
          addressPrefix: gatewaySubnetPrefix
        }
      }
    ]
  }
}

// Private DNS zone for Azure SQL private link.
resource sqlDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: sqlPrivateDnsZoneName
  location: 'global'
  tags: tags
}

resource sqlDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: sqlDnsZone
  name: '${vnetName}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

@description('Resource id of the spoke VNet.')
output vnetId string = vnet.id

@description('Resource id of the private-endpoint subnet.')
output privateEndpointSubnetId string = '${vnet.id}/subnets/${privateEndpointSubnetName}'

@description('Resource id of the gateway VM subnet.')
output gatewaySubnetId string = '${vnet.id}/subnets/${gatewaySubnetName}'

@description('Resource id of the SQL private DNS zone.')
output sqlPrivateDnsZoneId string = sqlDnsZone.id
