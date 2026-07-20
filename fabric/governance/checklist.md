# Governance & security checklist

This checklist walks the Fabric governance story end-to-end. Each item is a
demo-able capability; the ⭐ items are the headline features requested for this demo:
**OneLake catalog, lineage, RLS & CLS, and content endorsement**.

## 1. Administration & least privilege

- [ ] Workspace assigned to capacity and to a **domain** (`Contoso Analytics`).
- [ ] At least two **workspace admins**.
- [ ] Roles assigned per least privilege (see `docs/fabric-workspace-setup.md` §4):

| Surface | Demo permission point |
|---|---|
| Workspace | Admin / Member / Contributor / Viewer |
| Lakehouse | ReadData / ReadAll for governed users |
| SQL analytics endpoint | SQL access for analysts (subject to RLS/CLS) |
| Semantic model | Build permission + RLS |
| Report | Consume via published **app** |
| Data Agent | Access flows through governed data items |

## 2. ⭐ OneLake catalog

- [ ] Open the **OneLake catalog** and find the Customer 360 data by domain.
- [ ] Show item descriptions, owners, endorsement badges, and sensitivity labels.
- [ ] Talking point: one governed catalog to **discover and trust** data across
      the tenant — no copies, single source in OneLake.

## 3. ⭐ Lineage & impact analysis

- [ ] Open the workspace **lineage view**.
- [ ] Trace the full chain:
      `sqldb-ops → mirror_sqldb_ops → LH_Bronze → LH_Silver → LH_Gold → sm_customer360_gold → report / Data Agent`
      plus `ADLS shortcut → LH_Bronze` and `sqldb-etl → copy_etl_to_bronze → LH_Bronze`.
- [ ] Run **impact analysis** on a Gold table before a change to show downstream
      dependents.

## 4. ⭐ Row-Level & Column-Level Security

- [ ] Apply `fabric/governance/rls-cls.sql` on the **LH_Gold SQL analytics endpoint**:
  - CLS: `Analysts` cannot read `customer_360.sensitivity_tier`.
  - DDM: `customer_name` masked unless the user has `UNMASK` (SalesManagers).
  - RLS: non-managers see **United States** rows only; managers see all.
- [ ] (Optional) Add semantic-model RLS from `fabric/semantic-model/rls-roles.md`
      and show the same report returning different rows per persona.
- [ ] Talking point: define security **once** on the governed layer → enforced for
      SQL, Power BI, Excel, and the Data Agent alike.

## 5. ⭐ Content endorsement

- [ ] **Certify** (or Promote) `sm_customer360_gold`.
- [ ] Show the badge in the catalog and in report/dataset lists.
- [ ] Talking point: endorsement signals trusted, owned assets and surfaces them
      first in discovery.

## 6. Sensitivity labels & protection

- [ ] Apply a **sensitivity label** (e.g. *Confidential*) to `LH_Silver`,
      `LH_Gold`, and `sm_customer360_gold`.
- [ ] Show the label flowing to the report and to exports (Excel/PDF).

## 7. Lifecycle governance (Git & deployment pipelines)

- [ ] Workspace connected to Git (`/`, `main`) — see `docs/fabric-git-integration-demo.md`.
- [ ] (Template) Deployment pipeline Dev → Test → Prod with data-source rules.
- [ ] Talking point: **Git governs code/metadata; Fabric runtime produces data.**

## Reset / re-run

- Disable RLS: `ALTER SECURITY POLICY Security.CustomerRowFilter WITH (STATE = OFF);`
- Re-run the medallion: notebook `03_run_end_to_end`.
- Full teardown of Azure sources: `scripts/Teardown-Azure.ps1`.
