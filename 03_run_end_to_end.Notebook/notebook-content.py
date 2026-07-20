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
# Orchestrates the medallion pipeline across `LH_Bronze`, `LH_Silver`, and `LH_Gold`.
#
# - **Primary flow (real ingestion):** leave `RUN_OFFLINE_SEED = False`. Bronze is
#   populated by Mirroring + Shortcut + Copy Job (see `docs/ingestion-*.md`). This
#   notebook then runs Silver and Gold.
# - **Offline dry run:** set `RUN_OFFLINE_SEED = True` to first run
#   `00_generate_raw_data`, seeding Bronze without any Azure sources.

# CELL ********************

from notebookutils import notebook as nb

# Set True only for an offline dry run without deployed Azure sources.
RUN_OFFLINE_SEED = False

child_notebooks = []
if RUN_OFFLINE_SEED:
    child_notebooks.append("00_generate_raw_data")
child_notebooks += ["01_raw_to_silver", "02_silver_to_gold"]

for child_nb in child_notebooks:
    try:
        nb.run(child_nb, 900)
    except Exception as e:
        raise RuntimeError(
            f"Child notebook '{child_nb}' failed. See its last run for details."
        ) from e

# CELL ********************

# Row-count sanity check across the medallion.
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
            ("LH_Bronze.customers", delta_count("LH_Bronze", "customers")),
            ("LH_Bronze.orders", delta_count("LH_Bronze", "orders")),
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
