# Infrastructure (Bicep) — Azure source systems

This folder deploys the **external source systems** that feed the three Fabric
ingestion patterns in the demo. Fabric capacity and workspace are created
manually by you (see [`../docs/fabric-workspace-setup.md`](../docs/fabric-workspace-setup.md)).

## What gets deployed

**Workload resource group** (`rg-fabric-e2e-demo` by default):

| Resource | Bicep name | Role in the demo | Feeds |
|---|---|---|---|
| User-assigned managed identity | `identity` | SQL Entra admin + seed identity | — |
| Azure SQL DB `sqldb-ops` (private) | `sqlOps` | Operational master data | **Mirroring** → customers, products |
| Storage account (ADLS Gen2, **public**) | `storage` | Reference file landing zone | **Shortcut** → regions |
| Azure SQL DB `sqldb-etl` (private) | `sqlEtl` | Transactional system of record | **ETL / Copy Job** → orders, support_tickets |

**Networking resource group** (`rg-fabric-e2e-network` by default; hub-spoke —
hub + peering are out of scope):

| Resource | Bicep name | Role |
|---|---|---|
| Spoke VNet + subnets | `network` | `snet-privatelink` (PEs) + `snet-gateway` (VM). |
| Private DNS zone `privatelink.database.windows.net` | `network` | Resolves SQL FQDNs to private IPs inside the VNet. |
| Private endpoints `pe-sql-ops` / `pe-sql-etl` | `peOps` / `peEtl` | Private connectivity to the two SQL servers. |
| Gateway VM (+ NIC, NSG, public IP) | `gatewayVm` | Hosts the on-prem data gateway; runs the seed from inside the VNet. |

Both resource groups are **created for you** by the subscription-scoped template;
rename them (and any resource) freely.

## One-click deploy (portal)

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Falexumanamonge%2Ffabric_end-to-end_demo%2Fmain%2Finfra%2Fazuredeploy.json)

The button loads [`azuredeploy.json`](azuredeploy.json) (the ARM template compiled
from `main.bicep`) into the Azure portal. Pick a region — **no password is
required**; all other parameters have sensible defaults.

**Authentication (Entra ID-only).** To satisfy the org policy *"Azure SQL Server
Instances cannot be created unless Entra ID only authentication is enabled"*, both
SQL servers are created with `azureADOnlyAuthentication: true` (SQL logins
disabled). A **user-assigned managed identity** (`modules/identity.bicep`) is
created and set as the single SQL Entra admin; the seed runs as that identity and
connects with an Entra access token (`Invoke-Sqlcmd -AccessToken`). Optionally set
`aadAdminObjectId` (your Entra objectId) + `aadAdminLogin` (your UPN) to be granted
`db_owner` on both databases (a SID-based `CREATE USER`, so no Directory Reader
role is needed). `sqlAdminLogin` / `sqlAdminPassword` still exist for ARM API
compatibility but are **never usable** (local auth is off); the password has a
generated default so no input is required.

**Networking (private SQL).** A second org policy denies SQL servers with a public
endpoint (`DenyPublicEndpointEnabled`). So both servers set
`publicNetworkAccess: 'Disabled'` and have **no firewall rules**; they are reached
only through **private endpoints** in the spoke VNet. Because Fabric is a public
SaaS service, a Windows **VNet data gateway VM** in the spoke lets Fabric reach the
private endpoints (install the on-prem data gateway on it — MANUAL). The **storage
account keeps its public endpoint**. Full walkthrough:
[`../docs/networking-gateway.md`](../docs/networking-gateway.md).

**Notes**
- This is a **subscription-scoped** template — it creates **both** resource groups
  for you. The resource-group names and every resource name are **parameters** with
  sensible defaults, so you can customize them at deploy time.
- **Automated seeding is on by default** (`seedData = true`): the gateway VM's
  Custom Script Extension runs [`../scripts/vm-seed.ps1`](../scripts/vm-seed.ps1)
  from inside the VNet — it authenticates as the managed identity, loads both SQL
  databases over the private endpoints with `Invoke-Sqlcmd -AccessToken`, grants
  you `db_owner`, and uploads `regions.csv`. The extension always exits 0, so a
  seeding issue never fails the deployment (check `C:\seed-log.txt` on the VM). Set
  `seedData = false` to skip.
- Because the seed pulls files over the public raw URL, the repo must stay
  **public** for automated seeding — or point `seedSourceUrl` at your own raw host.
- **Regenerating the template:** if you change the Bicep, recompile with
  `az bicep build --file infra\main.bicep --outfile infra\azuredeploy.json` and
  commit the result so the button stays in sync.

### Key parameters

