from __future__ import annotations

import csv
import random
from datetime import date, timedelta
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "bronze"
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
    ("P-100", "Fabric Capacity F64", "Analytics Platform", 8420),
    ("P-110", "Power BI Premium", "Business Intelligence", 4995),
    ("P-120", "Data Engineering Accelerator", "Services", 12500),
    ("P-130", "Security Governance Add-on", "Governance", 6200),
    ("P-140", "AI Data Agent Pack", "AI", 7800),
    ("P-150", "OneLake Migration Kit", "Migration", 9800),
]


def write_csv(name: str, rows: list[dict[str, object]]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def random_date(rng: random.Random, start: date, end: date) -> date:
    days = (end - start).days
    return start + timedelta(days=rng.randint(0, days))


def build_data() -> None:
    rng = random.Random(SEED)

    regions = [
        {"region_id": region_id, "geo": geo, "sales_region": sales_region, "country": country}
        for region_id, geo, sales_region, country in REGIONS
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
        {
            "product_id": product_id,
            "product_name": product_name,
            "category": category,
            "list_price": list_price,
        }
        for product_id, product_name, category, list_price in PRODUCTS
    ]

    orders = []
    for index in range(1, 1201):
        customer = rng.choice(customers)
        product = rng.choice(products)
        quantity = rng.randint(1, 8)
        discount = rng.choice([0, 0, 0.05, 0.1, 0.15])
        sales_amount = round(product["list_price"] * quantity * (1 - discount), 2)
        order_date = random_date(rng, date(2025, 1, 1), date(2026, 7, 10))
        orders.append(
            {
                "order_id": f"O-{index:06d}",
                "customer_id": customer["customer_id"],
                "product_id": product["product_id"],
                "order_date": order_date.isoformat(),
                "quantity": quantity,
                "discount_pct": discount,
                "sales_amount": sales_amount,
                "channel": rng.choice(["Direct", "Partner", "Marketplace", "Web"]),
                "source_system": rng.choice(["copy_job", "shortcut", "mirror"]),
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
                "closed_date": "" if days_to_close is None else (opened + timedelta(days=days_to_close)).isoformat(),
                "priority": rng.choice(["Low", "Medium", "High", "Critical"]),
                "category": rng.choice(["Access", "Performance", "Billing", "Data Quality", "Security"]),
                "satisfaction_score": rng.choice([1, 2, 3, 4, 5, ""]),
            }
        )

    write_csv("regions_shortcut.csv", regions)
    write_csv("customers_mirrored.csv", customers)
    write_csv("products_mirrored.csv", products)
    write_csv("orders_copy_job.csv", orders)
    write_csv("support_tickets_copy_job.csv", tickets)


if __name__ == "__main__":
    build_data()
    print(f"Generated demo data in {OUT}")

