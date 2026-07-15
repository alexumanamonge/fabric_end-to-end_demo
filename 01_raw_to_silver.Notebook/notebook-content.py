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

# # 01 - Raw to Bronze and Silver
# 
# Reads raw CSV folders from `LH_Bronze`, lands immutable Bronze Delta tables in `LH_Bronze`, then creates cleansed/joined Silver tables in `LH_Silver`.

# CELL ********************

from pyspark.sql import functions as F

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


RAW_BASE = lakehouse_path(BRONZE_LAKEHOUSE, "Files/raw/customer360")
BRONZE_TABLES = lakehouse_path(BRONZE_LAKEHOUSE, "Tables")
SILVER_TABLES = lakehouse_path(SILVER_LAKEHOUSE, "Tables")

def read_raw(entity: str):
    return (
        spark.read
        .option("header", "true")
        .option("inferSchema", "true")
        .csv(f"{RAW_BASE}/{entity}")
    )

raw_regions = read_raw("regions")
raw_customers = read_raw("customers")
raw_products = read_raw("products")
raw_orders = read_raw("orders")
raw_tickets = read_raw("support_tickets")

raw_regions.write.mode("overwrite").format("delta").save(f"{BRONZE_TABLES}/regions_raw")
raw_customers.write.mode("overwrite").format("delta").save(f"{BRONZE_TABLES}/customers_raw")
raw_products.write.mode("overwrite").format("delta").save(f"{BRONZE_TABLES}/products_raw")
raw_orders.write.mode("overwrite").format("delta").save(f"{BRONZE_TABLES}/orders_raw")
raw_tickets.write.mode("overwrite").format("delta").save(f"{BRONZE_TABLES}/support_tickets_raw")

silver_customers = (
    raw_customers
    .dropDuplicates(["customer_id"])
    .withColumn("customer_name", F.initcap("customer_name"))
    .withColumn("created_date", F.to_date("created_date"))
    .join(raw_regions, "region_id", "left")
    .select(
        "customer_id",
        "customer_name",
        "segment",
        "industry",
        "region_id",
        "geo",
        "sales_region",
        F.coalesce(raw_customers.country, raw_regions.country).alias("country"),
        "account_owner",
        "created_date",
        "sensitivity_tier",
    )
)

silver_products = raw_products.dropDuplicates(["product_id"])

silver_orders = (
    raw_orders
    .dropDuplicates(["order_id"])
    .withColumn("order_date", F.to_date("order_date"))
    .withColumn("quantity", F.col("quantity").cast("int"))
    .withColumn("discount_pct", F.col("discount_pct").cast("double"))
    .withColumn("sales_amount", F.col("sales_amount").cast("double"))
    .filter(F.col("sales_amount") > 0)
)

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

silver_tickets = (
    raw_tickets
    .dropDuplicates(["ticket_id"])
    .withColumn("opened_date", F.to_date("opened_date"))
    .withColumn("closed_date", F.to_date("closed_date"))
    .withColumn("satisfaction_score", F.col("satisfaction_score").cast("int"))
)

silver_customers.write.mode("overwrite").format("delta").save(f"{SILVER_TABLES}/customers")
silver_products.write.mode("overwrite").format("delta").save(f"{SILVER_TABLES}/products")
silver_orders.write.mode("overwrite").format("delta").save(f"{SILVER_TABLES}/orders")
silver_customer_orders.write.mode("overwrite").format("delta").save(f"{SILVER_TABLES}/customer_orders")
silver_tickets.write.mode("overwrite").format("delta").save(f"{SILVER_TABLES}/support_tickets")

display(
    spark.createDataFrame(
        [
            ("LH_Bronze.customers_raw", raw_customers.count()),
            ("LH_Bronze.orders_raw", raw_orders.count()),
            ("LH_Silver.customers", silver_customers.count()),
            ("LH_Silver.customer_orders", silver_customer_orders.count()),
            ("LH_Silver.support_tickets", silver_tickets.count()),
        ],
        ["table_name", "row_count"],
    )
)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
