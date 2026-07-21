// ---------------------------------------------------------------------------
// User-assigned managed identity used as:
//   1. the Microsoft Entra administrator on both SQL servers, and
//   2. the runtime identity of the seeding deployment script.
// This lets the (non-interactive) seed step authenticate to Entra-only SQL with
// an access token - no SQL password anywhere.
// ---------------------------------------------------------------------------

@description('Name of the user-assigned managed identity.')
param name string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object = {}

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

@description('Resource id of the managed identity.')
output id string = uami.id

@description('Principal (object) id - used as the SQL Entra admin sid.')
output principalId string = uami.properties.principalId

@description('Client id of the managed identity.')
output clientId string = uami.properties.clientId

@description('Name of the managed identity - used as the SQL Entra admin login.')
output name string = uami.name
