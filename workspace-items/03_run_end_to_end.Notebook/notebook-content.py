# Fabric notebook source
# METADATA ********************
# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {}
# META }
# CELL ********************
# MAGIC # 03 - Run end-to-end
# MAGIC
# MAGIC Optional orchestration notebook. Import all notebooks into the same Fabric workspace and run this one to build the complete demo pipeline.
# METADATA ********************
# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
# CELL ********************
notebookutils.notebook.run("00_generate_raw_data", 900)
notebookutils.notebook.run("01_raw_to_silver", 900)
notebookutils.notebook.run("02_silver_to_gold", 900)

display(spark.sql("""
SELECT 'bronze.customers_raw' AS table_name, count(*) AS row_count FROM bronze.customers_raw
UNION ALL SELECT 'silver.customer_orders', count(*) FROM silver.customer_orders
UNION ALL SELECT 'gold.sales_summary', count(*) FROM gold.sales_summary
UNION ALL SELECT 'gold.customer_360', count(*) FROM gold.customer_360
UNION ALL SELECT 'gold.executive_kpis', count(*) FROM gold.executive_kpis
"""))
# METADATA ********************
# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
