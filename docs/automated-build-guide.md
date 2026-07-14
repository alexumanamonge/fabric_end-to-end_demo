# Automated Fabric build guide

This version of the demo is designed to be built inside Fabric from notebooks, not from a manual SQL copy/paste.

## Target flow

```text
00_generate_raw_data
  -> OneLake Files/raw/customer360
01_raw_to_silver
  -> bronze.*_raw Delta tables
  -> silver.customers, silver.orders, silver.customer_orders, silver.support_tickets
02_silver_to_gold
  -> gold.sales_summary, gold.customer_360, gold.executive_kpis
Semantic model
  -> Direct Lake over Gold tables
Power BI report
  -> Executive overview, Customer 360, Support view
Data Agent
  -> Natural language over governed semantic model
```

## Fabric build steps

1. Create workspace `Fabric End-to-End Demo`.
2. Create Lakehouse `lh_customer360`.
3. Import these notebooks into the workspace:
   - `fabric\notebooks\00_generate_raw_data.ipynb`
   - `fabric\notebooks\01_raw_to_silver.ipynb`
   - `fabric\notebooks\02_silver_to_gold.ipynb`
   - `fabric\notebooks\03_run_end_to_end.ipynb`
4. Attach each notebook to `lh_customer360`.
5. Run `03_run_end_to_end`.
6. Confirm these tables exist:
   - `bronze.customers_raw`
   - `bronze.orders_raw`
   - `silver.customer_orders`
   - `gold.sales_summary`
   - `gold.customer_360`
   - `gold.executive_kpis`
7. Create semantic model `sm_customer360_gold` over the Gold tables.
8. Use `fabric\semantic-model\model-design.md`, `field-list.md`, and `measures.dax` to configure the model.
9. Build the Power BI report using `docs\power-bi-report-spec.md`.
10. Create the Data Agent using `fabric\data-agent\instructions.md`.

## What is automated vs. what is configured

| Area | Status |
|---|---|
| Raw demo data generation | Automated by notebook `00_generate_raw_data` |
| Bronze Delta tables | Automated by notebook `01_raw_to_silver` |
| Silver transformations and joins | Automated by notebook `01_raw_to_silver` |
| Gold business tables | Automated by notebook `02_silver_to_gold` |
| End-to-end data pipeline run | Automated by notebook `03_run_end_to_end` |
| Semantic model creation | Configured from generated Gold tables using provided model assets |
| Power BI report | Built from provided report specification |
| Data Agent | Configured from provided instructions and starter questions |

## Demo talking point

The notebooks intentionally keep the logic simple and visible. This makes it easy to demonstrate lineage, governance, permissions, and medallion architecture without losing the customer in complex ETL.
