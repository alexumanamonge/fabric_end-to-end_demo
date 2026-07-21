// ---------------------------------------------------------------------------
// VNet data gateway VM (Windows) in the spoke gateway subnet. Fabric uses an
// on-premises data gateway installed on this VM (MANUAL, one-time) to reach the
// Entra-only Azure SQL servers over their private endpoints.
//
// The VM also runs the demo SEED as a Custom Script Extension (when seedData is
// true): it is the only compute inside the VNet, so it can reach the private SQL
// endpoints. It authenticates as the user-assigned managed identity (the SQL
// Entra admin) and loads both databases + uploads the Shortcut file.
// Deployed into the networking resource group.
// ---------------------------------------------------------------------------

@description('Name of the gateway VM.')
param vmName string

@description('Azure region.')
param location string

@description('Resource id of the gateway subnet.')
param subnetId string

@description('Resource id of the user-assigned managed identity (the SQL Entra admin).')
param uamiId string

@description('Client id of the user-assigned managed identity (for the seed login).')
param uamiClientId string

@description('VM administrator username.')
param adminUsername string = 'fabricadmin'

@description('VM administrator password. Generated default so no input is required; reset in the portal if you need to RDP.')
@secure()
param adminPassword string

@description('VM size.')
param vmSize string = 'Standard_D2s_v3'

@description('Public IP to allow RDP (3389) from. Empty = no inbound RDP rule (use Bastion / add later).')
param clientIpAddress string = ''

// --- Seed inputs ------------------------------------------------------------
@description('Run the seed Custom Script Extension.')
param seedData bool = true

@description('Workload resource group that holds the seed storage account (for the account key).')
param storageResourceGroupName string

@description('Storage account holding the Shortcut source files.')
param storageAccountName string

@description('Shortcut blob container.')
param containerName string

@description('FQDN of the operational SQL server.')
param opsSqlServerFqdn string

@description('Operational database name.')
param opsDatabaseName string

@description('FQDN of the ETL SQL server.')
param etlSqlServerFqdn string

@description('ETL database name.')
param etlDatabaseName string

@description('Object id of the deploying user to grant db_owner. Empty to skip.')
param grantObjectId string = ''

@description('UPN of the deploying user to grant db_owner. Empty to skip.')
param grantLogin string = ''

@description('Base raw URL to download the seed files + bootstrap script from.')
param seedSourceUrl string

@description('Token that forces the seed extension to re-run on each deployment.')
param seedForceUpdateTag string = ''

@description('Resource tags.')
param tags object = {}

var hasClientIp = !empty(clientIpAddress)

// Cross-RG reference to the (public) seed storage account to read its key.
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
  scope: resourceGroup(storageResourceGroupName)
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: '${vmName}-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: hasClientIp ? [
      {
        name: 'Allow-RDP-From-Client'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: clientIpAddress
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ] : []
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: '${vmName}-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${vmName}-nic'
  location: location
  tags: tags
  properties: {
    networkSecurityGroup: {
      id: nsg.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: take(vmName, 15)
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// Seed the demo data from inside the VNet (reaches private SQL). Always exits 0.
resource seedExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = if (seedData) {
  parent: vm
  name: 'seed-demo-data'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    forceUpdateTag: seedForceUpdateTag
    settings: {
      fileUris: [
        '${seedSourceUrl}/scripts/vm-seed.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -NoProfile -File vm-seed.ps1 -UamiClientId "${uamiClientId}" -OpsFqdn "${opsSqlServerFqdn}" -OpsDb "${opsDatabaseName}" -EtlFqdn "${etlSqlServerFqdn}" -EtlDb "${etlDatabaseName}" -GrantObjectId "${grantObjectId}" -GrantUpn "${grantLogin}" -StorageAccount "${storageAccountName}" -StorageKey "${storage.listKeys().keys[0].value}" -Container "${containerName}" -SeedBaseUrl "${seedSourceUrl}"'
    }
  }
}

@description('Gateway VM resource name.')
output vmName string = vm.name

@description('Public IP address of the gateway VM (for RDP / gateway install).')
output publicIpAddress string = publicIp.properties.ipAddress

@description('Private IP of the gateway VM NIC.')
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
