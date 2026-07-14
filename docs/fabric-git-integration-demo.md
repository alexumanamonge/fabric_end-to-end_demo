# Fabric Git integration demo

Fabric Git integration syncs supported Fabric item definitions. It does **not** sync Lakehouse Files or Delta table data.

## Recommended repo folder for Fabric connection

When connecting the workspace to Git, point Fabric to this repository folder:

```text
workspace-items
```

That folder contains Fabric-style item folders:

```text
lh_customer360.Lakehouse
00_generate_raw_data.Notebook
01_raw_to_silver.Notebook
02_silver_to_gold.Notebook
03_run_end_to_end.Notebook
```

## What should sync

| Item | Expected behavior |
|---|---|
| `lh_customer360.Lakehouse` | Creates/syncs Lakehouse metadata only |
| `*.Notebook` folders | Creates/syncs notebooks from `notebook-content.py` |
| Lakehouse files/tables | Not synced by Git; generated when notebooks run |

## Demo flow

1. In Fabric workspace settings, connect to GitHub repo `alexumanamonge/fabric_end-to-end_demo`.
2. Select branch `main`.
3. Select folder `workspace-items`.
4. Open the workspace **Source control** pane.
5. Pull/update incoming changes from Git.
6. Confirm the Lakehouse and notebooks appear as Fabric items.
7. Attach notebooks to `lh_customer360` if Fabric does not auto-bind the Lakehouse.
8. Run `03_run_end_to_end`.
9. Show that Git created the code assets, while notebook execution created the actual OneLake raw files and tables.

## Key customer talking point

Git integration governs the code and metadata lifecycle. Data lifecycle is handled by Fabric runtime operations such as notebooks, pipelines, shortcuts, copy jobs, mirroring, and OneLake security.

This distinction is important: Git should promote the repeatable build logic; Fabric jobs should produce or refresh the data.

## If notebooks do not appear

Check these items:

1. The workspace Git connection is pointed at `workspace-items`, not the repo root.
2. The branch is `main`.
3. The tenant supports Notebook Git integration.
4. The Source control pane shows incoming changes and no unsupported-item warning.
5. The notebook item folders contain `.platform` and `notebook-content.py`.
6. The user has Workspace Admin or Member permissions.

