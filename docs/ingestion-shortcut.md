# Ingestion pattern 2 — Shortcut (ADLS Gen2 Blob → OneLake)

**Source:** Storage account (ADLS Gen2) container `reference`, file
`regions/regions.csv`.
**Pattern:** OneLake **Shortcut** — virtualizes external storage into OneLake with
**no data copy**. The file stays in Blob; Fabric reads it in place.

**Lands as:** `LH_Bronze/Files/shortcuts/regions/regions.csv`.

---

## Prerequisites

- `scripts\Deploy-Azure.ps1` completed (regions.csv uploaded to the container).
- `storageDfsEndpoint` and `storageAccountName` from `infra\deployment-outputs.json`.

## Steps (MANUAL — Fabric portal)

1. Open **`LH_Bronze`** → **Files** → right-click → **New shortcut**.
2. Choose **Azure Data Lake Storage Gen2**.
3. **Connection settings:**
   - URL: `<storageDfsEndpoint>` (e.g. `https://stfabdemoxxxxxx.dfs.core.windows.net/`)
   - Authentication:
     - **Organizational account** (Entra ID) — requires **Storage Blob Data
       Reader** on the account for your user (recommended), **or**
     - **Account key / SAS** — quickest for a demo.
4. Browse to container **`reference`** → folder **`regions`**.
5. Name the shortcut **`regions`**. It appears under
   `LH_Bronze/Files/shortcuts/regions`.

## Verify

- In `LH_Bronze/Files/shortcuts/regions` you see `regions.csv` (5 rows).
- Preview the file to confirm columns: `region_id, geo, sales_region, country`.

## How the notebook uses it

`01_raw_to_silver` reads regions from the shortcut path first and falls back to the
Bronze Delta table / fallback CSV if the shortcut is not present, so the notebook
runs whether or not you've wired the shortcut yet.

## Governance talking points

- **No copy, no duplication** — a single source of truth virtualized into OneLake.
- Access is still governed: the shortcut respects OneLake permissions, and the
  underlying storage RBAC still applies.
- Lineage shows the external ADLS source feeding Bronze.

## Troubleshooting

| Symptom | Fix |
|---|---|
| "Access denied" creating shortcut | Grant your user **Storage Blob Data Reader**, or use account key/SAS. |
| File not found | Confirm `Seed-Data.ps1` uploaded `regions/regions.csv` (upload-batch step). |
| Wrong endpoint | Use the **dfs** endpoint, not blob, for ADLS Gen2 shortcuts. |
