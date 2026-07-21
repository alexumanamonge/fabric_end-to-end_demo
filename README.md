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

Provisions the resource group + both Azure SQL DBs + ADLS Gen2 storage in the
portal, **and automatically seeds the sample data** (a deployment script loads the
SQL tables and uploads the Shortcut file). Just pick a region and set the SQL
admin password — all resource names default but are fully customizable
(resource group, SQL servers/databases, storage account). Fabric
capacity/workspace are still created manually.

---

## Architecture

```
 Azure (Bicep IaC)                Fabric (manual capacity + workspace)
 ─────────────────                ────────────────────────────────────
 sqldb-ops   ──Mirroring──────▶  LH_Bronze ─┐
 ADLS Gen2   ──Shortcut───────▶  (raw)       │  01  ┌─ LH_Silver ─┐ 02 ┌─ LH_Gold ─┐
 sqldb-etl   ──ETL/Copy Job──▶  LH_Bronze ─┘        │ (clean/     │    │ (report-  │
                                                     │  combine)   │    │  ready)   │
                                                     └─────────────┘    └─────┬─────┘
                                                                              ▼
                                        sm_customer360_gold (Direct Lake) ─▶ Report + Data Agent
```

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
- Either the PowerShell **SqlServer** module or **sqlcmd.exe** (for SQL seeding).
- An Azure subscription (Contributor) and a **Microsoft Fabric capacity** you can create.
- `az login` completed and the right subscription selected.

---

## Quick start

### Step 1 — Deploy & seed the Azure sources

**Option A — one-click portal deploy (deploys *and* seeds).** Click the
[**Deploy to Azure**](#one-click-deploy-the-azure-sources) button above, pick a
region, set the SQL admin password, and (optionally) customize the resource group
and resource names. The deployment provisions everything **and runs the automated
seed** (SQL tables + Shortcut file) — no follow-up command needed. Then continue
to Step 2.

> The automated seed runs a deployment script that downloads the seed files from
> this repo's public raw URL, so the repo must stay public (or set `seedSourceUrl`
> to your own raw location). To provision without seeding, set `seedData=false`.

**Option B — fully scripted (deploy + local seed in one command).**

```powershell
$env:SQL_ADMIN_PASSWORD = 'Ch@ngeMe-StrongP@ss1'   # strong, not committed
.\scripts\Deploy-Azure.ps1 -NamePrefix fabdemo -Location eastus2
```

The script deploys the Bicep (with `seedData=false`) and seeds locally from your
machine (also adding your client IP to the SQL firewall). Outputs (server FQDNs,
storage endpoint) are saved to `infra/deployment-outputs.json`.
Details: [`infra/README.md`](infra/README.md).

### Step 2 — Create the Fabric workspace (MANUAL, best practices)

Follow [`docs/fabric-workspace-setup.md`](docs/fabric-workspace-setup.md) to create
the capacity, domain, workspace, `LH_Bronze` / `LH_Silver` / `LH_Gold`, roles, and
Git integration.

### Step 3 — Wire the three ingestion patterns (MANUAL)

| Pattern | Guide |
|---|---|
| Mirroring | [`docs/ingestion-mirroring.md`](docs/ingestion-mirroring.md) |
| Shortcut | [`docs/ingestion-shortcut.md`](docs/ingestion-shortcut.md) |
| ETL / Copy Job | [`docs/ingestion-etl-copyjob.md`](docs/ingestion-etl-copyjob.md) |

### Step 4 — Run the medallion pipeline

1. Pull the Git-connected `*.Notebook` items into the workspace.
2. If Fabric can't auto-resolve the workspace name, set `WORKSPACE_NAME` in each notebook.
3. Run **`03_run_end_to_end`** (leave `RUN_OFFLINE_SEED = False`).

> **No Azure sources handy?** Set `RUN_OFFLINE_SEED = True` in `03_run_end_to_end`
> (or run `00_generate_raw_data`) to seed Bronze offline and still demo the medallion.

### Step 5 — Semantic model, report, Data Agent, ontology

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

### Step 6 — Governance & security

Work through [`fabric/governance/checklist.md`](fabric/governance/checklist.md):
OneLake catalog, lineage/impact analysis, **RLS/CLS**
([`fabric/governance/rls-cls.sql`](fabric/governance/rls-cls.sql)), endorsement,
and sensitivity labels.

### Step 7 — Tear down

```powershell
.\scripts\Teardown-Azure.ps1 -NamePrefix fabdemo
```

Delete the Fabric workspace manually for a full reset.

---

## Repository layout

| Path | Purpose |
|---|---|
| `infra/` | Bicep IaC for the Azure sources (+ README, MI variant). |
| `scripts/Deploy-Azure.ps1` | One-command deploy + seed. |
| `scripts/Seed-Data.ps1` | Load SQL seed data + upload Shortcut files. |
| `scripts/Teardown-Azure.ps1` | Delete the Azure resource group. |
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
