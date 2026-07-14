# Demo runbook

## 1. Admin setup

1. Open the Fabric portal.
2. Create or open workspace `Fabric End-to-End Demo`.
3. Confirm the workspace is assigned to Fabric capacity.
4. Show workspace roles and explain least privilege.
5. Apply or discuss sensitivity labels and endorsement.

## 2. Ingestion

1. Create Lakehouse `lh_customer360`.
2. Upload the CSV files from `data\bronze` to `Files\bronze`.
3. Demonstrate or explain:
   - Shortcut for `regions_shortcut.csv`.
   - Mirroring for `customers_mirrored.csv` and `products_mirrored.csv`.
   - Copy Job for `orders_copy_job.csv` and `support_tickets_copy_job.csv`.

## 3. Medallion transformation

1. Create notebook `nb_customer360_medallion`.
2. Attach it to `lh_customer360`.
3. Run `fabric\sql\medallion_customer360.sql`.
4. Show Bronze raw tables, Silver cleansed tables, and Gold business tables.

## 4. Governance and lineage

1. Open workspace lineage view.
2. Show the chain from ingestion to Lakehouse to notebook to semantic model to report.
3. Open item permissions and explain access control.
4. Promote or certify the semantic model.

## 5. Semantic model and Power BI

1. Create a semantic model from Gold tables.
2. Add measures from `fabric\semantic-model\measures.dax`.
3. Build report pages:
   - Executive Overview
   - Customer 360
   - Support and Satisfaction
4. Show Direct Lake positioning and governed metrics.

## 6. Data Agent

1. Create `Customer Insights Agent`.
2. Use the instructions in `fabric\data-agent\instructions.md`.
3. Ask the recommended starter questions.
4. Explain that agent answers are constrained by governed data permissions.

