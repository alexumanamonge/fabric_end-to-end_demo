# Infrastructure (Bicep) — Azure source systems

This folder deploys the **external source systems** that feed the three Fabric
ingestion patterns in the demo. Fabric capacity and workspace are created
manually by you (see [`../docs/fabric-workspace-setup.md`](../docs/fabric-workspace-setup.md)).

## What gets deployed

**Workload resource group** (`rg-fabric-e2e-demo` by default):

| Resource | Bicep name | Role in the demo | Feeds |
|---|---|---|---|
| Azure SQL DB `sqldb-ops` (private) | `sqlOps` | Operational master data | **Mirroring** → customers, products |
| Storage account (ADLS Gen2, **public**) | `storage` | Reference file landing zone | **Shortcut** → regions |
| Azure SQL DB `sqldb-etl` (private) | `sqlEtl` | Transactional system of record | **ETL / Copy Job** → orders, support_tickets |

The **deploying user** is set as the Microsoft Entra admin on both SQL servers, so
you can seed them from Fabric with your own account (no managed identity, no VM).

**Networking resource group** (`rg-fabric-e2e-network` by default; hub-spoke —
hub + peering are out of scope):

| Resource | Bicep name | Role |
|---|---|---|
| Spoke VNet + subnets | `network` | `snet-privatelink` (PEs) + `snet-fabric-gateway` (**delegated** to `Microsoft.PowerPlatform/vnetaccesslinks`). |
| Private DNS zone `privatelink.database.windows.net` | `network` | Resolves SQL FQDNs to private IPs inside the VNet. |
| Private endpoints `pe-sql-ops` / `pe-sql-etl` | `peOps` / `peEtl` | Private connectivity to the two SQL servers. |

Fabric provisions its own **managed VNet data gateway** into the delegated
`snet-fabric-gateway` subnet — this template only creates and delegates the subnet;
there is no VM.

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
disabled). The **deploying user** is set as the single SQL Entra admin via Bicep's
`deployer()` function (or override with `aadAdminObjectId` / `aadAdminLogin` /
`aadAdminPrincipalType` to use a Group or service principal). That admin account is
what you sign in with from Fabric to seed the databases. `sqlAdminLogin` /
`sqlAdminPassword` still exist for ARM API compatibility but are **never usable**
(local auth is off); the password has a generated default so no input is required.

**Networking (private SQL).** A second org policy denies SQL servers with a public
endpoint (`DenyPublicEndpointEnabled`). So both servers set
`publicNetworkAccess: 'Disabled'` and have **no firewall rules**; they are reached
only through **private endpoints** in the spoke VNet. Because Fabric is a public
SaaS service, the template **delegates** the `snet-fabric-gateway` subnet to
`Microsoft.PowerPlatform/vnetaccesslinks` so Fabric can inject its own **managed
VNet data gateway** and reach the private endpoints (create it from the Fabric
portal — MANUAL, no VM). The **storage account keeps its public endpoint**. Full
walkthrough: [`../docs/networking-gateway.md`](../docs/networking-gateway.md).

**Notes**
- This is a **subscription-scoped** template — it creates **both** resource groups
  for you. The resource-group names and every resource name are **parameters** with
  sensible defaults, so you can customize them at deploy time.
- **Seeding:** the SQL databases are **not** seeded by the deployment (they are
  private and no in-VNet compute is deployed). After you connect Fabric's managed
  VNet gateway, seed them **from Fabric** with your admin account by running
  [`../data/sql/ops_seed.sql`](../data/sql/ops_seed.sql) and
  [`../data/sql/etl_seed.sql`](../data/sql/etl_seed.sql) through the gateway
  connections — see [`../docs/networking-gateway.md`](../docs/networking-gateway.md).
  The Shortcut reference blob is uploaded to the (public) storage account by
  `scripts\Deploy-Azure.ps1` / `scripts\Seed-Data.ps1` from your machine.
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
| `aadAdminObjectId` / `aadAdminLogin` | *(empty → deploying user)* | Entra principal set as SQL admin. Empty uses `deployer()`. |
| `aadAdminPrincipalType` | `User` | `User` (default), `Group`, or `Application` (managed identity / SP). |
| `networkResourceGroupName` | `rg-fabric-e2e-network` | Networking RG (spoke VNet, PEs, Fabric-delegated subnet). |
| `vnetAddressPrefix` / `privateEndpointSubnetPrefix` / `fabricGatewaySubnetPrefix` | `10.20.0.0/16` / `10.20.1.0/24` / `10.20.2.0/24` | Spoke VNet + subnet ranges. |

## Files

| File | Purpose |
|---|---|
| `main.bicep` | Subscription-scoped entry point; creates both RGs + all resources. |
| `modules/sqlServer.bicep` | Azure SQL logical server + database (Entra-only, public access disabled). |
| `modules/storage.bicep` | ADLS Gen2 storage account + container (public) for the shortcut source. |
| `modules/network.bicep` | Spoke VNet + subnets (incl. Fabric-delegated) + SQL private DNS zone + link. |
| `modules/privateEndpoint.bicep` | Private endpoint + DNS zone group for one SQL server (called twice). |
| `main.bicepparam` | Optional parameter values (all optional; no secrets). |
| `azuredeploy.json` | ARM template compiled from `main.bicep` — powers the **Deploy to Azure** button. |

## Prerequisites

- Azure CLI ≥ 2.86 and Bicep ≥ 0.41 (`az bicep version`).
- Rights to create resource groups + resources in the target subscription.
- SQL seeding happens later **from Fabric** (through the managed VNet gateway), so
  no local `SqlServer` PowerShell module is required.

## Deploy

Use the wrapper script (recommended — it also uploads the blob reference file):

```powershell
..\scripts\Deploy-Azure.ps1 -ResourceGroupName rg-fabric-e2e-demo `
  -NetworkResourceGroupName rg-fabric-e2e-network -Location eastus2
```

Or deploy the Bicep directly (no password — Entra-only auth). The deploying user
becomes the SQL Entra admin automatically via `deployer()`:

```powershell
# Deploy at subscription scope (creates both resource groups)
az deployment sub create `
  --name fabric-demo-source `
  --location eastus2 `
  --template-file main.bicep `
  --parameters main.bicepparam
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
- No VM is deployed — the Fabric managed VNet data gateway is a managed service, so
  there is no VM to stop, patch, or pay for continuously.

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
2. Point the Fabric SQL connection (and the `etl_seed.sql` you run through the
   gateway) at the MI endpoint (`<mi-name>.<dns-zone>.database.windows.net`).
3. In Fabric, create the Copy Job / pipeline connection against the MI endpoint
   exactly as documented in
   [`../docs/ingestion-etl-copyjob.md`](../docs/ingestion-etl-copyjob.md).

No notebook or medallion logic changes are required — only the connection target.
