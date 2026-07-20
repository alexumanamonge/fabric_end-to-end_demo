from __future__ import annotations

"""Generate deterministic demo data for the Fabric end-to-end demo.

Outputs (all deterministic from SEED):

  data/bronze/*.csv          Offline fallback CSVs (used by notebook 00 only).
  data/blob/reference/...    Files uploaded to the Storage account -> OneLake SHORTCUT source (regions).
  data/sql/ops_seed.sql      Schema + seed for Azure SQL DB `sqldb-ops`  -> MIRRORING (customers, products).
  data/sql/etl_seed.sql      Schema + seed for Azure SQL DB `sqldb-etl`  -> ETL / Copy Job (orders, support_tickets).

Run:  python scripts/generate_demo_data.py
"""

import csv
import random
from datetime import date, timedelta
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
BRONZE_OUT = ROOT / "data" / "bronze"
BLOB_OUT = ROOT / "data" / "blob" / "reference" / "regions"
SQL_OUT = ROOT / "data" / "sql"
SEED = 20260714

REGIONS = [
    ("R-NA-W", "North America", "West", "United States"),
    ("R-NA-E", "North America", "East", "United States"),
    ("R-LATAM", "Latin America", "Central", "Costa Rica"),
    ("R-EMEA-N", "EMEA", "North", "United Kingdom"),
    ("R-APAC-S", "APAC", "South", "Singapore"),
]

SEGMENTS = ["Enterprise", "Commercial", "SMB", "Public Sector"]
INDUSTRIES = ["Retail", "Financial Services", "Manufacturing", "Healthcare", "Technology"]
PRODUCTS = [
    ("P-100", "Fabric Capacity F64", "Analytics Platform", 8420.0),
    ("P-110", "Power BI Premium", "Business Intelligence", 4995.0),
    ("P-120", "Data Engineering Accelerator", "Services", 12500.0),
    ("P-130", "Security Governance Add-on", "Governance", 6200.0),
    ("P-140", "AI Data Agent Pack", "AI", 7800.0),
    ("P-150", "OneLake Migration Kit", "Migration", 9800.0),
]


def random_date(rng: random.Random, start: date, end: date) -> date:
    return start + timedelta(days=rng.randint(0, (end - start).days))


def build_data() -> dict[str, list[dict[str, Any]]]:
    rng = random.Random(SEED)

    regions = [
        {"region_id": rid, "geo": geo, "sales_region": sr, "country": country}
        for rid, geo, sr, country in REGIONS
    ]

    customers = []
    for index in range(1, 151):
        region = rng.choice(REGIONS)
        customers.append(
            {
                "customer_id": f"C-{index:04d}",
                "customer_name": f"Contoso Customer {index:04d}",
                "segment": rng.choice(SEGMENTS),
                "industry": rng.choice(INDUSTRIES),
                "region_id": region[0],
                "country": region[3],
                "account_owner": rng.choice(["Avery", "Jordan", "Morgan", "Riley", "Taylor"]),
                "created_date": random_date(rng, date(2024, 1, 1), date(2025, 12, 31)).isoformat(),
                "sensitivity_tier": rng.choice(["Public", "General", "Confidential"]),
            }
        )

    products = [
        {"product_id": pid, "product_name": pname, "category": cat, "list_price": price}
        for pid, pname, cat, price in PRODUCTS
    ]

    orders = []
    for index in range(1, 1201):
        customer = rng.choice(customers)
        product = rng.choice(products)
        quantity = rng.randint(1, 8)
        discount = rng.choice([0.0, 0.0, 0.0, 0.05, 0.1, 0.15])
        sales_amount = round(product["list_price"] * quantity * (1 - discount), 2)
        orders.append(
            {
                "order_id": f"O-{index:06d}",
                "customer_id": customer["customer_id"],
                "product_id": product["product_id"],
                "order_date": random_date(rng, date(2025, 1, 1), date(2026, 7, 10)).isoformat(),
                "quantity": quantity,
                "discount_pct": discount,
                "sales_amount": sales_amount,
                "channel": rng.choice(["Direct", "Partner", "Marketplace", "Web"]),
                "source_system": "sqlmi_etl",
            }
        )

    tickets = []
    for index in range(1, 401):
        customer = rng.choice(customers)
        opened = random_date(rng, date(2025, 7, 1), date(2026, 7, 10))
        days_to_close = rng.choice([None, 1, 2, 3, 5, 8, 13])
        tickets.append(
            {
                "ticket_id": f"T-{index:05d}",
                "customer_id": customer["customer_id"],
                "opened_date": opened.isoformat(),
                "closed_date": None if days_to_close is None else (opened + timedelta(days=days_to_close)).isoformat(),
                "priority": rng.choice(["Low", "Medium", "High", "Critical"]),
                "category": rng.choice(["Access", "Performance", "Billing", "Data Quality", "Security"]),
                "satisfaction_score": rng.choice([1, 2, 3, 4, 5, None]),
            }
        )

    return {
        "regions": regions,
        "customers": customers,
        "products": products,
        "orders": orders,
        "support_tickets": tickets,
    }


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        for row in rows:
            writer.writerow({k: ("" if v is None else v) for k, v in row.items()})


