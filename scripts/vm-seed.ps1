<#
.SYNOPSIS
  Bootstrap seeding script run by the gateway VM's Custom Script Extension.

.DESCRIPTION
  Runs INSIDE the spoke VNet (on the gateway VM), so it can reach the Entra-only
  Azure SQL servers through their private endpoints. It:
    - authenticates as the user-assigned managed identity (the SQL Entra admin),
    - downloads the seed SQL + Shortcut file from the public repo raw URL,
    - seeds both databases with an Entra access token (Invoke-Sqlcmd -AccessToken),
    - grants the deploying user db_owner (SID-based, no Directory Reader needed),
    - uploads regions.csv to the (public) Shortcut storage container.

  Everything is wrapped in try/catch and the script ALWAYS exits 0 so a seeding
  hiccup never fails the VM/deployment. Progress is logged to C:\seed-log.txt.

.NOTES
  Invoked by infra/modules/gatewayVm.bicep. Not intended to be run by hand
  (though you can, on the VM, for a manual re-seed).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $UamiClientId,
  [Parameter(Mandatory)] [string] $OpsFqdn,
  [Parameter(Mandatory)] [string] $OpsDb,
  [Parameter(Mandatory)] [string] $EtlFqdn,
  [Parameter(Mandatory)] [string] $EtlDb,
  [string] $GrantObjectId = '',
  [string] $GrantUpn = '',
  [Parameter(Mandatory)] [string] $StorageAccount,
  [Parameter(Mandatory)] [string] $StorageKey,
  [Parameter(Mandatory)] [string] $Container,
  [Parameter(Mandatory)] [string] $SeedBaseUrl
)

$log = 'C:\seed-log.txt'
function Log($m) { "$(Get-Date -Format o)  $m" | Tee-Object -FilePath $log -Append }

try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $ProgressPreference = 'SilentlyContinue'
  $ErrorActionPreference = 'Stop'

  Log "Installing PowerShell modules (NuGet, Az.Accounts, Az.Storage, SqlServer)..."
  Install-PackageProvider -Name NuGet -Force -Scope AllUsers | Out-Null
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
  Install-Module Az.Accounts -Force -Scope AllUsers -AllowClobber | Out-Null
  Install-Module Az.Storage  -Force -Scope AllUsers -AllowClobber | Out-Null
  Install-Module SqlServer   -Force -Scope AllUsers -AllowClobber | Out-Null
  Import-Module Az.Accounts; Import-Module Az.Storage; Import-Module SqlServer

  Log "Connecting as managed identity $UamiClientId..."
  Connect-AzAccount -Identity -AccountId $UamiClientId | Out-Null
  # Az.Accounts 5.x+ returns the token as a SecureString; -AsSecureString works on
  # both old and new versions. Convert to plaintext for Invoke-Sqlcmd -AccessToken.
  $secureToken = (Get-AzAccessToken -ResourceUrl 'https://database.windows.net/' -AsSecureString).Token
  $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
             [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken))

  function Get-SeedFile([string] $rel) {
    $url = "$SeedBaseUrl/$rel"
    $out = Join-Path $env:TEMP ([System.IO.Path]::GetFileName($rel))
    Log "Downloading $url"
    Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
    return $out
  }

  $opsSql  = Get-SeedFile 'data/sql/ops_seed.sql'
  $etlSql  = Get-SeedFile 'data/sql/etl_seed.sql'
  $regions = Get-SeedFile 'data/blob/reference/regions/regions.csv'

  Log "Seeding $OpsDb on $OpsFqdn (private endpoint)..."
  Invoke-Sqlcmd -ServerInstance $OpsFqdn -Database $OpsDb -AccessToken $token `
    -InputFile $opsSql -TrustServerCertificate -QueryTimeout 300 -ConnectionTimeout 60

  Log "Seeding $EtlDb on $EtlFqdn (private endpoint)..."
  Invoke-Sqlcmd -ServerInstance $EtlFqdn -Database $EtlDb -AccessToken $token `
    -InputFile $etlSql -TrustServerCertificate -QueryTimeout 600 -ConnectionTimeout 60

  if ($GrantObjectId -and $GrantUpn) {
    $grant = @"
DECLARE @sid varbinary(16) = CAST(CAST('$GrantObjectId' AS uniqueidentifier) AS varbinary(16));
DECLARE @sidStr nvarchar(100) = CONVERT(nvarchar(100), @sid, 1);
DECLARE @upn sysname = N'$GrantUpn';
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @upn)
  EXEC('CREATE USER ' + QUOTENAME(@upn) + ' WITH SID = ' + @sidStr + ', TYPE = E;');
IF IS_ROLEMEMBER('db_owner', @upn) = 0
  EXEC('ALTER ROLE db_owner ADD MEMBER ' + QUOTENAME(@upn) + ';');
"@
    Log "Granting $GrantUpn db_owner on both databases..."
    Invoke-Sqlcmd -ServerInstance $OpsFqdn -Database $OpsDb -AccessToken $token -Query $grant -TrustServerCertificate -ConnectionTimeout 60
    Invoke-Sqlcmd -ServerInstance $EtlFqdn -Database $EtlDb -AccessToken $token -Query $grant -TrustServerCertificate -ConnectionTimeout 60
  }

  Log "Uploading regions.csv to $StorageAccount/$Container..."
  $ctx = New-AzStorageContext -StorageAccountName $StorageAccount -StorageAccountKey $StorageKey
  Set-AzStorageBlobContent -File $regions -Container $Container -Blob 'regions/regions.csv' -Context $ctx -Force | Out-Null

  Log "Seeding complete."
}
catch {
  Log "SEEDING ERROR: $($_.Exception.Message)"
  Log $_.ScriptStackTrace
}
finally {
  # Never fail the VM extension / deployment on a seeding issue.
  exit 0
}
