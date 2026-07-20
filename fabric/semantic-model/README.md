# Semantic model — `sm_customer360_gold` (deployable PBIP / TMDL)

A **Direct Lake** semantic model over `LH_Gold`, authored as text (TMDL) so it is
Git-deployable. Tables: `sales_summary`, `customer_360`, `executive_kpis`; all
measures from `measures.dax`; and the `US Only` RLS role.

## One-time bind (required)

The model ships with a **placeholder connection** so it can live in Git without
environment-specific IDs. Point it at your Lakehouse once:

1. Open `sm_customer360_gold.SemanticModel` in **Power BI Desktop** (via the
   `.pbip`/PBIR, or import through **Fabric › Git integration**).
2. Edit the `DirectLake - LH_Gold` expression in
   `definition/expressions.tmdl` (or use Transform data › Data source settings):
   - Replace `REPLACE_WITH_LH_GOLD_SQL_ENDPOINT...` with your **LH_Gold SQL
     analytics endpoint** (Lakehouse › Settings › SQL analytics endpoint › copy
     the connection string / server).
   - Replace `REPLACE_WITH_LH_GOLD_DATABASE` with the Lakehouse name or the SQL DB id.
3. Refresh / save. In Fabric, the Direct Lake model then reads Gold Delta tables
   with no import.

> Deploying via **Fabric Git integration** into a workspace that already contains
> `LH_Gold` is the smoothest path: Fabric rebinds the Direct Lake source to the
> workspace Lakehouse automatically.

## Files

| File | Purpose |
|---|---|
| `.platform` | Fabric item metadata (type `SemanticModel`). |
| `definition.pbism` | Model pointer. |
| `definition/model.tmdl` | Model root; references tables, expression, role. |
| `definition/database.tmdl` | Compatibility level. |
| `definition/expressions.tmdl` | **Direct Lake connection (edit the placeholders).** |
| `definition/tables/*.tmdl` | Table/column/measure definitions. |
| `definition/roles/US Only.tmdl` | RLS role (`country = "United States"`). |

## Endorsement & governance

After deploy, **Certify** this model and apply a sensitivity label — see
`fabric/governance/checklist.md`. RLS options: this role, or the SQL-endpoint
RLS/CLS in `fabric/governance/rls-cls.sql`. Dynamic RLS pattern: `rls-roles.md`.
