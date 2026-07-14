# Demo runbook

## 1. Admin setup

1. Open the Fabric portal.
2. Create or open workspace `Fabric End-to-End Demo`.
3. Confirm the workspace is assigned to Fabric capacity.
4. Show workspace roles and explain least privilege.
5. Apply or discuss sensitivity labels and endorsement.

## 2. Automated ingestion and transformation

1. Create Lakehouse `lh_customer360`.
2. Import the notebooks from `fabric\notebooks`.
3. Attach each notebook to `lh_customer360`.
4. Run `03_run_end_to_end.ipynb`.
5. Show raw CSV data under `Files/raw/customer360`.
6. Show Bronze raw tables, Silver cleansed/joined tables, and Gold business tables.

Use `docs\automated-build-guide.md` as the detailed build procedure.

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
