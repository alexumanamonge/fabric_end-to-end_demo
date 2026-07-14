# Fabric notebook source
# METADATA ********************
# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {}
# META }
# CELL ********************
# MAGIC # 01 - Raw to Bronze and Silver
# MAGIC
# MAGIC Reads raw CSV folders from OneLake, lands immutable Bronze Delta tables, then creates cleansed/joined Silver tables.
# METADATA ********************
# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
# CELL ********************
from pyspark.sql import functions as F

RAW_BASE = "/lakehouse/default/Files/raw/customer360"

spark.sql("CREATE DATABASE IF NOT EXISTS bronze")
spark.sql("CREATE DATABASE IF NOT EXISTS silver")

def read_raw(entity: str):
    return spark.read.option("header", "true").option("inferSchema", "true").csv(f"{RAW_BASE}/{entity}")

raw_regions = read_raw("regions")
raw_customers = read_raw("customers")
raw_products = read_raw("products")
raw_orders = read_raw("orders")
raw_tickets = read_raw("support_tickets")

raw_regions.write.mode("overwrite").format("delta").saveAsTable("bronze.regions_raw")
raw_customers.write.mode("overwrite").format("delta").saveAsTable("bronze.customers_raw")
raw_products.write.mode("overwrite").format("delta").saveAsTable("bronze.products_raw")
raw_orders.write.mode("overwrite").format("delta").saveAsTable("bronze.orders_raw")
raw_tickets.write.mode("overwrite").format("delta").saveAsTable("bronze.support_tickets_raw")

silver_customers = (
    raw_customers
    .dropDuplicates(["customer_id"])
    .withColumn("customer_name", F.initcap("customer_name"))
    .withColumn("created_date", F.to_date("created_date"))
    .join(raw_regions, "region_id", "left")
    .select(
        "customer_id", "customer_name", "segment", "industry", "region_id", "geo", "sales_region",
        F.coalesce(raw_customers.country, raw_regions.country).alias("country"),
        "account_owner", "created_date", "sensitivity_tier"
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
        "o.order_id", "o.order_date", "o.customer_id", "c.customer_name", "c.segment", "c.industry",
        "c.geo", "c.sales_region", "c.country", "c.account_owner", "c.sensitivity_tier",
        "o.product_id", "p.product_name", "p.category", "o.quantity", "o.discount_pct",
        "o.sales_amount", "o.channel", "o.source_system"
    )
)

silver_tickets = (
    raw_tickets
    .dropDuplicates(["ticket_id"])
    .withColumn("opened_date", F.to_date("opened_date"))
    .withColumn("closed_date", F.to_date("closed_date"))
    .withColumn("satisfaction_score", F.col("satisfaction_score").cast("int"))
)

silver_customers.write.mode("overwrite").format("delta").saveAsTable("silver.customers")
silver_products.write.mode("overwrite").format("delta").saveAsTable("silver.products")
silver_orders.write.mode("overwrite").format("delta").saveAsTable("silver.orders")
silver_customer_orders.write.mode("overwrite").format("delta").saveAsTable("silver.customer_orders")
silver_tickets.write.mode("overwrite").format("delta").saveAsTable("silver.support_tickets")

display(spark.sql("""
SELECT 'bronze.customers_raw' AS table_name, count(*) AS row_count FROM bronze.customers_raw
UNION ALL SELECT 'bronze.orders_raw', count(*) FROM bronze.orders_raw
UNION ALL SELECT 'silver.customers', count(*) FROM silver.customers
UNION ALL SELECT 'silver.customer_orders', count(*) FROM silver.customer_orders
UNION ALL SELECT 'silver.support_tickets', count(*) FROM silver.support_tickets
"""))
# METADATA ********************
# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
