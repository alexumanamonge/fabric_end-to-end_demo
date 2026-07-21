# Bill of materials

## Azure resources (Bicep — `infra/`)

| Resource | Suggested name | Role | Feeds |
|---|---|---|---|
| Resource group | `rg-fabric-e2e-demo` | Container for all sources | — |
| Azure SQL DB | `sqldb-ops` | Operational master data | **Mirroring** |
| Storage (ADLS Gen2) | `st<prefix><suffix>` | Reference file landing | **Shortcut** |
| Azure SQL DB | `sqldb-etl` | Transactional data (SQL MI stand-in) | **ETL / Copy Job** |

## Fabric items to create (manual)

| Item | Suggested name | Purpose |
|---|---|---|
| Capacity | (your F SKU) | Compute for the workspace |
| Domain | `Contoso Analytics` | Catalog / governance grouping |
| Workspace | `Fabric End-to-End Demo` | Governed collaboration boundary |
| Lakehouse | `LH_Bronze` | Raw landing from the 3 ingestion patterns |
| Lakehouse | `LH_Silver` | Cleansed / conformed / combined tables |
| Lakehouse | `LH_Gold` | Curated tables for consumption |
| Mirrored DB | `mirror_sqldb_ops` | Mirroring of `sqldb-ops` |
| Shortcut | `regions` | ADLS Gen2 shortcut (no copy) |
| Copy Job | `copy_etl_to_bronze` | Batch ETL of `sqldb-etl` tables |
| Notebooks | `00`–`03` | Medallion transforms + orchestration |
| Semantic model | `sm_customer360_gold` | Governed Direct Lake metrics (Git-deployable, `*.SemanticModel/`) |
| Power BI report | `Customer 360 Executive Overview` | Business consumption (Git-deployable, `*.Report/`) |
| Data Agent | `Customer Insights Agent` | Natural-language consumption (config-as-code) |
| Fabric IQ ontology | `Contoso Customer 360 Ontology` | Business semantic layer over Gold (config-as-code) |

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
