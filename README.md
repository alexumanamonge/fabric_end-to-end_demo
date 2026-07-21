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
storage) and a **networking RG** (spoke VNet, SQL private endpoints, private DNS,
and a subnet **delegated to Fabric** for its managed virtual network data gateway).
Just pick a region and (optionally) the two resource-group names; every other name
defaults but is customizable. **No password is required:** SQL uses **Microsoft
Entra ID-only auth** and is **private-endpoint only** (public access disabled) to
satisfy org policy, and the **deploying user** is set as the SQL Entra admin. There
is **no VM** — Fabric provisions its own **managed VNet data gateway** into the
delegated subnet to reach the private SQL endpoints (one-time, manual), and you
seed the databases from Fabric with your own account. Fabric capacity/workspace are
still created manually.

---

## Architecture

```
 Azure (Bicep IaC)                                 Fabric (manual capacity + workspace)
 ─────────────────                                 ────────────────────────────────────
 workload RG                     network RG
 ───────────                     ──────────
 sqldb-ops (private) ─PE─▶ spoke VNet ─┐
 sqldb-etl (private) ─PE─▶ (privatelink)│  ┌ snet-fabric-gateway (delegated)
 ADLS Gen2 (public) ───────────────────┘  └── Fabric managed VNet data gateway ──
                                                          │ (Fabric → managed gateway → private SQL)
 sqldb-ops   ──Mirroring──────▶  LH_Bronze ─┐
 ADLS Gen2   ──Shortcut───────▶  (raw)       │  01  ┌─ LH_Silver ─┐ 02 ┌─ LH_Gold ─┐
 sqldb-etl   ──ETL/Copy Job──▶  LH_Bronze ─┘        │ (clean/     │    │ (report-  │
                                                     │  combine)   │    │  ready)   │
                                                     └─────────────┘    └─────┬─────┘
                                                                              ▼
                                        sm_customer360_gold (Direct Lake) ─▶ Report + Data Agent
```

**Networking:** SQL is **Entra-only + private-endpoint-only** (public access
disabled per org policy). A **spoke VNet** with SQL private endpoints and a subnet
**delegated to Fabric** (`Microsoft.PowerPlatform/vnetaccesslinks`) are deployed to
a separate **networking resource group** (hub-spoke; hub + peering out of scope).
Fabric provisions its own **managed VNet data gateway** into the delegated subnet
and connects to SQL **through it** — no VM to run or patch. Storage keeps its
**public** endpoint. See
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
- No PowerShell SQL module is needed: SQL is seeded later **from Fabric** through
  the managed VNet gateway (see Step 3). The scripted deploy only uploads the blob
  reference file (public storage) from your machine.
- An Azure subscription (Contributor) and a **Microsoft Fabric capacity** you can create.
- `az login` completed and the right subscription selected.

> **Authentication + networking:** the Azure SQL servers are **Entra ID-only**
> (SQL logins disabled) **and** have **public network access disabled** — both to
> satisfy org policy. They are reached only via **private endpoints** in a spoke
> VNet. The **deploying user** is set as the SQL Entra admin (no SQL password
> anywhere), so once Fabric's **managed VNet data gateway** is connected you can
> seed the databases from Fabric with your own account. Fabric provisions the
> managed gateway into a subnet this template delegates for it — there is **no VM**
> to install or patch. See
> [`docs/networking-gateway.md`](docs/networking-gateway.md).

---

## Quick start

### Step 1 — Deploy the Azure sources

**Option A — one-click portal deploy.** Click the
[**Deploy to Azure**](#one-click-deploy-the-azure-sources) button above, pick a
region, and (optionally) customize the two resource-group names / resource names.
No password is needed. The deployment provisions everything (both RGs + spoke VNet
+ private endpoints + the Fabric-delegated subnet) and sets **you** (the deployer)
as the SQL Entra admin. The databases start **empty** — you seed them from Fabric
in Step 3 (there is no in-VNet VM). Upload the blob reference file with
`scripts\Seed-Data.ps1` (storage is public), then continue to Step 2.

**Option B — fully scripted.**

```powershell
.\scripts\Deploy-Azure.ps1 -ResourceGroupName rg-fabric-e2e-demo `
  -NetworkResourceGroupName rg-fabric-e2e-network -Location eastus2
```

The script deploys the Bicep, sets you as the SQL Entra admin, and uploads the
Shortcut reference file to the (public) storage account. Outputs (server FQDNs,
VNet name, Fabric-delegated subnet name, storage endpoint) are saved to
`infra/deployment-outputs.json`. Details: [`infra/README.md`](infra/README.md).

### Step 2 — Create the Fabric workspace (MANUAL, best practices)

Follow [`docs/fabric-workspace-setup.md`](docs/fabric-workspace-setup.md) to create
the capacity, domain, workspace, `LH_Bronze` / `LH_Silver` / `LH_Gold`, roles, and
Git integration.

### Step 3 — Connect the managed VNet data gateway & seed SQL (MANUAL)

In the Fabric portal, create a **virtual network data gateway** on the delegated
subnet (`snet-fabric-gateway` in `vnet-fabric-spoke`), create connections to the
two private SQL servers with your organizational account, then **seed the databases
from Fabric** by running the two SQL seed scripts through the gateway. Full steps:
[`docs/networking-gateway.md`](docs/networking-gateway.md).

### Step 4 — Wire the three ingestion patterns (MANUAL)

| Pattern | Guide |
|---|---|
| Mirroring | [`docs/ingestion-mirroring.md`](docs/ingestion-mirroring.md) |
| Shortcut | [`docs/ingestion-shortcut.md`](docs/ingestion-shortcut.md) |
| ETL / Copy Job | [`docs/ingestion-etl-copyjob.md`](docs/ingestion-etl-copyjob.md) |

> Mirroring and Copy Job connections to SQL must select the **managed VNet data
> gateway** (Step 3) because SQL has no public endpoint.

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
| `scripts/Deploy-Azure.ps1` | One-command deploy of both RGs + blob upload. |
| `scripts/Seed-Data.ps1` | Uploads the Shortcut reference file to storage (public). |
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
