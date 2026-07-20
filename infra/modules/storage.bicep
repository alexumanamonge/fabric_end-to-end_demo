// ---------------------------------------------------------------------------
// Storage account (ADLS Gen2) used as the SHORTCUT source for the demo.
// A container holds reference files (regions) that OneLake virtualizes via a
// shortcut - no data copy required.
// ---------------------------------------------------------------------------

@description('Storage account name. Must be globally unique, 3-24 lowercase alphanumeric chars.')
param storageAccountName string

@description('Azure region for the storage account.')
param location string

@description('Blob container that holds the shortcut source files.')
param containerName string = 'reference'

@description('Resource tags applied to every resource.')
param tags object = {}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    // Hierarchical namespace = ADLS Gen2, required for OneLake ADLS shortcuts.
    isHnsEnabled: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
    networkAcls: {
      // Open for the demo so Fabric shortcuts and the seeding script can reach it.
      // Tighten with private endpoints / trusted services for production.
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: containerName
  properties: {
    publicAccess: 'None'
  }
}

@description('Storage account resource name.')
output storageAccountName string = storage.name

@description('DFS (ADLS Gen2) endpoint used when creating the OneLake shortcut.')
output dfsEndpoint string = storage.properties.primaryEndpoints.dfs

@description('Blob endpoint.')
output blobEndpoint string = storage.properties.primaryEndpoints.blob

@description('Container that holds the shortcut source files.')
output containerName string = container.name
