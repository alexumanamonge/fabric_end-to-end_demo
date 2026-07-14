# Fabric notebook source
# METADATA ********************
# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {}
# META }
# CELL ********************
# MAGIC # 00 - Generate raw demo data
# MAGIC
# MAGIC Attach this notebook to Lakehouse `lh_customer360`. It creates deterministic raw CSV folders under `Files/raw/customer360` so the rest of the demo can run without any external source-system dependency.
# METADATA ********************
# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
# CELL ********************
from datetime import date, timedelta
import random
from pyspark.sql import Row

RAW_BASE = "/lakehouse/default/Files/raw/customer360"
SEED = 20260714
rng = random.Random(SEED)

regions_seed = [
    ("R-NA-W", "North America", "West", "United States"),
    ("R-NA-E", "North America", "East", "United States"),
    ("R-LATAM", "Latin America", "Central", "Costa Rica"),
    ("R-EMEA-N", "EMEA", "North", "United Kingdom"),
    ("R-APAC-S", "APAC", "South", "Singapore"),
]
segments = ["Enterprise", "Commercial", "SMB", "Public Sector"]
industries = ["Retail", "Financial Services", "Manufacturing", "Healthcare", "Technology"]
products_seed = [
    ("P-100", "Fabric Capacity F64", "Analytics Platform", 8420.0),
    ("P-110", "Power BI Premium", "Business Intelligence", 4995.0),
    ("P-120", "Data Engineering Accelerator", "Services", 12500.0),
    ("P-130", "Security Governance Add-on", "Governance", 6200.0),
    ("P-140", "AI Data Agent Pack", "AI", 7800.0),
    ("P-150", "OneLake Migration Kit", "Migration", 9800.0),
]

def random_date(start: date, end: date) -> str:
    return (start + timedelta(days=rng.randint(0, (end - start).days))).isoformat()

regions = [
    Row(region_id=region_id, geo=geo, sales_region=sales_region, country=country)
    for region_id, geo, sales_region, country in regions_seed
]

customers = []
for index in range(1, 151):
    region = rng.choice(regions_seed)
    customers.append(Row(
        customer_id=f"C-{index:04d}",
        customer_name=f"Contoso Customer {index:04d}",
        segment=rng.choice(segments),
        industry=rng.choice(industries),
        region_id=region[0],
        country=region[3],
        account_owner=rng.choice(["Avery", "Jordan", "Morgan", "Riley", "Taylor"]),
        created_date=random_date(date(2024, 1, 1), date(2025, 12, 31)),
        sensitivity_tier=rng.choice(["Public", "General", "Confidential"]),
    ))

products = [
    Row(product_id=product_id, product_name=product_name, category=category, list_price=list_price)
    for product_id, product_name, category, list_price in products_seed
]

orders = []
for index in range(1, 1201):
    customer = rng.choice(customers)
    product = rng.choice(products)
    quantity = rng.randint(1, 8)
    discount_pct = rng.choice([0.0, 0.0, 0.05, 0.1, 0.15])
    sales_amount = round(product.list_price * quantity * (1 - discount_pct), 2)
    orders.append(Row(
        order_id=f"O-{index:06d}",
        customer_id=customer.customer_id,
        product_id=product.product_id,
        order_date=random_date(date(2025, 1, 1), date(2026, 7, 10)),
        quantity=quantity,
        discount_pct=discount_pct,
        sales_amount=sales_amount,
        channel=rng.choice(["Direct", "Partner", "Marketplace", "Web"]),
        source_system=rng.choice(["copy_job", "shortcut", "mirror"]),
    ))

tickets = []
for index in range(1, 401):
    customer = rng.choice(customers)
    opened = date.fromisoformat(random_date(date(2025, 7, 1), date(2026, 7, 10)))
    days_to_close = rng.choice([None, 1, 2, 3, 5, 8, 13])
    tickets.append(Row(
        ticket_id=f"T-{index:05d}",
        customer_id=customer.customer_id,
        opened_date=opened.isoformat(),
        closed_date=None if days_to_close is None else (opened + timedelta(days=days_to_close)).isoformat(),
        priority=rng.choice(["Low", "Medium", "High", "Critical"]),
        category=rng.choice(["Access", "Performance", "Billing", "Data Quality", "Security"]),
        satisfaction_score=rng.choice([1, 2, 3, 4, 5, None]),
    ))

raw_sets = {
    "regions": regions,
    "customers": customers,
    "products": products,
    "orders": orders,
    "support_tickets": tickets,
}

for name, rows in raw_sets.items():
    spark.createDataFrame(rows).coalesce(1).write.mode("overwrite").option("header", "true").csv(f"{RAW_BASE}/{name}")

display(spark.createDataFrame([(name, len(rows), f"{RAW_BASE}/{name}") for name, rows in raw_sets.items()], ["raw_entity", "row_count", "path"]))
# METADATA ********************
# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
