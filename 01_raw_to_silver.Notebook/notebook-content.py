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

# # 01 - Bronze to Silver
# # Reads the **raw** data landed in `LH_Bronze` by the three ingestion patterns and
# produces cleansed, conformed, combined **Silver** tables in `LH_Silver`.
# # **Bronze inputs (canonical locations):**
# # | Entity | Location | Ingestion pattern |
# |---|---|---|
# | customers, products | `LH_Bronze/Tables/*` | Mirroring (`sqldb-ops`) |
# | orders, support_tickets | `LH_Bronze/Tables/*` | ETL / Copy Job (`sqldb-etl`) |
# | regions | `LH_Bronze/Files/shortcuts/regions` | Shortcut (ADLS Gen2) |
# # If Bronze is empty, wire the ingestion (see `docs/ingestion-*.md`) or run the
# optional `00_generate_raw_data` notebook first.

# CELL ********************

from pyspark.sql import functions as F
from pyspark.sql.utils import AnalysisException

WORKSPACE_NAME = ""
BRONZE_LAKEHOUSE = "LH_Bronze"
SILVER_LAKEHOUSE = "LH_Silver"


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
SILVER_TABLES = lakehouse_path(SILVER_LAKEHOUSE, "Tables")

MISSING_HINT = (
    "Bronze data not found. Wire the ingestion patterns (docs/ingestion-*.md) "
    "or run the optional 00_generate_raw_data notebook first."
)


def read_bronze_table(name: str):
    """Read a Bronze Delta table landed by Mirroring or the Copy Job."""
    try:
        return spark.read.format("delta").load(f"{BRONZE_TABLES}/{name}")
    except AnalysisException as exc:
        raise RuntimeError(f"Could not read LH_Bronze/Tables/{name}. {MISSING_HINT}") from exc


def read_regions_shortcut():
    """Read the regions reference file exposed via the ADLS Gen2 shortcut."""
    try:
        return (
            spark.read.option("header", "true").option("inferSchema", "true").csv(REGIONS_SHORTCUT_DIR)
        )
    except AnalysisException as exc:
        raise RuntimeError(f"Could not read LH_Bronze/Files/shortcuts/regions. {MISSING_HINT}") from exc


# CELL ********************

# --- Read raw Bronze data from the three ingestion patterns ---
raw_customers = read_bronze_table("customers")
raw_products = read_bronze_table("products")
raw_orders = read_bronze_table("orders")
raw_tickets = read_bronze_table("support_tickets")
raw_regions = read_regions_shortcut()

# --- Silver: cleanse + conform each entity ---
silver_regions = raw_regions.dropDuplicates(["region_id"])

silver_products = (
    raw_products
    .dropDuplicates(["product_id"])
    .withColumn("list_price", F.col("list_price").cast("double"))
)

silver_customers = (
    raw_customers
    .dropDuplicates(["customer_id"])
    .withColumn("customer_name", F.initcap("customer_name"))
    .withColumn("created_date", F.to_date("created_date"))
    .join(silver_regions, "region_id", "left")
    .select(
        "customer_id",
        "customer_name",
        "segment",
        "industry",
        "region_id",
        "geo",
        "sales_region",
        F.coalesce(raw_customers["country"], silver_regions["country"]).alias("country"),
        "account_owner",
        "created_date",
        "sensitivity_tier",
    )
)

silver_orders = (
    raw_orders
    .dropDuplicates(["order_id"])
    .withColumn("order_date", F.to_date("order_date"))
    .withColumn("quantity", F.col("quantity").cast("int"))
    .withColumn("discount_pct", F.col("discount_pct").cast("double"))
    .withColumn("sales_amount", F.col("sales_amount").cast("double"))
    .filter(F.col("sales_amount") > 0)
)

silver_tickets = (
    raw_tickets
    .dropDuplicates(["ticket_id"])
    .withColumn("opened_date", F.to_date("opened_date"))
    .withColumn("closed_date", F.to_date("closed_date"))
    .withColumn("satisfaction_score", F.col("satisfaction_score").cast("int"))
)

# --- Silver: combine sources into a conformed customer-orders fact ---
silver_customer_orders = (
    silver_orders.alias("o")
    .join(silver_customers.alias("c"), "customer_id", "inner")
    .join(silver_products.alias("p"), "product_id", "left")
    .select(
        "order_id",
        "order_date",
        "customer_id",
        "customer_name",
        "segment",
        "industry",
        "geo",
        "sales_region",
        "country",
        "account_owner",
        "sensitivity_tier",
        "product_id",
        "product_name",
        "category",
        "quantity",
        "discount_pct",
        "sales_amount",
        "channel",
        "source_system",
    )
)

# --- Persist Silver ---
silver_regions.write.mode("overwrite").format("delta").save(f"{SILVER_TABLES}/regions")
silver_customers.write.mode("overwrite").format("delta").save(f"{SILVER_TABLES}/customers")
silver_products.write.mode("overwrite").format("delta").save(f"{SILVER_TABLES}/products")
silver_orders.write.mode("overwrite").format("delta").save(f"{SILVER_TABLES}/orders")
silver_tickets.write.mode("overwrite").format("delta").save(f"{SILVER_TABLES}/support_tickets")
silver_customer_orders.write.mode("overwrite").format("delta").save(f"{SILVER_TABLES}/customer_orders")

display(
    spark.createDataFrame(
        [
            ("LH_Silver.customers", silver_customers.count()),
            ("LH_Silver.products", silver_products.count()),
            ("LH_Silver.orders", silver_orders.count()),
            ("LH_Silver.support_tickets", silver_tickets.count()),
            ("LH_Silver.customer_orders", silver_customer_orders.count()),
        ],
        ["table_name", "row_count"],
    )
)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
