# Demo data

Regenerate all demo data with:

```powershell
python .\scripts\generate_demo_data.py
```

The generator is deterministic (fixed seed) and uses only the Python standard library.
It produces three kinds of output that map to the three Fabric ingestion patterns.

## 1. Azure SQL seed scripts — `data\sql\`

| File | Target Azure SQL DB | Tables | Fabric ingestion pattern |
|---|---|---|---|
| `ops_seed.sql` | `sqldb-ops` | `customers`, `products` | **Mirroring** |
| `etl_seed.sql` | `sqldb-etl` | `orders`, `support_tickets` | **ETL / Copy Job** |

Loaded by `scripts\Seed-Data.ps1` (or `Deploy-Azure.ps1`).

## 2. Shortcut source files — `data\blob\reference\`

| File | Uploaded to | Fabric ingestion pattern |
|---|---|---|
| `regions\regions.csv` | Storage account container `reference` | **Shortcut** (OneLake virtualizes, no copy) |

## 3. Offline fallback CSVs — `data\bronze\`

`customers.csv`, `products.csv`, `regions.csv`, `orders.csv`, `support_tickets.csv`.

These are **only** used by notebook `00_generate_raw_data` when you want to run the
medallion demo **without** deploying Azure sources. The primary flow reads from the
three real ingestion patterns above.
