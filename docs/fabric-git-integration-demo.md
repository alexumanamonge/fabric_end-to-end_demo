# Fabric Git integration demo

Fabric Git integration syncs supported Fabric item definitions. It does **not** sync Lakehouse Files or Delta table data.

## Recommended approach for tomorrow's demo

Use **Fabric-first Git integration**:

1. Connect the Fabric workspace to this repo.
2. Create the Lakehouse and notebooks in Fabric.
3. Commit those Fabric-created items back to Git from the Fabric Source control pane.
4. Make a small notebook change in GitHub.
5. Pull the change back into Fabric.

This avoids hand-authored system files and lets Fabric generate valid item metadata.

## Recommended repo folder for Fabric connection

Connect the Fabric workspace to this repository folder:

```text
/
```

Do **not** connect to the old `workspace-items` folder. That folder was removed because Fabric rejected the hand-authored system files.

## What should sync

Fabric should create valid item folders in Git after you commit from the Fabric Source control pane.

| Item | Expected behavior |
|---|---|
| Lakehouse created in Fabric | Commits Lakehouse metadata only |
| Notebooks created/imported in Fabric | Commits `*.Notebook` folders with Fabric-generated system files |
| Lakehouse files/tables | Not synced by Git; generated when notebooks run |

## Demo flow

1. In Fabric workspace settings, connect to GitHub repo `alexumanamonge/fabric_end-to-end_demo`.
2. Select branch `main`.
3. Select repository root `/`.
4. Create Lakehouse `lh_customer360` in Fabric.
5. Create/import the four notebooks from `fabric\notebooks`.
6. Attach notebooks to `lh_customer360`.
7. In Source control, commit the Fabric-created Lakehouse and notebooks to Git.
8. Make a small change in GitHub, such as editing a markdown cell or adding a comment to one notebook.
9. Return to Fabric Source control and pull the incoming change.
10. Run `03_run_end_to_end`.
11. Show that Git governed the code assets, while notebook execution created the actual OneLake raw files and tables.

## Key customer talking point

Git integration governs the code and metadata lifecycle. Data lifecycle is handled by Fabric runtime operations such as notebooks, pipelines, shortcuts, copy jobs, mirroring, and OneLake security.

This distinction is important: Git should promote the repeatable build logic; Fabric jobs should produce or refresh the data.

## If Git sync errors

Check these items:

1. The workspace Git connection is pointed at `/`, not `workspace-items`.
2. The branch is `main`.
3. Remove any incoming handcrafted `*.Notebook` or `*.Lakehouse` folders.
4. Let Fabric create item system files by committing from Fabric to Git.
5. The user has Workspace Admin or Member permissions.
6. The tenant supports Notebook and Lakehouse Git integration.
