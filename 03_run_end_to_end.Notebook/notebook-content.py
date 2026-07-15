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

# # 03 - Run end-to-end
# 
# Optional orchestration notebook. Import all notebooks into the same Fabric workspace and run this one to build the complete demo pipeline.

# CELL ********************

# Run child notebooks sequentially and stop if any fails

# Helper to run a notebook and surface a clear error if it fails
from notebookutils import notebook as nb

for child_nb in [
    "00_generate_raw_data",
    "01_raw_to_silver",
    "02_silver_to_gold",
]:
    try:
        nb.run(child_nb, 900)
    except Exception as e:
        # Log which child failed and re-raise so the pipeline stops here
        raise RuntimeError(f"Child notebook '{child_nb}' failed. See its last run for details.") from e

# If all child notebooks succeed, show row counts from key tables
query = """
SELECT 'bronze.customers_raw'   AS table_name, count(*) AS row_count FROM bronze.customers_raw
UNION ALL SELECT 'silver.customer_orders', count(*) FROM silver.customer_orders
UNION ALL SELECT 'gold.sales_summary',    count(*) FROM gold.sales_summary
UNION ALL SELECT 'gold.customer_360',     count(*) FROM gold.customer_360
UNION ALL SELECT 'gold.executive_kpis',   count(*) FROM gold.executive_kpis
"""

display(spark.sql(query))


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