# ---------------------------------------------------------------------------
# SQL emitters
# ---------------------------------------------------------------------------

def sql_literal(value: Any, quote: bool) -> str:
    if value is None or value == "":
        return "NULL"
    if quote:
        return "N'" + str(value).replace("'", "''") + "'"
    return str(value)


def emit_insert_batches(table: str, columns: list[str], quoted: list[bool],
                        rows: list[dict[str, Any]], batch_size: int = 500) -> list[str]:
    lines: list[str] = []
    col_list = ", ".join(f"[{c}]" for c in columns)
    for start in range(0, len(rows), batch_size):
        chunk = rows[start:start + batch_size]
        lines.append(f"INSERT INTO {table} ({col_list}) VALUES")
        values = []
        for row in chunk:
            vals = ", ".join(sql_literal(row[c], q) for c, q in zip(columns, quoted))
            values.append(f"  ({vals})")
        lines.append(",\n".join(values) + ";")
        lines.append("GO")
    return lines


def write_ops_sql(data: dict[str, list[dict[str, Any]]]) -> None:
    """sqldb-ops: operational master data replicated via Fabric Mirroring."""
    lines = [
        "-- ===========================================================",
        "-- sqldb-ops : source for Fabric MIRRORING",
        "-- Tables: dbo.customers, dbo.products",
        "-- Idempotent: drops and recreates tables, then seeds.",
        "-- ===========================================================",
        "SET NOCOUNT ON;",
        "GO",
        "IF OBJECT_ID('dbo.customers','U') IS NOT NULL DROP TABLE dbo.customers;",
        "IF OBJECT_ID('dbo.products','U')  IS NOT NULL DROP TABLE dbo.products;",
        "GO",
        "CREATE TABLE dbo.products (",
        "  product_id   VARCHAR(10)   NOT NULL PRIMARY KEY,",
        "  product_name NVARCHAR(100) NOT NULL,",
        "  category     NVARCHAR(50)  NOT NULL,",
        "  list_price   DECIMAL(12,2) NOT NULL",
        ");",
        "GO",
        "CREATE TABLE dbo.customers (",
        "  customer_id      VARCHAR(10)   NOT NULL PRIMARY KEY,",
        "  customer_name    NVARCHAR(100) NOT NULL,",
        "  segment          NVARCHAR(50)  NOT NULL,",
        "  industry         NVARCHAR(50)  NOT NULL,",
        "  region_id        VARCHAR(10)   NOT NULL,",
        "  country          NVARCHAR(50)  NOT NULL,",
        "  account_owner    NVARCHAR(50)  NOT NULL,",
        "  created_date     DATE          NOT NULL,",
        "  sensitivity_tier NVARCHAR(20)  NOT NULL",
        ");",
        "GO",
    ]
    lines += emit_insert_batches(
        "dbo.products",
        ["product_id", "product_name", "category", "list_price"],
        [True, True, True, False],
        data["products"],
    )
    lines += emit_insert_batches(
        "dbo.customers",
        ["customer_id", "customer_name", "segment", "industry", "region_id",
         "country", "account_owner", "created_date", "sensitivity_tier"],
        [True, True, True, True, True, True, True, True, True],
        data["customers"],
    )
    _write_lines(SQL_OUT / "ops_seed.sql", lines)


