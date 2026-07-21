# Fabric Git integration — connect the workspace to this repo

Fabric **Git integration** links a workspace to a Git branch and syncs supported
**Fabric item definitions** (Lakehouse metadata, notebooks, semantic models,
reports). This repo already contains those items in the correct format, so a single
**Update all** creates them all in your workspace — you do **not** build them by
hand.

> **What Git does and does not sync.** Git syncs the *code and metadata* of items
> (notebook source, Lakehouse definition, semantic model, report). It does **not**
> sync Lakehouse **Files** or **Delta table data** — those are produced later when
> you run the notebooks, wire shortcuts/mirroring, and seed SQL.

---

## What gets created when you sync

| Repo item | Becomes in your workspace |
|---|---|
| `LH_Bronze.Lakehouse/`, `LH_Silver.Lakehouse/`, `LH_Gold.Lakehouse/` | The three **empty** medallion Lakehouses |
| `*.Notebook/` folders | The medallion notebooks (`00`–`03`) |
| `sm_customer360_gold.SemanticModel/` | The Direct Lake semantic model |
| `Customer 360 Executive Overview.Report/` | The Power BI report |

Because these come straight from the repo, their names and internal references stay
consistent. **Creating any of them manually first causes duplicate items and sync
conflicts** — start from a completely **empty** workspace.

---

## Steps (MANUAL — Fabric portal)

1. Create (or open) an **empty** Fabric workspace on your capacity. Do **not** add
   any Lakehouses, notebooks, or reports yet.
2. Open **Workspace settings › Git integration**.
3. Sign in to **GitHub** and select:
   - **Repository:** `alexumanamonge/fabric_end-to-end_demo`
   - **Branch:** `main`
   - **Folder:** `/` (the repository root — **not** any subfolder)
4. Click **Connect**, then **Update all**. Fabric reads the repo and creates every
   item in the table above.
5. Wait for the sync to finish. The workspace now shows the three Lakehouses, the
   notebooks, the semantic model, and the report.

That's it — continue with the rest of the quick start (gateway + seed, ingestion,
run notebooks, bind the semantic model).

---

## Optional: show the two-way Git workflow (nice demo moment)

To demonstrate that Git governs the *code* lifecycle:

1. In GitHub, make a small change — e.g. edit a markdown cell or add a comment in
   one notebook — and commit to `main`.
2. In Fabric, open **Source control**; the change appears as **incoming**.
3. Click **Update** to pull it into the workspace.
4. Re-run `03_run_end_to_end` to show the updated code executing.

**Talking point:** Git integration promotes the repeatable **build logic** (code and
metadata). The **data lifecycle** is handled by Fabric runtime operations —
notebooks, pipelines, shortcuts, copy jobs, mirroring, and OneLake security. Git
governs the code; Fabric jobs produce and refresh the data.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `FailedToParseContent` on `shortcuts.metadata.json` | You started from a non-empty workspace, or an older clone. Start from an **empty** workspace and sync `main`; the repo ships valid metadata. |
| Duplicate `LH_Bronze` / notebooks after sync | You created items by hand before syncing. Delete the manual copies (or start a fresh empty workspace) and **Update all** again. |
| Report fails to import (`Cannot find file 'version.json'`) | Use the current `main` branch — the report includes the required `definition/version.json`. |
| Nothing syncs / items missing | Confirm the connection points to folder **`/`** (root), branch **`main`**, and that you clicked **Update all**. |
| Permission errors | You need **Workspace Admin** or **Member**, and the tenant must allow Notebook/Lakehouse Git integration. |
