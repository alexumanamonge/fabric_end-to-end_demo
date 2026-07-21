# Fabric end-to-end demo

A **re-deployable, quick-start** demo of Microsoft Fabric covering the full
lifecycle: Infrastructure-as-Code Azure sources → three ingestion patterns →
medallion architecture in OneLake → semantic model, Power BI, and a Data Agent —
with governance & security (OneLake catalog, lineage, RLS/CLS, endorsement,
sensitivity labels) throughout.

Built to onboard new team members fast: everything is scripted, and every manual
Fabric action is documented with a **MANUAL** callout.

## One-click: deploy the Azure sources

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Falexumanamonge%2Ffabric_end-to-end_demo%2Fmain%2Finfra%2Fazuredeploy.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](https://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Falexumanamonge%2Ffabric_end-to-end_demo%2Fmain%2Finfra%2Fazuredeploy.json)

Provisions **two resource groups** — a workload RG (both Azure SQL DBs + ADLS Gen2
storage + a managed identity) and a **networking RG** (spoke VNet, SQL private
endpoints, private DNS, and a "VNet data gateway" VM) — **and automatically seeds
the sample data** from inside the VNet. Just pick a region and (optionally) the two
resource-group names; every other name defaults but is customizable. **No password
is required:** SQL uses **Microsoft Entra ID-only auth** and is **private-endpoint
only** (public access disabled) to satisfy org policy. Fabric reaches the private
SQL endpoints through an on-premises data gateway you install on the VM (one-time,
manual). Fabric capacity/workspace are still created manually.

---

## Architecture

```
 Azure (Bicep IaC)                                 Fabric (manual capacity + workspace)
 ─────────────────                                 ────────────────────────────────────
 workload RG                     network RG
 ───────────                     ──────────
 sqldb-ops (private) ─PE─▶ spoke VNet ─┐
 sqldb-etl (private) ─PE─▶ (privatelink)│  ┌ gateway VM (on-prem data gateway)
 ADLS Gen2 (public) ───────────────────┘  └──────────────┬───────────────────
                                                          │ (Fabric → gateway → private SQL)
 sqldb-ops   ──Mirroring──────▶  LH_Bronze ─┐
 ADLS Gen2   ──Shortcut───────▶  (raw)       │  01  ┌─ LH_Silver ─┐ 02 ┌─ LH_Gold ─┐
 sqldb-etl   ──ETL/Copy Job──▶  LH_Bronze ─┘        │ (clean/     │    │ (report-  │
                                                     │  combine)   │    │  ready)   │
                                                     └─────────────┘    └─────┬─────┘
                                                                              ▼
                                        sm_customer360_gold (Direct Lake) ─▶ Report + Data Agent
```

**Networking:** SQL is **Entra-only + private-endpoint-only** (public access
disabled per org policy). A **spoke VNet** with SQL private endpoints and a **VNet
data gateway VM** are deployed to a separate **networking resource group**
(hub-spoke; hub + peering out of scope). Fabric connects to SQL **through the
gateway**. Storage keeps its **public** endpoint. See
[`docs/networking-gateway.md`](docs/networking-gateway.md).

| Source (Azure) | Ingestion pattern | Data | Lands in Bronze as |
|---|---|---|---|
| Azure SQL DB `sqldb-ops` | **Mirroring** | customers, products | `Tables/customers`, `Tables/products` |
| Storage (ADLS Gen2) | **Shortcut** | regions | `Files/shortcuts/regions/regions.csv` |
| Azure SQL DB `sqldb-etl`¹ | **ETL / Copy Job** | orders, support_tickets | `Tables/orders`, `Tables/support_tickets` |

¹ `sqldb-etl` stands in for **SQL Managed Instance** for speed/cost; the MI variant
is documented in [`infra/README.md`](infra/README.md).

---

## Prerequisites

- Azure CLI ≥ 2.86, Bicep ≥ 0.41 (`az bicep version`), Python 3.10+.
- Only for a manual re-seed on the gateway VM: the PowerShell **SqlServer** module.
  The one-click / scripted deploy needs none of this — seeding runs on the VM.
- An Azure subscription (Contributor) and a **Microsoft Fabric capacity** you can create.
- `az login` completed and the right subscription selected.

> **Authentication + networking:** the Azure SQL servers are **Entra ID-only**
> (SQL logins disabled) **and** have **public network access disabled** — both to
> satisfy org policy. They are reached only via **private endpoints** in a spoke
> VNet. A user-assigned managed identity is the SQL Entra admin; the seed runs on a
> **VNet data gateway VM** inside the VNet and authenticates with an Entra token.
> There is **no SQL password** anywhere. Fabric connects to SQL through the
> on-premises data gateway you install on that VM — see
> [`docs/networking-gateway.md`](docs/networking-gateway.md).

---

## Quick start

### Step 1 — Deploy & seed the Azure sources

**Option A — one-click portal deploy (deploys *and* seeds).** Click the
[**Deploy to Azure**](#one-click-deploy-the-azure-sources) button above, pick a
region, and (optionally) customize the two resource-group names / resource names.
No password is needed. The deployment provisions everything (both RGs + spoke VNet
+ private endpoints + gateway VM) **and the gateway VM seeds the data from inside
the VNet** — no follow-up command needed. Then continue to Step 2.

> The seed runs on the gateway VM (as the managed identity) and downloads the seed
> files from this repo's public raw URL, so the repo must stay public (or set
> `seedSourceUrl` to your own raw location). To provision without seeding, set
> `seedData=false`. To be granted `db_owner` on the databases, set
> `aadAdminObjectId` (your Entra objectId) and `aadAdminLogin` (your UPN).

**Option B — fully scripted (deploy + seed in one command).**

```powershell
.\scripts\Deploy-Azure.ps1 -ResourceGroupName rg-fabric-e2e-demo `
  -NetworkResourceGroupName rg-fabric-e2e-network -Location eastus2
```

The script deploys the Bicep, auto-detects your Entra objectId/UPN (granted
`db_owner`) and public IP (allowed to RDP the gateway VM), and the gateway VM seeds
the data with an Entra token. Outputs (server FQDNs, gateway VM IP, storage
endpoint) are saved to `infra/deployment-outputs.json`.
Details: [`infra/README.md`](infra/README.md).

### Step 2 — Install the VNet data gateway (MANUAL)

RDP to the gateway VM and install + register the on-premises data gateway so Fabric
can reach the private SQL endpoints. Follow
[`docs/networking-gateway.md`](docs/networking-gateway.md).

### Step 3 — Create the Fabric workspace (MANUAL, best practices)

Follow [`docs/fabric-workspace-setup.md`](docs/fabric-workspace-setup.md) to create
the capacity, domain, workspace, `LH_Bronze` / `LH_Silver` / `LH_Gold`, roles, and
Git integration.

### Step 4 — Wire the three ingestion patterns (MANUAL)

| Pattern | Guide |
|---|---|
| Mirroring | [`docs/ingestion-mirroring.md`](docs/ingestion-mirroring.md) |
| Shortcut | [`docs/ingestion-shortcut.md`](docs/ingestion-shortcut.md) |
| ETL / Copy Job | [`docs/ingestion-etl-copyjob.md`](docs/ingestion-etl-copyjob.md) |

> Mirroring and Copy Job connections to SQL must select the **VNet data gateway**
> (Step 2) because SQL has no public endpoint.

### Step 5 — Run the medallion pipeline

1. Pull the Git-connected `*.Notebook` items into the workspace.
2. If Fabric can't auto-resolve the workspace name, set `WORKSPACE_NAME` in each notebook.
3. Run **`03_run_end_to_end`** (leave `RUN_OFFLINE_SEED = False`).

> **No Azure sources handy?** Set `RUN_OFFLINE_SEED = True` in `03_run_end_to_end`
> (or run `00_generate_raw_data`) to seed Bronze offline and still demo the medallion.

### Step 6 — Semantic model, report, Data Agent, ontology

Two ways to get the semantic model + report:

- **Git-deployable (recommended):** connect the workspace to this repo via
  **Fabric › Git integration**. The `sm_customer360_gold.SemanticModel/` (TMDL)
  and `Customer 360 Executive Overview.Report/` (PBIR) items sync in directly.
  Then do the **one-time bind** in
  [`fabric/semantic-model/README.md`](fabric/semantic-model/README.md) (point the
  Direct Lake source at your `LH_Gold`). The report is pre-built to the spec.
- **Manual:** create `sm_customer360_gold` (Direct Lake) over `LH_Gold`, add
  measures from [`fabric/semantic-model/measures.dax`](fabric/semantic-model/measures.dax),
  and build the report per [`docs/power-bi-report-spec.md`](docs/power-bi-report-spec.md).

Then:

- Create the **Data Agent** per
  [`fabric/data-agent/build-guide.md`](fabric/data-agent/build-guide.md)
  (config-as-code in [`agent-config.yaml`](fabric/data-agent/agent-config.yaml)).
- Build the **Fabric IQ ontology** per
  [`fabric/ontology/README.md`](fabric/ontology/README.md)
  (config-as-code in [`ontology.yaml`](fabric/ontology/ontology.yaml)).

> The hand-authored TMDL/PBIR items are schema-valid but should be opened once in
> Power BI Desktop (the paired `.pbip`) to let Desktop normalize them; see each
> item's README.

### Step 7 — Governance & security

Work through [`fabric/governance/checklist.md`](fabric/governance/checklist.md):
OneLake catalog, lineage/impact analysis, **RLS/CLS**
([`fabric/governance/rls-cls.sql`](fabric/governance/rls-cls.sql)), endorsement,
and sensitivity labels.

### Step 8 — Tear down

```powershell
.\scripts\Teardown-Azure.ps1 -ResourceGroupName rg-fabric-e2e-demo `
  -NetworkResourceGroupName rg-fabric-e2e-network
```

Deletes **both** resource groups (workload + networking). Delete the Fabric
workspace manually for a full reset.

---

## Repository layout

| Path | Purpose |
|---|---|
| `infra/` | Bicep IaC for the Azure sources + spoke networking (+ README, MI variant). |
| `scripts/Deploy-Azure.ps1` | One-command deploy of both RGs + gateway-VM seed. |
| `scripts/vm-seed.ps1` | Seed bootstrap run by the gateway VM (in-VNet, Entra token). |
| `scripts/Seed-Data.ps1` | Manual re-seed helper (run on the gateway VM). |
| `scripts/Teardown-Azure.ps1` | Delete both Azure resource groups. |
| `scripts/generate_demo_data.py` | Deterministic data generator (SQL, blob, fallback CSV). |
| `data/` | Generated seed data (`sql/`, `blob/`, `bronze/`). |
| `*.Notebook/` | Git-synced Fabric notebooks (medallion + orchestration). |
| `*.SemanticModel/` | Git-deployable Direct Lake semantic model (TMDL/PBIP). |
| `*.Report/` | Git-deployable Power BI report (PBIR). |
| `LH_Bronze/Silver/Gold.Lakehouse/` | Fabric Lakehouse item metadata. |
| `docs/` | Setup, ingestion, runbook, report spec, Git integration. |
| `fabric/semantic-model/` | Model design, measures, RLS roles, bind guide. |
| `fabric/governance/` | Governance checklist + RLS/CLS SQL. |
| `fabric/data-agent/` | Data Agent instructions, config-as-code, build guide. |
| `fabric/ontology/` | Fabric IQ ontology (config-as-code) + build guide. |

## Design principles

- **Re-deployable:** scripted Azure sources, deterministic data, idempotent seeds.
- **Clear manual boundaries:** every human step is a **MANUAL** callout.
- **Simple, visible logic:** notebooks stay readable so lineage & governance shine.
- **Git governs code; Fabric runtime produces data.**
