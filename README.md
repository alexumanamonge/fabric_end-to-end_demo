# Fabric end-to-end demo

Customer-ready demo materials for Microsoft Fabric covering administration, governance, ingestion, medallion transformation in OneLake, semantic models, Power BI, and Data Agents.

This repo now includes a runnable notebook pipeline that generates raw demo data, builds Bronze/Silver/Gold Delta tables, and prepares the Gold layer for a semantic model, Power BI report, and Data Agent.

## Demo scenario

Contoso Retail wants a governed Customer 360 platform. Data arrives through three Fabric ingestion patterns:

- **Shortcut**: external sales/region reference files virtualized into OneLake.
- **Mirroring**: operational customer and product data replicated into Fabric.
- **Copy Job**: batch order and support-ticket files loaded into the Lakehouse.

The data is transformed through Bronze, Silver, and Gold layers, then consumed through a Direct Lake semantic model, Power BI report, and a governed Data Agent.

## Repository contents

| Path | Purpose |
|---|---|
| `scripts\generate_demo_data.py` | Generates deterministic synthetic CSV data for the demo. |
| `data\bronze` | Generated raw source files for Lakehouse ingestion. |
| `fabric\notebooks` | Runnable Fabric notebooks for raw generation, Silver processing, Gold aggregation, and orchestration. |
| `fabric\sql` | Optional Spark SQL script for Bronze/Silver/Gold tables. |
| `fabric\semantic-model` | Suggested DAX measures and model design. |
| `fabric\data-agent` | Data Agent instructions and sample prompts. |
| `fabric\governance` | Security, permissions, lineage, and governance checklist. |
| `docs` | Bill of materials and demo runbook. |

## Quick start

1. Generate demo data:

   ```powershell
   python .\scripts\generate_demo_data.py
   ```

2. Create a Fabric workspace named `Fabric End-to-End Demo`.
3. Create a Lakehouse named `lh_customer360`.
4. Import the notebooks from `fabric\notebooks`.
5. Attach the notebooks to `lh_customer360`.
6. Run `03_run_end_to_end.ipynb`.
7. Create a semantic model over the Gold tables and add the measures from `fabric\semantic-model\measures.dax`.
8. Build the Power BI report and Data Agent using `docs\automated-build-guide.md` and `docs\power-bi-report-spec.md`.

## Git integration demo

To demo Fabric Git integration, use the Fabric-first flow in `docs\fabric-git-integration-demo.md`. Fabric should generate its own item system files; do not rely on hand-authored Fabric metadata.

## Suggested GitHub repository name

`fabric_end-to-end_demo`
