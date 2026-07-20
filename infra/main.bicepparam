using 'main.bicep'

// -------------------------------------------------------------------------
// Copy this file / edit values before deploying. Do NOT commit real secrets.
// Provide sqlAdminPassword at deploy time via env var or --parameters override,
// or wire it to Key Vault with getSecret(). See infra/README.md.
// -------------------------------------------------------------------------

param namePrefix = 'fabdemo'
param location = 'eastus2'

// Set your Entra ID user objectId + UPN to become the SQL AAD admin (recommended).
param aadAdminObjectId = ''
param aadAdminLogin = ''

// Set to your machine's public IP so the seeding script can connect.
param clientIpAddress = ''

// Password is intentionally NOT stored here. Pass it at deploy time, e.g.:
//   $securePwd read from env, passed via -p sqlAdminPassword=...
param sqlAdminPassword = readEnvironmentVariable('SQL_ADMIN_PASSWORD', '')
