# Fabric end-to-end demo

Customer-ready demo materials for Microsoft Fabric covering administration, governance, ingestion, medallion transformation in OneLake, semantic models, Power BI, and Data Agents.

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
| `fabric\sql` | Spark SQL scripts for Bronze/Silver/Gold tables. |
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
4. Upload files from `data\bronze` into the Lakehouse `Files\bronze` area.
5. Run `fabric\sql\medallion_customer360.sql` in a Fabric notebook or Spark SQL cell.
6. Create a semantic model over the Gold tables and add the measures from `fabric\semantic-model\measures.dax`.
7. Build the Power BI report and Data Agent using the runbook in `docs\demo-runbook.md`.

## Suggested GitHub repository name

`fabric_end-to-end_demo`

