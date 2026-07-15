# Automated Fabric build guide

This version of the demo is designed to be built inside Fabric from notebooks, not from a manual SQL copy/paste.

## Target flow

```text
00_generate_raw_data
  -> LH_Bronze Files/raw/customer360
01_raw_to_silver
  -> LH_Bronze Tables/*_raw Delta tables
  -> LH_Silver Tables/customers, orders, customer_orders, support_tickets
02_silver_to_gold
  -> LH_Gold Tables/sales_summary, customer_360, executive_kpis
Semantic model
  -> Direct Lake over LH_Gold tables
Power BI report
  -> Executive overview, Customer 360, Support view
Data Agent
  -> Natural language over governed semantic model
```

## Fabric build steps

1. Create workspace `Fabric End-to-End Demo`.
2. Create or sync Lakehouses `LH_Bronze`, `LH_Silver`, and `LH_Gold`.
3. Pull the Git-connected notebook items into the workspace.
4. If Fabric cannot resolve the workspace name automatically, set `WORKSPACE_NAME` in each notebook.
5. Run `03_run_end_to_end`.
6. Confirm these tables exist:
   - `LH_Bronze.Tables.customers_raw`
   - `LH_Bronze.Tables.orders_raw`
   - `LH_Silver.Tables.customer_orders`
   - `LH_Gold.Tables.sales_summary`
   - `LH_Gold.Tables.customer_360`
   - `LH_Gold.Tables.executive_kpis`
7. Create semantic model `sm_customer360_gold` over the `LH_Gold` tables.
8. Use `fabric\semantic-model\model-design.md`, `field-list.md`, and `measures.dax` to configure the model.
9. Build the Power BI report using `docs\power-bi-report-spec.md`.
10. Create the Data Agent using `fabric\data-agent\instructions.md`.

## What is automated vs. what is configured

| Area | Status |
|---|---|
| Raw demo data generation | Automated by notebook `00_generate_raw_data` |
| Bronze Delta tables in `LH_Bronze` | Automated by notebook `01_raw_to_silver` |
| Silver transformations and joins in `LH_Silver` | Automated by notebook `01_raw_to_silver` |
| Gold business tables in `LH_Gold` | Automated by notebook `02_silver_to_gold` |
| End-to-end data pipeline run | Automated by notebook `03_run_end_to_end` |
| Semantic model creation | Configured from generated Gold tables using provided model assets |
| Power BI report | Built from provided report specification |
| Data Agent | Configured from provided instructions and starter questions |

## Demo talking point

The notebooks intentionally keep the logic simple and visible. This makes it easy to demonstrate lineage, governance, permissions, and medallion architecture without losing the customer in complex ETL.
