# Bill of materials

## Azure resources (Bicep — `infra/`)

| Resource | Suggested name | Role | Feeds |
|---|---|---|---|
| Resource group | `rg-fabric-e2e-demo` | Container for all sources | — |
| Azure SQL DB | `sqldb-ops` | Operational master data | **Mirroring** |
| Storage (ADLS Gen2) | `st<prefix><suffix>` | Reference file landing | **Shortcut** |
| Azure SQL DB | `sqldb-etl` | Transactional data (SQL MI stand-in) | **ETL / Copy Job** |

## Fabric items (how each is created)

> **Git integration creates most of these for you.** When you connect the empty
> workspace to this repo and run **Update all**, Fabric creates the **Lakehouses,
> notebooks, semantic model, and report** from the repo — do **not** build those by
> hand. The **Created by** column below shows what you set up manually (capacity,
> domain, workspace, ingestion items, AI items) versus what Git provides.

| Item | Suggested name | Purpose | Created by |
|---|---|---|---|
| Capacity | (your F SKU) | Compute for the workspace | Manual |
| Domain | `Contoso Analytics` | Catalog / governance grouping | Manual |
| Workspace | `Fabric End-to-End Demo` | Governed collaboration boundary | Manual (empty) |
| Lakehouse | `LH_Bronze` | Raw landing from the 3 ingestion patterns | **Git** |
| Lakehouse | `LH_Silver` | Cleansed / conformed / combined tables | **Git** |
| Lakehouse | `LH_Gold` | Curated tables for consumption | **Git** |
| Notebooks | `00`–`03` | Medallion transforms + orchestration | **Git** |
| Semantic model | `sm_customer360_gold` | Governed Direct Lake metrics (`*.SemanticModel/`) | **Git** (then bind) |
| Power BI report | `Customer 360 Executive Overview` | Business consumption (`*.Report/`) | **Git** |
| Mirrored DB | `mirror_sqldb_ops` | Mirroring of `sqldb-ops` | Manual |
| Shortcut | `regions` | ADLS Gen2 shortcut (no copy) | Manual |
| Copy Job | `copy_etl_to_bronze` | Batch ETL of `sqldb-etl` tables | Manual |
| Data Agent | `Customer Insights Agent` | Natural-language consumption (config-as-code) | Manual |
| Fabric IQ ontology | `Contoso Customer 360 Ontology` | Business semantic layer over Gold (config-as-code) | Manual |

## Local assets

| Asset | Path |
|---|---|
| Bicep IaC | `infra/main.bicep`, `infra/modules/*` (sqlServer, storage, network, privateEndpoint) |
| Deploy / seed / teardown | `scripts/Deploy-Azure.ps1`, `Seed-Data.ps1`, `Teardown-Azure.ps1` |
| Networking + gateway guide | `docs/networking-gateway.md` |
| Data generator | `scripts/generate_demo_data.py` |
| SQL seed scripts | `data/sql/ops_seed.sql`, `data/sql/etl_seed.sql` |
| Shortcut source files | `data/blob/reference/regions/regions.csv` |
| Offline fallback CSVs | `data/bronze/*.csv` |
| Semantic model (TMDL/PBIP) | `sm_customer360_gold.SemanticModel/` |
| Power BI report (PBIR) | `Customer 360 Executive Overview.Report/` |
| Semantic model build/bind guide | `fabric/semantic-model/README.md` |
| DAX measures | `fabric/semantic-model/measures.dax` |
| RLS roles | `fabric/semantic-model/rls-roles.md` |
| RLS/CLS SQL | `fabric/governance/rls-cls.sql` |
| Governance checklist | `fabric/governance/checklist.md` |
| Data Agent prompt | `fabric/data-agent/instructions.md` |
| Data Agent config-as-code | `fabric/data-agent/agent-config.yaml`, `build-guide.md` |
| Fabric IQ ontology | `fabric/ontology/ontology.yaml`, `README.md` |

## Demo data entities

Regions · Customers · Products · Orders · Support tickets

## Prerequisites

- Microsoft Fabric tenant with capacity enabled.
- Azure subscription (Contributor) for the Bicep deployment.
- Permission to create workspaces, Lakehouses, Mirrored DBs, Copy Jobs,
  notebooks, semantic models, reports, and Data Agents.
