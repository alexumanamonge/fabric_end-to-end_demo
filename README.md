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

### Step 2 — Create the workspace and sync all Fabric items from Git (MANUAL)

This is the key step: you create an **empty** Fabric workspace, connect it to this
GitHub repo, and let **Git integration create every Fabric item for you** — the
three Lakehouses (`LH_Bronze` / `LH_Silver` / `LH_Gold`), the notebooks, the
semantic model, and the report. **Do not create these by hand.**

1. Create a **Fabric capacity** and an **empty workspace**, and assign roles —
   full best-practice detail in
   [`docs/fabric-workspace-setup.md`](docs/fabric-workspace-setup.md).
2. In **Workspace settings › Git integration**, connect to this repo, branch
   `main`, folder `/`, then click **Update all**. Fabric provisions all the items
   listed above from the repo. Walkthrough:
   [`docs/fabric-git-integration-demo.md`](docs/fabric-git-integration-demo.md).

> Why Git-first: the Lakehouses, notebooks, semantic model, and report already
> exist in this repo as valid Fabric items. Letting Git create them keeps their
> names and internal references intact — creating them manually causes duplicate
> items and sync conflicts.

### Step 3 — Connect the managed VNet data gateway & seed SQL (MANUAL)

The two Azure SQL databases are **private** (no public endpoint) and start
**empty**. In the Fabric portal you: (1) create a **virtual network data gateway**
on the delegated subnet (`snet-fabric-gateway` in `vnet-fabric-spoke`); (2) create
connections to the two SQL servers with your organizational account; (3) **seed the
databases from Fabric** by running the two SQL scripts through the gateway. Full
steps: [`docs/networking-gateway.md`](docs/networking-gateway.md).

> **Keep the seed pipeline out of Git.** The one-time seed uses a Fabric **Data
> pipeline**, which is a Git-tracked item. Do **not** commit it, and **delete it
> after seeding** so it never syncs to the repo and breaks future deployments.
> (Same workspace is fine; a separate non–Git-connected workspace is an option if
> you want this workspace's Source control pane pristine.) Details in the guide.

### Populate the medallion — pick one of two options

You can fill Bronze (and then Silver/Gold) **two ways**. Both run the exact same
`01`/`02` transforms, so everything downstream (semantic model, report, Data Agent)
is identical.

| | **Option A — Real ingestion** (full demo) | **Option B — Offline synthetic seed** (fastest / no Azure) |
|---|---|---|
| What it shows | The three real ingestion patterns landing live data | A working medallion on generated data |
| Needs | Steps 1, 3 **and** 4 (Azure SQL + storage, gateway, Mirroring/Shortcut/Copy Job) | **Only** the Git-synced workspace from Step 2 — skip Steps 1, 3, 4 |
| How | Wire ingestion (Step 4), then run the pipeline with `RUN_OFFLINE_SEED = False` | Run the pipeline with `RUN_OFFLINE_SEED = True` |
| Data | Live rows from your sources | Deterministic synthetic rows (fixed seed → same every run) |

> **Option B is a great standalone demo** when you have no Azure sources handy (or
> want a fast, self-contained run). Narrative: *"the platform runs end-to-end on
> synthetic data today; in production these same Bronze tables are fed by Mirroring,
> Shortcut, and Copy Job."* If you use Option B, **skip Step 4** and jump to Step 5.

### Step 4 — (Option A only) Wire the three ingestion patterns (MANUAL)

| Pattern | Guide |
|---|---|
| Mirroring | [`docs/ingestion-mirroring.md`](docs/ingestion-mirroring.md) |
| Shortcut | [`docs/ingestion-shortcut.md`](docs/ingestion-shortcut.md) |
| ETL / Copy Job | [`docs/ingestion-etl-copyjob.md`](docs/ingestion-etl-copyjob.md) |

> Mirroring and Copy Job connections to SQL must select the **managed VNet data
> gateway** (Step 3) because SQL has no public endpoint.

### Step 5 — Run the medallion pipeline

The notebooks were already created in your workspace by Git integration (Step 2).

1. Open the workspace and open **`03_run_end_to_end`**.
2. Choose your data source at the top of the notebook:
   - **Option A (real ingestion):** leave `RUN_OFFLINE_SEED = False`.
   - **Option B (offline synthetic):** set `RUN_OFFLINE_SEED = True` — this first
     runs `00_generate_raw_data` to seed Bronze, then Silver and Gold. No Azure
     sources needed.
3. **Run all.** It builds Bronze → Silver → Gold and prints a row-count summary.

> The notebooks auto-detect your workspace. If detection ever fails, set
> `WORKSPACE_NAME` at the top of each notebook to your workspace name (use a name
> **without spaces**, e.g. `End-to-End_Fabric_Demo`).

### Step 6 — Bind the semantic model, then build the Data Agent & ontology

The `sm_customer360_gold` semantic model and the `Customer 360 Executive Overview`
report were already created in your workspace by Git integration (Step 2). You just
need one binding step, then build the two AI items:

1. **Bind the semantic model** (one time): point its Direct Lake source at *your*
   `LH_Gold` — see [`fabric/semantic-model/README.md`](fabric/semantic-model/README.md).
   The report is pre-built to spec and refreshes once the model is bound.
2. Create the **Data Agent** per
   [`fabric/data-agent/build-guide.md`](fabric/data-agent/build-guide.md)
   (config-as-code in [`agent-config.yaml`](fabric/data-agent/agent-config.yaml)).
3. Build the **Fabric IQ ontology** per
   [`fabric/ontology/README.md`](fabric/ontology/README.md)
   (config-as-code in [`ontology.yaml`](fabric/ontology/ontology.yaml)).

> **Prefer to build them by hand instead?** You can create `sm_customer360_gold`
> (Direct Lake over `LH_Gold`) with the measures in
> [`fabric/semantic-model/measures.dax`](fabric/semantic-model/measures.dax) and
> build the report from [`docs/power-bi-report-spec.md`](docs/power-bi-report-spec.md).

> **Tip:** the semantic model and report in this repo are valid but hand-authored.
> They will work as-is; if you want Power BI Desktop to "bless" and re-save them in
> its own format, open the paired `.pbip` once in Desktop (optional). Each item's
> README explains this.

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
