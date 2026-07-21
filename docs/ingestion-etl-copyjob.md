# Ingestion pattern 3 — ETL / Copy Job (Azure SQL DB → Bronze Lakehouse)

**Source:** Azure SQL Database `sqldb-etl` (tables `dbo.orders`,
`dbo.support_tickets`). This DB **stands in for a SQL Managed Instance** — the
ingestion pattern is identical (see `infra\README.md` › *Variant: real SQL MI*).
**Pattern:** Fabric **Copy Job** (or Data pipeline Copy activity) — managed,
scheduled **batch ETL** that lands source tables into the Bronze Lakehouse.

**Lands as:** Delta tables `LH_Bronze/Tables/orders` and
`LH_Bronze/Tables/support_tickets`.

---

## Prerequisites

- `scripts\Deploy-Azure.ps1` completed (sources deployed + seeded).
- `etlSqlServerFqdn` / `etlDatabaseName` from `infra\deployment-outputs.json`.

## Option A — Copy Job (simplest, recommended)

1. In the workspace: **+ New item › Copy job**.
2. **Source:** Azure SQL Database.
   - Server: `<etlSqlServerFqdn>`, Database: `sqldb-etl`
   - **Data gateway:** select your VNet gateway (installed on the gateway VM) —
     required because SQL is private-endpoint-only.
   - Auth: **Organizational account** (Entra ID) — the servers are Entra-only;
     sign in with the account granted `db_owner`. (SQL/Basic auth is disabled.)
   - Select tables **`dbo.orders`** and **`dbo.support_tickets`**.
3. **Destination:** Lakehouse **`LH_Bronze`** → **Tables**.
   - Map `orders → orders`, `support_tickets → support_tickets`.
4. **Copy mode:** Full load for the demo (Incremental/CDC available as an advanced
   talking point).
5. Name it **`copy_etl_to_bronze`**, save, and **Run**.

## Option B — Data pipeline Copy activity

1. **+ New item › Data pipeline** named `pl_etl_to_bronze`.
2. Add a **Copy data** activity per table (or a ForEach over a table list).
3. Source = `sqldb-etl`; Sink = `LH_Bronze` Tables; run/schedule as needed.

## Verify

- `LH_Bronze/Tables` contains `orders` (1200 rows) and `support_tickets` (400 rows).

## How the notebook uses it

`01_raw_to_silver` reads `orders` and `support_tickets` from `LH_Bronze/Tables`
first, falling back to Bronze raw / fallback CSV if the Copy Job hasn't run yet.

## Governance talking points

- Copy Job is **managed, monitored ETL** — run history, lineage, and alerting
  without maintaining Spark/ADF infrastructure.
- Clear separation: batch **transactional** data (orders/tickets) via ETL, while
  **operational** data (customers/products) streams via Mirroring.
- Lineage: `sqldb-etl → copy_etl_to_bronze → LH_Bronze → LH_Silver → LH_Gold`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Connection fails | Confirm firewall + credentials; server FQDN from outputs. |
| 0 rows copied | Ensure `etl_seed.sql` ran (Seed-Data.ps1). |
| Type mismatches | Bronze accepts source types as-is; typing/cleansing happens in Silver. |
