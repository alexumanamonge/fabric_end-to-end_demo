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
# Optional orchestration notebook. Run this one to build the complete demo pipeline across `LH_Bronze`, `LH_Silver`, and `LH_Gold`.

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
WORKSPACE_NAME = ""


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


def delta_count(lakehouse_name: str, table_name: str) -> int:
    return spark.read.format("delta").load(lakehouse_path(lakehouse_name, f"Tables/{table_name}")).count()


display(
    spark.createDataFrame(
        [
            ("LH_Bronze.customers_raw", delta_count("LH_Bronze", "customers_raw")),
            ("LH_Silver.customer_orders", delta_count("LH_Silver", "customer_orders")),
            ("LH_Gold.sales_summary", delta_count("LH_Gold", "sales_summary")),
            ("LH_Gold.customer_360", delta_count("LH_Gold", "customer_360")),
            ("LH_Gold.executive_kpis", delta_count("LH_Gold", "executive_kpis")),
        ],
        ["table_name", "row_count"],
    )
)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
