# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "f42ffc3d-869e-463b-a2c9-101372a1342d",
# META       "default_lakehouse_name": "lh_customer360",
# META       "default_lakehouse_workspace_id": "c60a59f4-22d9-485d-a255-352ca532bc92",
# META       "known_lakehouses": [
# META         {
# META           "id": "f42ffc3d-869e-463b-a2c9-101372a1342d"
# META         }
# META       ]
# META     }
# META   }
# META }

# MARKDOWN ********************

# # 02 - Silver to Gold
# 
# Creates business-ready Gold tables that are intended to back the semantic model, Power BI report, and Data Agent.

# CELL ********************

from pyspark.sql import functions as F

# Ensure the gold database exists
spark.sql("CREATE DATABASE IF NOT EXISTS gold")

# Read required Silver tables
customer_orders = spark.table("silver.customer_orders")
customers = spark.table("silver.customers")
orders = spark.table("silver.orders")
tickets = spark.table("silver.support_tickets")

# Gold: sales summary by geo/region/month
gold_sales_summary = (
    customer_orders
    .withColumn("sales_year", F.year("order_date"))
    .withColumn("sales_month", F.month("order_date"))
    .groupBy(
        "geo",
        "sales_region",
        "country",
        "segment",
        "industry",
        "category",
        "sales_year",
        "sales_month",
    )
    .agg(
        F.sum("sales_amount").alias("total_sales"),
        F.countDistinct("customer_id").alias("active_customers"),
        F.countDistinct("order_id").alias("order_count"),
        F.avg("discount_pct").alias("average_discount_pct"),
    )
)

# Support ticket summary per customer
ticket_summary = (
    tickets
    .groupBy("customer_id")
    .agg(
        F.countDistinct("ticket_id").alias("support_ticket_count"),
        F.avg("satisfaction_score").alias("average_satisfaction_score"),
        F.sum(F.when(F.col("priority") == "Critical", 1).otherwise(0)).alias("critical_ticket_count"),
    )
)

# Order summary per customer
order_summary = (
    orders
    .groupBy("customer_id")
    .agg(
        F.countDistinct("order_id").alias("order_count"),
        F.sum("sales_amount").alias("lifetime_sales"),
        F.max("order_date").alias("last_order_date"),
    )
)

# Customer 360 view
gold_customer_360 = (
    customers
    .join(order_summary, "customer_id", "left")
    .join(ticket_summary, "customer_id", "left")
    .fillna(
        {
            "order_count": 0,
            "lifetime_sales": 0.0,
            "support_ticket_count": 0,
            "critical_ticket_count": 0,
        }
    )
)

# Executive KPIs
gold_customer_360.createOrReplaceTempView("gold_customer_360_temp")

gold_executive_kpis = spark.sql(
    """
    SELECT
      COUNT(DISTINCT customer_id) AS total_customers,
      SUM(lifetime_sales) AS total_sales,
      SUM(order_count) AS total_orders,
      SUM(support_ticket_count) AS total_support_tickets,
      AVG(average_satisfaction_score) AS average_satisfaction_score
    FROM gold_customer_360_temp
    """
)

# Persist Gold tables as Delta
gold_sales_summary.write.mode("overwrite").format("delta").saveAsTable("gold.sales_summary")
gold_customer_360.write.mode("overwrite").format("delta").saveAsTable("gold.customer_360")
gold_executive_kpis.write.mode("overwrite").format("delta").saveAsTable("gold.executive_kpis")

# Simple row count sanity check
display(
    spark.sql(
        """
        SELECT 'gold.sales_summary' AS table_name, COUNT(*) AS row_count FROM gold.sales_summary
        UNION ALL SELECT 'gold.customer_360', COUNT(*) FROM gold.customer_360
        UNION ALL SELECT 'gold.executive_kpis', COUNT(*) FROM gold.executive_kpis
        """
    )
)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