| Parameter | Default | Purpose |
|---|---|---|
| `resourceGroupName` | `rg-fabric-e2e-demo` | Resource group to create (any valid name). |
| `opsSqlServerName` / `opsDatabaseName` | unique `sql-ops-…` / `sqldb-ops` | Mirroring source (override with any name). |
| `etlSqlServerName` / `etlDatabaseName` | unique `sql-etl-…` / `sqldb-etl` | Copy Job source (override with any name). |
| `storageAccountName` / `containerName` | unique `stfabric…` / `reference` | Shortcut source (override with any name). |
| `seedIdentityName` | unique `id-fabric-seed-…` | Managed identity used as SQL Entra admin + seed runtime. |
| `aadAdminObjectId` / `aadAdminLogin` | *(empty)* | Your Entra objectId + UPN, granted `db_owner`. |
| `networkResourceGroupName` | `rg-fabric-e2e-network` | Networking RG (spoke VNet, PEs, gateway VM). |
| `vnetAddressPrefix` / `privateEndpointSubnetPrefix` / `gatewaySubnetPrefix` | `10.20.0.0/16` / `10.20.1.0/24` / `10.20.2.0/24` | Spoke VNet + subnet ranges. |
| `gatewayVmSize` / `vmAdminUsername` / `vmAdminPassword` | `Standard_D2s_v3` / `fabricadmin` / *(generated)* | Gateway VM. Reset the password in the portal to RDP. |
| `clientIpAddress` | *(empty)* | Your public IP, allowed to RDP (3389) the gateway VM. |
| `seedData` | `true` | Run the gateway-VM seed extension. |
| `seedSourceUrl` | repo `main` raw URL | Where the seed step downloads files from. |

## Files

| File | Purpose |
|---|---|
| `main.bicep` | Subscription-scoped entry point; creates both RGs + all resources. |
| `modules/identity.bicep` | User-assigned managed identity: SQL Entra admin + seed runtime. |
| `modules/sqlServer.bicep` | Azure SQL logical server + database (Entra-only, public access disabled). |
| `modules/storage.bicep` | ADLS Gen2 storage account + container (public) for the shortcut source. |
| `modules/network.bicep` | Spoke VNet + subnets + SQL private DNS zone + link. |
| `modules/privateEndpoint.bicep` | Private endpoint + DNS zone group for one SQL server (called twice). |
| `modules/gatewayVm.bicep` | Windows gateway VM (+ NIC/NSG/PIP) + seed Custom Script Extension. |
| `main.bicepparam` | Optional parameter values (all optional; no secrets). |
| `azuredeploy.json` | ARM template compiled from `main.bicep` — powers the **Deploy to Azure** button. |

## Prerequisites

- Azure CLI ≥ 2.86 and Bicep ≥ 0.41 (`az bicep version`).
- Rights to create resource groups + resources in the target subscription.
- Only for a **manual re-seed on the gateway VM** (`Seed-Data.ps1` / `vm-seed.ps1`):
  the PowerShell `SqlServer` module. The automated seed installs it on the VM.

## Deploy

Use the wrapper script (recommended — it also seeds data):

```powershell
..\scripts\Deploy-Azure.ps1 -ResourceGroupName rg-fabric-e2e-demo `
  -NetworkResourceGroupName rg-fabric-e2e-network -Location eastus2
```

Or deploy the Bicep directly (no password — Entra-only auth):

```powershell
# (Recommended) capture your objectId + UPN (db_owner grant) and public IP (VM RDP)
$objectId = az ad signed-in-user show --query id -o tsv
$upn      = az ad signed-in-user show --query userPrincipalName -o tsv
$myIp     = (Invoke-RestMethod https://api.ipify.org)

# Deploy at subscription scope (creates both resource groups)
az deployment sub create `
  --name fabric-demo-source `
  --location eastus2 `
  --template-file main.bicep `
  --parameters main.bicepparam `
  --parameters aadAdminObjectId=$objectId `
               aadAdminLogin=$upn `
               clientIpAddress=$myIp
```

Read outputs (used by the Fabric setup docs and the seeding script):

```powershell
az deployment sub show --name fabric-demo-source --query properties.outputs
```

## Cost & sizing

- Both SQL databases default to **serverless General Purpose** (`GP_S_Gen5_2`),
  which auto-pauses when idle to minimize cost. Override with `databaseSkuName`
  (e.g. `S0`) in `main.bicepparam` if serverless is not available in your region.
- Storage is `Standard_LRS`, Hot tier.
- The **gateway VM** (`Standard_D2s_v3`, ~2 vCPU/8 GB) runs continuously — stop or
  deallocate it when not demoing to save cost, and start it before using Fabric
  ingestion (the on-prem gateway must be running).

## Teardown

```powershell
..\scripts\Teardown-Azure.ps1 -ResourceGroupName rg-fabric-e2e-demo `
  -NetworkResourceGroupName rg-fabric-e2e-network
# or (delete both resource groups)
az group delete --name rg-fabric-e2e-network --yes --no-wait
az group delete --name rg-fabric-e2e-demo --yes --no-wait
```

## Variant: real Azure SQL Managed Instance

The demo uses a second **Azure SQL Database** (`sqldb-etl`) in place of a SQL
Managed Instance so the environment is fast (minutes) and cheap to deploy. The
ingestion story is identical — a pipeline **Copy activity** batch-loads
`orders` and `support_tickets` into the Bronze Lakehouse.

To use a **real SQL MI** instead:

1. Deploy a SQL MI (allow **4–6 hours**; ~$700+/month even at the smallest
   General Purpose tier). A starter module is out of scope here because MI also
   requires a dedicated VNet/subnet, route table, and NSG.
2. Point the seeding script's `-EtlServer` / `-EtlDatabase` parameters at the MI
   endpoint (`<mi-name>.<dns-zone>.database.windows.net`).
3. In Fabric, create the Copy Job / pipeline connection against the MI endpoint
   exactly as documented in
   [`../docs/ingestion-etl-copyjob.md`](../docs/ingestion-etl-copyjob.md).

No notebook or medallion logic changes are required — only the connection target.
