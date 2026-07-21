# Ingestion pattern 1 — Mirroring (Azure SQL DB → OneLake)

**Source:** Azure SQL Database `sqldb-ops` (tables `dbo.customers`, `dbo.products`)
**Pattern:** Fabric **Mirroring** — near-real-time, low-cost replication of an
operational database into OneLake as Delta tables. No ETL code; Fabric reads the
source change feed and keeps the mirror current.

**Lands as:** a Mirrored database item `mirror_sqldb_ops` whose tables are
automatically available in OneLake and can be read/shortcut from `LH_Bronze`.

---

## Prerequisites

- `scripts\Deploy-Azure.ps1` completed (sources deployed + seeded).
- The `opsSqlServerFqdn` / `opsDatabaseName` from `infra\deployment-outputs.json`.
- Your Entra ID account with `db_owner` on `sqldb-ops` (granted automatically by
  the deployment when you pass `aadAdminObjectId`/`aadAdminLogin`). The servers are
  **Entra ID-only** — there is no SQL login/password.
- The **on-premises data gateway installed on the gateway VM** and online in
  Fabric — the SQL servers are private-endpoint-only, so the connection must go
  through it. See [`networking-gateway.md`](networking-gateway.md).

## Steps (MANUAL — Fabric portal)

1. In the demo workspace choose **+ New item › Mirrored Azure SQL Database**.
2. **New connection:**
   - Server: `<opsSqlServerFqdn>` (e.g. `sql-ops-xxxxxxxx.database.windows.net`)
   - Database: `sqldb-ops`
   - **Data gateway:** select your VNet gateway (the one installed on the gateway
     VM) — required because SQL has no public endpoint.
   - Authentication: **Organizational account** (Entra ID) — sign in with the
     account that was granted `db_owner`. (Basic/SQL auth is disabled.)
3. Select tables to mirror: **`dbo.customers`** and **`dbo.products`**.
4. Name the item **`mirror_sqldb_ops`** and create it.
5. Wait for initial snapshot; status shows **Running / Replicating**.

## Verify

- Open `mirror_sqldb_ops` → the SQL analytics endpoint lists `customers` and
  `products` with row counts (150 customers, 6 products).
- (Optional) In the source DB, `UPDATE dbo.customers ... ;` and watch the change
  flow into the mirror within a minute — a strong live talking point.

## Make it available to Bronze

The medallion notebook `01_raw_to_silver` reads mirrored data. Choose one:

- **Recommended:** in `LH_Bronze`, create a **OneLake shortcut** to the mirrored
  `customers` and `products` tables (New shortcut › Microsoft OneLake ›
  `mirror_sqldb_ops`). This surfaces them under `LH_Bronze/Tables` with zero copy.
- **Or** point the notebook's `MIRROR_ITEM` variable at `mirror_sqldb_ops` and it
  will read the mirrored tables directly (see notebook header).

## Governance talking points

- Mirroring keeps a **live governed copy** in OneLake without hand-written ETL.
- Lineage shows `sqldb-ops → mirror_sqldb_ops → LH_Bronze → LH_Silver → …`.
- Source stays authoritative; Fabric never writes back.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Connection fails | Confirm firewall allows Azure services (Bicep sets this) and your credentials. |
| Tables missing | Ensure `ops_seed.sql` ran (Seed-Data.ps1). |
| Mirror stuck *Initializing* | Some SQL features block mirroring; confirm the DB is a standard Azure SQL DB (this repo's is). |
