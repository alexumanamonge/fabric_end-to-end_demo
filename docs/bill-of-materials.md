# Bill of materials

## Fabric items to create

| Item | Suggested name | Purpose |
|---|---|---|
| Workspace | `Fabric End-to-End Demo` | Governed collaboration boundary |
| Lakehouse | `LH_Bronze` | Raw files and Bronze raw Delta tables |
| Lakehouse | `LH_Silver` | Cleansed and joined Silver Delta tables |
| Lakehouse | `LH_Gold` | Curated Gold tables for consumption |
| Shortcut | `regions_shortcut` | Demonstrate virtualization without copy |
| Mirrored database | `mirror_customer_ops` | Demonstrate operational replication |
| Copy Job | `copy_orders_support_to_bronze` | Demonstrate managed batch ingestion |
| Notebook | `nb_customer360_medallion` | Bronze to Silver to Gold transformation |
| Semantic model | `sm_customer360_gold` | Governed business metrics |
| Power BI report | `Customer 360 Executive Overview` | Business consumption |
| Data Agent | `Customer Insights Agent` | Natural language consumption |

## Local assets

| Asset | Path |
|---|---|
| Data generator | `scripts\generate_demo_data.py` |
| Synthetic data | `data\bronze` |
| Medallion SQL | `fabric\sql\medallion_customer360.sql` |
| DAX measures | `fabric\semantic-model\measures.dax` |
| Data Agent prompt | `fabric\data-agent\instructions.md` |
| Governance checklist | `fabric\governance\checklist.md` |

## Demo data entities

- Regions
- Customers
- Products
- Orders
- Support tickets

## Prerequisites

- Microsoft Fabric tenant with capacity enabled.
- Permission to create workspaces, Lakehouses, notebooks, semantic models, reports, and Data Agents.
- Optional source systems for live shortcut/mirroring demos. If unavailable, use the generated CSV files as stand-ins and explain the intended ingestion pattern.
