# Build guide (what is automated vs. configured)

This demo is designed to be **deployed by script** (Azure sources) and
**built in Fabric** (workspace + ingestion + notebooks), not hand-assembled.

## Target flow

```text
scripts\Deploy-Azure.ps1
  -> Azure: sqldb-ops, sqldb-etl, storage (ADLS Gen2) + seed data
Fabric ingestion (manual, one-time)
  Mirroring   sqldb-ops   -> LH_Bronze Tables/customers, products
  Shortcut    ADLS Gen2   -> LH_Bronze Files/shortcuts/regions
  Copy Job    sqldb-etl   -> LH_Bronze Tables/orders, support_tickets
01_raw_to_silver
  -> LH_Silver Tables/customers, products, regions, orders, support_tickets, customer_orders
02_silver_to_gold
  -> LH_Gold Tables/sales_summary, customer_360, executive_kpis
Semantic model  -> Direct Lake over LH_Gold
Power BI report -> Executive overview, Customer 360, Support view
Data Agent      -> Natural language over the governed model
```

## What is automated vs. configured

| Area | Status |
|---|---|
| Azure source infrastructure | **Automated** by `scripts\Deploy-Azure.ps1` (Bicep) |
| Source data seeding (SQL + blob) | **Automated** by `scripts\Seed-Data.ps1` |
| Fabric capacity, domain, workspace, Lakehouses | Manual (`docs\fabric-workspace-setup.md`) |
| Mirroring / Shortcut / Copy Job | Manual, one-time (`docs\ingestion-*.md`) |
| Bronze → Silver | **Automated** by `01_raw_to_silver` |
| Silver → Gold | **Automated** by `02_silver_to_gold` |
| End-to-end pipeline run | **Automated** by `03_run_end_to_end` |
| Semantic model | Configured from Gold using provided model assets |
| Power BI report | Built from `docs\power-bi-report-spec.md` |
| Data Agent | Configured from `fabric\data-agent\instructions.md` |
| Governance (RLS/CLS, endorsement, labels) | Applied via `fabric\governance\` |

## Offline mode

To demo the medallion **without** deploying Azure, set
`RUN_OFFLINE_SEED = True` in `03_run_end_to_end` (or run `00_generate_raw_data`).
It writes the same Bronze shapes the real ingestion produces, so `01`/`02` are
unchanged.

## Verify after a run

- `LH_Bronze.Tables`: customers, products, orders, support_tickets (+ regions file)
- `LH_Silver.Tables`: customer_orders (and the conformed dimensions)
- `LH_Gold.Tables`: sales_summary, customer_360, executive_kpis

## Talking point

The notebooks keep logic simple and visible so the demo can focus on **ingestion
patterns, medallion architecture, lineage, and governance** without getting lost
in complex ETL.
