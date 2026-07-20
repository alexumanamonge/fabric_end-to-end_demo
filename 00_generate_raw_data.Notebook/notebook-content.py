# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse_name": "",
# META       "default_lakehouse_workspace_id": "",
# META       "known_lakehouses": []
# META     }
# META   }
# META }

# MARKDOWN ********************

# # 00 - (OPTIONAL) Offline Bronze seed
#
# **You usually do NOT run this notebook.** The primary demo lands Bronze data from
# three real Azure ingestion patterns:
#
# | Bronze object | Real ingestion pattern | Setup guide |
# |---|---|---|
# | `Tables/customers`, `Tables/products` | **Mirroring** from `sqldb-ops` | `docs/ingestion-mirroring.md` |
# | `Files/shortcuts/regions/regions.csv` | **Shortcut** from ADLS Gen2 | `docs/ingestion-shortcut.md` |
# | `Tables/orders`, `Tables/support_tickets` | **ETL / Copy Job** from `sqldb-etl` | `docs/ingestion-etl-copyjob.md` |
#
# Run this notebook **only** to seed Bronze with the same shapes **without** deploying
# Azure sources (e.g. a laptop-only dry run). It writes the identical canonical
# locations that the real ingestion produces, so `01_raw_to_silver` works either way.

# CELL ********************

from datetime import date, timedelta
import random
from pyspark.sql import Row

WORKSPACE_NAME = ""
BRONZE_LAKEHOUSE = "LH_Bronze"


def current_workspace_name() -> str:
    if WORKSPACE_NAME:
        return WORKSPACE_NAME
    try:
        import notebookutils

        context = notebookutils.runtime.context
        if callable(context):
            context = context()
        if isinstance(context, dict):
            workspace_name = context.get("currentWorkspaceName") or context.get("workspaceName")
            if workspace_name:
                return workspace_name
    except Exception:
        pass
    raise ValueError("Set WORKSPACE_NAME to your Fabric workspace name before running this notebook.")


def lakehouse_path(lakehouse_name: str, relative_path: str) -> str:
    return f"abfss://{current_workspace_name()}@onelake.dfs.fabric.microsoft.com/{lakehouse_name}.Lakehouse/{relative_path}"


BRONZE_TABLES = lakehouse_path(BRONZE_LAKEHOUSE, "Tables")
REGIONS_SHORTCUT_DIR = lakehouse_path(BRONZE_LAKEHOUSE, "Files/shortcuts/regions")

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
    Row(region_id=r[0], geo=r[1], sales_region=r[2], country=r[3]) for r in regions_seed
]

customers = []
for index in range(1, 151):
    region = rng.choice(regions_seed)
    customers.append(
        Row(
            customer_id=f"C-{index:04d}",
            customer_name=f"Contoso Customer {index:04d}",
            segment=rng.choice(segments),
            industry=rng.choice(industries),
            region_id=region[0],
            country=region[3],
            account_owner=rng.choice(["Avery", "Jordan", "Morgan", "Riley", "Taylor"]),
            created_date=random_date(date(2024, 1, 1), date(2025, 12, 31)),
            sensitivity_tier=rng.choice(["Public", "General", "Confidential"]),
        )
    )

products = [
    Row(product_id=p[0], product_name=p[1], category=p[2], list_price=p[3]) for p in products_seed
]

orders = []
for index in range(1, 1201):
    customer = rng.choice(customers)
    product = rng.choice(products)
    quantity = rng.randint(1, 8)
    discount_pct = rng.choice([0.0, 0.0, 0.0, 0.05, 0.1, 0.15])
    sales_amount = round(product.list_price * quantity * (1 - discount_pct), 2)
    orders.append(
        Row(
            order_id=f"O-{index:06d}",
            customer_id=customer.customer_id,
            product_id=product.product_id,
            order_date=random_date(date(2025, 1, 1), date(2026, 7, 10)),
            quantity=quantity,
            discount_pct=discount_pct,
            sales_amount=sales_amount,
            channel=rng.choice(["Direct", "Partner", "Marketplace", "Web"]),
            source_system="sqlmi_etl",
        )
    )

tickets = []
for index in range(1, 401):
    customer = rng.choice(customers)
    opened = date.fromisoformat(random_date(date(2025, 7, 1), date(2026, 7, 10)))
    days_to_close = rng.choice([None, 1, 2, 3, 5, 8, 13])
    tickets.append(
        Row(
            ticket_id=f"T-{index:05d}",
            customer_id=customer.customer_id,
            opened_date=opened.isoformat(),
            closed_date=None if days_to_close is None else (opened + timedelta(days=days_to_close)).isoformat(),
            priority=rng.choice(["Low", "Medium", "High", "Critical"]),
            category=rng.choice(["Access", "Performance", "Billing", "Data Quality", "Security"]),
            satisfaction_score=rng.choice([1, 2, 3, 4, 5, None]),
        )
    )

# Mirroring + Copy Job land Delta TABLES in Bronze -> emulate that here.
spark.createDataFrame(customers).write.mode("overwrite").format("delta").save(f"{BRONZE_TABLES}/customers")
spark.createDataFrame(products).write.mode("overwrite").format("delta").save(f"{BRONZE_TABLES}/products")
spark.createDataFrame(orders).write.mode("overwrite").format("delta").save(f"{BRONZE_TABLES}/orders")
spark.createDataFrame(tickets).write.mode("overwrite").format("delta").save(f"{BRONZE_TABLES}/support_tickets")

# Shortcut lands a CSV FILE in Bronze -> emulate that here.
(
    spark.createDataFrame(regions)
    .coalesce(1)
    .write.mode("overwrite")
    .option("header", "true")
    .csv(REGIONS_SHORTCUT_DIR)
)

display(
    spark.createDataFrame(
        [
            ("LH_Bronze.Tables.customers", len(customers)),
            ("LH_Bronze.Tables.products", len(products)),
            ("LH_Bronze.Tables.orders", len(orders)),
            ("LH_Bronze.Tables.support_tickets", len(tickets)),
            ("LH_Bronze.Files.shortcuts/regions", len(regions)),
        ],
        ["bronze_object", "row_count"],
    )
)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
