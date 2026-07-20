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

# # 02 - Silver to Gold
#
# Reads conformed Silver tables from `LH_Silver` and creates business-ready **Gold**
# tables in `LH_Gold` for the Direct Lake semantic model, Power BI report, and Data
# Agent.
#
# `gold_customer_360` intentionally keeps `account_owner`, `country`, and
# `sensitivity_tier` so the governance demo can apply **row-level** and
# **column-level** security (see `fabric/governance/`).

# CELL ********************

from pyspark.sql import functions as F

WORKSPACE_NAME = ""
SILVER_LAKEHOUSE = "LH_Silver"
GOLD_LAKEHOUSE = "LH_Gold"


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


SILVER_TABLES = lakehouse_path(SILVER_LAKEHOUSE, "Tables")
GOLD_TABLES = lakehouse_path(GOLD_LAKEHOUSE, "Tables")

# --- Read required Silver tables ---
customer_orders = spark.read.format("delta").load(f"{SILVER_TABLES}/customer_orders")
customers = spark.read.format("delta").load(f"{SILVER_TABLES}/customers")
orders = spark.read.format("delta").load(f"{SILVER_TABLES}/orders")
tickets = spark.read.format("delta").load(f"{SILVER_TABLES}/support_tickets")

# --- Gold: monthly sales summary by geography / segment / industry / category ---
gold_sales_summary = (
    customer_orders
    .withColumn("sales_year", F.year("order_date"))
    .withColumn("sales_month", F.month("order_date"))
    .groupBy(
        "geo", "sales_region", "country", "segment", "industry", "category",
        "sales_year", "sales_month",
    )
    .agg(
        F.sum("sales_amount").alias("total_sales"),
        F.countDistinct("customer_id").alias("active_customers"),
        F.countDistinct("order_id").alias("order_count"),
        F.avg("discount_pct").alias("average_discount_pct"),
    )
)

# --- Support ticket summary per customer ---
ticket_summary = (
    tickets
    .groupBy("customer_id")
    .agg(
        F.countDistinct("ticket_id").alias("support_ticket_count"),
        F.avg("satisfaction_score").alias("average_satisfaction_score"),
        F.sum(F.when(F.col("priority") == "Critical", 1).otherwise(0)).alias("critical_ticket_count"),
    )
)

# --- Order summary per customer ---
order_summary = (
    orders
    .groupBy("customer_id")
    .agg(
        F.countDistinct("order_id").alias("order_count"),
        F.sum("sales_amount").alias("lifetime_sales"),
        F.max("order_date").alias("last_order_date"),
    )
)

# --- Customer 360 (keeps security-relevant columns for RLS/CLS) ---
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

# --- Executive KPI snapshot ---
gold_customer_360.createOrReplaceTempView("gold_customer_360_temp")
gold_executive_kpis = spark.sql(
    """
    SELECT
      COUNT(DISTINCT customer_id)   AS total_customers,
      SUM(lifetime_sales)           AS total_sales,
      SUM(order_count)              AS total_orders,
      SUM(support_ticket_count)     AS total_support_tickets,
      AVG(average_satisfaction_score) AS average_satisfaction_score
    FROM gold_customer_360_temp
    """
)

# --- Persist Gold ---
gold_sales_summary.write.mode("overwrite").format("delta").save(f"{GOLD_TABLES}/sales_summary")
gold_customer_360.write.mode("overwrite").format("delta").save(f"{GOLD_TABLES}/customer_360")
gold_executive_kpis.write.mode("overwrite").format("delta").save(f"{GOLD_TABLES}/executive_kpis")

display(
    spark.createDataFrame(
        [
            ("LH_Gold.sales_summary", gold_sales_summary.count()),
            ("LH_Gold.customer_360", gold_customer_360.count()),
            ("LH_Gold.executive_kpis", gold_executive_kpis.count()),
        ],
        ["table_name", "row_count"],
    )
)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
