# Demo runbook

A suggested order for delivering the demo live. Full setup detail is in
`README.md` and the linked guides.

## 0. Pre-demo (once)

1. `scripts\Deploy-Azure.ps1` — deploy both RGs (workload + spoke networking) and
   upload the Shortcut reference blob. The SQL databases start empty.
2. Create the Fabric capacity, domain, and an **empty** workspace
   (`docs\fabric-workspace-setup.md`).
3. **Connect the workspace to this repo via Git integration and run Update all**
   (`docs\fabric-git-integration-demo.md`). This creates the three Lakehouses, the
   notebooks, the semantic model, and the report — do **not** build them by hand.
4. Create the **managed VNet data gateway** in Fabric on the delegated subnet, then
   **seed the SQL databases from Fabric** through it (`docs\networking-gateway.md`).
5. Wire ingestion: Mirroring, Shortcut, Copy Job (`docs\ingestion-*.md`) — SQL
   connections select the managed VNet data gateway.
6. Run `03_run_end_to_end`; bind the semantic model (`fabric\semantic-model\README.md`),
   then build the Data Agent and Fabric IQ ontology.
7. Apply governance (`fabric\governance\checklist.md`).

## 1. Admin & structure (5 min)

- Show the capacity, **domain**, and workspace roles (least privilege).
- Show naming conventions and the medallion Lakehouse layout.

## 2. Ingestion — three patterns (8 min)

- **Mirroring:** open `mirror_sqldb_ops`; optionally update a row in `sqldb-ops`
  and watch it replicate.
- **Shortcut:** show `LH_Bronze/Files/shortcuts/regions` — data virtualized, no copy.
- **ETL / Copy Job:** show `copy_etl_to_bronze` run history landing `orders` and
  `support_tickets` into `LH_Bronze/Tables`.

## 3. Medallion transformation (6 min)

- Walk `01_raw_to_silver` (clean + combine) and `02_silver_to_gold`
  (business-ready). Run `03_run_end_to_end` and show the row-count summary.
- Point out Bronze = raw, Silver = conformed, Gold = consumption-ready.

## 4. ⭐ Governance & security (10 min)

- **OneLake catalog:** discover Customer 360 by domain; show descriptions/owners.
- **Lineage:** trace source → Bronze → Silver → Gold → model → report/agent; run
  **impact analysis**.
- **RLS/CLS:** apply `fabric\governance\rls-cls.sql`; query as Analyst vs. Manager
  to show fewer rows, masked names, and the denied `sensitivity_tier` column.
- **Endorsement:** show the **Certified** badge on `sm_customer360_gold`.
- **Sensitivity labels:** show the label on Gold flowing to the report.

## 5. Semantic model & Power BI (6 min)

- `sm_customer360_gold` (Direct Lake) + `Customer 360 Executive Overview` were
  already created by Git integration (step 0.3); just do the one-time bind per
  `fabric\semantic-model\README.md`.
- Report pages: Executive Overview, Customer 360, Support & Governance.
- Optionally apply semantic-model RLS (`fabric\semantic-model\rls-roles.md`) and
  demo **View as › US Only**.

## 6. Data Agent & Fabric IQ ontology (6 min)

- Open `Customer Insights Agent` (build per `fabric\data-agent\build-guide.md`);
  ask the starter questions in `fabric\data-agent\instructions.md`.
- Show the **Fabric IQ ontology** (`fabric\ontology\README.md`): entities
  (Customer, Region, SalesFact, Product, SupportTicket) over Gold.
- Note answers respect the same governed permissions (RLS/CLS) as the report.

## 7. Lifecycle (3 min)

- Show Git integration governing code/metadata; note data is produced by Fabric
  runtime (mirroring, shortcut, copy job, notebooks).
