# Demo data

Run `python .\scripts\generate_demo_data.py` from the repository root to regenerate the Bronze CSV files.

The generator is deterministic and uses only Python standard-library modules.

| File | Intended ingestion pattern |
|---|---|
| `bronze\regions_shortcut.csv` | Shortcut reference-data example |
| `bronze\customers_mirrored.csv` | Mirroring source stand-in |
| `bronze\products_mirrored.csv` | Mirroring source stand-in |
| `bronze\orders_copy_job.csv` | Copy Job batch ingestion |
| `bronze\support_tickets_copy_job.csv` | Copy Job batch ingestion |