def write_etl_sql(data: dict[str, list[dict[str, Any]]]) -> None:
    """sqldb-etl: transactional data batch-loaded via Fabric Copy Job / pipeline."""
    lines = [
        "-- ===========================================================",
        "-- sqldb-etl : source for Fabric ETL / Copy Job",
        "-- (stands in for SQL Managed Instance)",
        "-- Tables: dbo.orders, dbo.support_tickets",
        "-- Idempotent: drops and recreates tables, then seeds.",
        "-- ===========================================================",
        "SET NOCOUNT ON;",
        "GO",
        "IF OBJECT_ID('dbo.orders','U')          IS NOT NULL DROP TABLE dbo.orders;",
        "IF OBJECT_ID('dbo.support_tickets','U') IS NOT NULL DROP TABLE dbo.support_tickets;",
        "GO",
        "CREATE TABLE dbo.orders (",
        "  order_id      VARCHAR(12)   NOT NULL PRIMARY KEY,",
        "  customer_id   VARCHAR(10)   NOT NULL,",
        "  product_id    VARCHAR(10)   NOT NULL,",
        "  order_date    DATE          NOT NULL,",
        "  quantity      INT           NOT NULL,",
        "  discount_pct  DECIMAL(5,2)  NOT NULL,",
        "  sales_amount  DECIMAL(14,2) NOT NULL,",
        "  channel       NVARCHAR(30)  NOT NULL,",
        "  source_system NVARCHAR(30)  NOT NULL",
        ");",
        "GO",
        "CREATE TABLE dbo.support_tickets (",
        "  ticket_id          VARCHAR(12)  NOT NULL PRIMARY KEY,",
        "  customer_id        VARCHAR(10)  NOT NULL,",
        "  opened_date        DATE         NOT NULL,",
        "  closed_date        DATE         NULL,",
        "  priority           NVARCHAR(20) NOT NULL,",
        "  category           NVARCHAR(30) NOT NULL,",
        "  satisfaction_score INT          NULL",
        ");",
        "GO",
    ]
    lines += emit_insert_batches(
        "dbo.orders",
        ["order_id", "customer_id", "product_id", "order_date", "quantity",
         "discount_pct", "sales_amount", "channel", "source_system"],
        [True, True, True, True, False, False, False, True, True],
        data["orders"],
    )
    lines += emit_insert_batches(
        "dbo.support_tickets",
        ["ticket_id", "customer_id", "opened_date", "closed_date", "priority",
         "category", "satisfaction_score"],
        [True, True, True, True, True, True, False],
        data["support_tickets"],
    )
    _write_lines(SQL_OUT / "etl_seed.sql", lines)


def _write_lines(path: Path, lines: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    data = build_data()

    # 1. Offline fallback CSVs (notebook 00).
    for name, rows in data.items():
        write_csv(BRONZE_OUT / f"{name}.csv", rows)

    # 2. Shortcut source file (regions) uploaded to the Storage account.
    write_csv(BLOB_OUT / "regions.csv", data["regions"])

    # 3. SQL seed scripts for the two Azure SQL databases.
    write_ops_sql(data)
    write_etl_sql(data)

    print("Generated demo data:")
    print(f"  CSV fallback   -> {BRONZE_OUT}")
    print(f"  Shortcut files -> {BLOB_OUT}")
    print(f"  SQL seeds      -> {SQL_OUT} (ops_seed.sql, etl_seed.sql)")


if __name__ == "__main__":
    main()
