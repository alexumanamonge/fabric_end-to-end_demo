// ---------------------------------------------------------------------------
// Spoke virtual network for the Fabric demo (hub-spoke; hub + peering are OUT of
// scope for this template). Deployed into the dedicated networking resource group.
//   - snet-privatelink    : holds the SQL private endpoints (network policies off).
//   - snet-fabric-gateway : DELEGATED to Microsoft.PowerPlatform/vnetaccesslinks
//                           so Fabric can inject its MANAGED virtual network data
//                           gateway here. Fabric creates the gateway itself - this
//                           template only wires up (and delegates) the subnet.
//   - Private DNS zone privatelink.database.windows.net + a link to this VNet so
//     the SQL FQDNs resolve to their private-endpoint IPs from inside the spoke
//     (the managed gateway lives in the spoke, so it resolves them automatically).
// ---------------------------------------------------------------------------

@description('Name of the spoke virtual network.')
param vnetName string

@description('Azure region.')
param location string

@description('Address space for the spoke VNet.')
param vnetAddressPrefix string = '10.20.0.0/16'

@description('Subnet for the SQL private endpoints.')
param privateEndpointSubnetPrefix string = '10.20.1.0/24'

@description('Subnet delegated to Fabric for the managed virtual network data gateway.')
param fabricGatewaySubnetPrefix string = '10.20.2.0/24'

@description('Resource tags.')
param tags object = {}

var privateEndpointSubnetName = 'snet-privatelink'
var fabricGatewaySubnetName = 'snet-fabric-gateway'
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
        // Dedicated, delegated subnet for the Fabric MANAGED VNet data gateway.
        // Fabric provisions the gateway into this subnet when you create a
        // "Virtual network data gateway" in the Fabric/Power BI admin portal.
        name: fabricGatewaySubnetName
        properties: {
          addressPrefix: fabricGatewaySubnetPrefix
          delegations: [
            {
              name: 'Microsoft.PowerPlatform.vnetaccesslinks'
              properties: {
                serviceName: 'Microsoft.PowerPlatform/vnetaccesslinks'
              }
            }
          ]
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

@description('Name of the spoke VNet.')
output vnetName string = vnet.name

@description('Resource id of the private-endpoint subnet.')
output privateEndpointSubnetId string = '${vnet.id}/subnets/${privateEndpointSubnetName}'

@description('Resource id of the Fabric-delegated gateway subnet.')
output fabricGatewaySubnetId string = '${vnet.id}/subnets/${fabricGatewaySubnetName}'

@description('Name of the Fabric-delegated gateway subnet (select this in the Fabric VNet data gateway wizard).')
output fabricGatewaySubnetName string = fabricGatewaySubnetName

@description('Resource id of the SQL private DNS zone.')
output sqlPrivateDnsZoneId string = sqlDnsZone.id
