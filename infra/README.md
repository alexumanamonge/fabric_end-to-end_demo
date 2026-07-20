# Infrastructure (Bicep) — Azure source systems

This folder deploys the **external source systems** that feed the three Fabric
ingestion patterns in the demo. Fabric capacity and workspace are created
manually by you (see [`../docs/fabric-workspace-setup.md`](../docs/fabric-workspace-setup.md)).

## What gets deployed

| Resource | Bicep name | Role in the demo | Feeds |
|---|---|---|---|
| Azure SQL DB `sqldb-ops` | `sqlOps` | Operational master data | **Mirroring** → customers, products |
| Storage account (ADLS Gen2) | `storage` | Reference file landing zone | **Shortcut** → regions |
| Azure SQL DB `sqldb-etl` | `sqlEtl` | Transactional system of record | **ETL / Copy Job** → orders, support_tickets |

All resources land in a single resource group (`rg-<namePrefix>-source` by default).

## One-click deploy (portal)

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Falexumanamonge%2Ffabric_end-to-end_demo%2Fmain%2Finfra%2Fazuredeploy.json)

The button loads [`azuredeploy.json`](azuredeploy.json) (the ARM template compiled
from `main.bicep`) into the Azure portal. Pick a region and set the SQL admin
password; all other parameters have sensible defaults.

**Notes**
- This is a **subscription-scoped** template — it creates the resource group for
  you (no need to pre-create one).
- The button **provisions infrastructure only**; it does not seed data. After it
  completes, run the seeding command in the repo README (Step 1, Option A) to load
  the SQL tables and upload the Shortcut files.
- The portal deploy does not add your workstation IP to the SQL firewall. The
  `Deploy-Azure.ps1` seeding step adds it automatically; alternatively add a
  firewall rule for your IP in the portal, or enable *Allow Azure services*.
- **Regenerating the template:** if you change the Bicep, recompile with
  `az bicep build --file infra\main.bicep --outfile infra\azuredeploy.json` and
  commit the result so the button stays in sync.

## Files

| File | Purpose |
|---|---|
| `main.bicep` | Subscription-scoped entry point; creates the RG + all resources. |
| `modules/sqlServer.bicep` | Reusable Azure SQL logical server + database + firewall. |
| `modules/storage.bicep` | ADLS Gen2 storage account + container for the shortcut source. |
| `main.bicepparam` | Parameter values. **Never commit real secrets.** |
| `azuredeploy.json` | ARM template compiled from `main.bicep` — powers the **Deploy to Azure** button. |

## Prerequisites

- Azure CLI ≥ 2.86 and Bicep ≥ 0.41 (`az bicep version`).
- Rights to create a resource group + resources in the target subscription.
- `sqlcmd` **or** the PowerShell `SqlServer` module for seeding (see `../scripts`).

## Deploy

Use the wrapper script (recommended — it also seeds data):

```powershell
..\scripts\Deploy-Azure.ps1 -NamePrefix fabdemo -Location eastus2
```

Or deploy the Bicep directly:

```powershell
# 1. Set the SQL admin password securely (not stored in files)
$env:SQL_ADMIN_PASSWORD = 'Ch@ngeMe-StrongP@ss1'

# 2. (Recommended) capture your objectId + public IP for AAD admin & firewall
$objectId = az ad signed-in-user show --query id -o tsv
$myIp     = (Invoke-RestMethod https://api.ipify.org)

# 3. Deploy at subscription scope
az deployment sub create `
  --name fabric-demo-source `
  --location eastus2 `
  --template-file main.bicep `
  --parameters main.bicepparam `
  --parameters sqlAdminPassword=$env:SQL_ADMIN_PASSWORD `
               aadAdminObjectId=$objectId `
               aadAdminLogin=$(az ad signed-in-user show --query userPrincipalName -o tsv) `
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

## Teardown

```powershell
..\scripts\Teardown-Azure.ps1 -NamePrefix fabdemo
# or
az group delete --name rg-fabdemo-source --yes --no-wait
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
