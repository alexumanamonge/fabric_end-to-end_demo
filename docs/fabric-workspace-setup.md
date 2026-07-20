# Fabric workspace & capacity setup (Microsoft best practices)

This is the **manual** setup you perform in the Fabric portal after the Azure
sources are deployed (`scripts\Deploy-Azure.ps1`). It follows Microsoft's
recommended patterns for capacity, workspaces, domains, naming, security, and
release management. Steps that require a human decision or click are marked
**MANUAL**.

> The demo ships as a *single governed workspace* with three medallion
> Lakehouses. The multi-workspace / multi-environment guidance below is included
> so the repo doubles as a template your team can grow into.

---

## 1. Capacity

**MANUAL — you create the capacity.**

1. In the Azure portal, create a **Microsoft Fabric capacity (F SKU)** in the
   **same region** as the OneLake data and, ideally, the Azure sources deployed
   by this repo. Region alignment reduces cross-region egress and latency.
2. Recommended demo size: **F2–F8** is enough for this dataset. Start small; you
   can scale the SKU without recreating the workspace.
3. **Cost control:** F SKUs bill per hour while running. **Pause** the capacity
   in the Azure portal when not demoing — OneLake data persists while paused;
   only compute stops.
4. Assign at least two **Capacity admins**.

Best practice references:
- Keep capacity, workspace, and source data in one region.
- Use separate capacities for prod vs. dev/test if you later split environments.

---

## 2. Domains (OneLake catalog & governance)

**MANUAL — Fabric admin portal › Domains.**

1. Create a domain, e.g. **`Contoso Analytics`**.
2. (Optional) add a subdomain **`Customer 360`**.
3. Assign the demo workspace to this (sub)domain.

Why: domains organize data by business area in the **OneLake catalog**, enable
delegated governance, and let you scope sensitivity/endorsement policies. They are
the backbone of the "find & trust data" governance story.

---

## 3. Workspace structure & naming

**MANUAL — create the workspace.**

Create a workspace named **`Fabric End-to-End Demo`** (or, using the naming
convention below, `WS-Contoso-Customer360-Prod`) and assign it to the capacity
and domain.

### Naming conventions used in this repo

| Item type | Convention | Example |
|---|---|---|
| Workspace | `WS-<BusinessArea>-<Solution>-<Env>` | `WS-Contoso-Customer360-Prod` |
| Lakehouse | `LH_<Layer>` | `LH_Bronze`, `LH_Silver`, `LH_Gold` |
| Notebook | `NN_<from>_to_<to>` | `01_raw_to_silver` |
| Mirrored DB | `mirror_<source>` | `mirror_sqldb_ops` |
| Copy Job / Pipeline | `copy_<what>_to_<target>` | `copy_etl_to_bronze` |
| Semantic model | `sm_<subject>_<layer>` | `sm_customer360_gold` |
| Report | Business-friendly name | `Customer 360 Executive Overview` |
| Data Agent | Business-friendly name | `Customer Insights Agent` |

### Medallion layout — one workspace, three Lakehouses (recommended for the demo)

```
WS-Contoso-Customer360-Prod
├── LH_Bronze   (raw: exact copies from the 3 ingestion patterns, no transforms)
├── LH_Silver   (clean + conform + combine across sources)
├── LH_Gold     (business-ready: aggregates, Customer 360, KPIs)
├── mirror_sqldb_ops        (Mirrored Azure SQL DB -> customers, products)
├── copy_etl_to_bronze      (Copy Job: sqldb-etl -> orders, support_tickets)
├── 00..03 Notebooks        (medallion transformations + orchestration)
├── sm_customer360_gold     (Direct Lake semantic model over LH_Gold)
├── Customer 360 Executive Overview  (report)
└── Customer Insights Agent (Data Agent)
```

**Why three Lakehouses in one workspace (not one Lakehouse, not three
workspaces):**
- Clear medallion boundaries → clean lineage and easy-to-explain governance.
- Layer-level access control (e.g., analysts get `LH_Gold` only).
- Single workspace keeps the demo simple; split into layer-per-workspace only
  when teams and release cadences diverge.

### Scaling to multiple environments (template guidance)

For a production solution, create one workspace **per environment** and promote
with **Deployment Pipelines**:

```
WS-Contoso-Customer360-Dev  →  -Test  →  -Prod
```

Pair this with **Git integration** (Section 6) so Dev is Git-connected and
Test/Prod are populated by the deployment pipeline.

---

## 4. Security & least privilege

**MANUAL — Workspace › Manage access.**

Assign the *minimum* role each persona needs:

| Persona | Workspace role | Rationale |
|---|---|---|
| Platform owner | Admin | Manage settings, Git, pipelines |
| Data engineer | Member / Contributor | Build Lakehouses, notebooks, pipelines |
| Analyst (BI author) | Viewer + item Build on `sm_customer360_gold` | Author reports without workspace edit rights |
| Business consumer | No workspace role | Consume via the published **app** only |

Item-level detail (Lakehouse ReadData, SQL endpoint, semantic model Build, RLS)
is covered in [`../fabric/governance/checklist.md`](../fabric/governance/checklist.md).

---

## 5. Sensitivity labels & endorsement

**MANUAL — item settings.**

- Apply a **sensitivity label** (e.g., *Confidential*) to `LH_Silver`, `LH_Gold`,
  and `sm_customer360_gold`. Labels flow downstream to reports and exports.
- **Endorse** the Gold semantic model as **Certified** (or Promoted). Certified
  items surface first in the OneLake catalog and signal trust.

---

## 6. Git integration & deployment pipelines

**MANUAL — Workspace settings › Git integration.**

1. Connect the workspace to this GitHub repo, branch `main`, folder `/`.
2. Let **Fabric generate** the item system files; commit Fabric-created items back
   from the Source control pane. See
   [`fabric-git-integration-demo.md`](fabric-git-integration-demo.md).
3. For multi-environment promotion, add a **Deployment Pipeline**
   (Dev → Test → Prod) and use deployment rules to swap data source bindings per
   stage.

Key principle: **Git governs code/metadata; Fabric runtime (mirroring, shortcuts,
copy jobs, notebooks) produces the data.** Git does not sync Lakehouse files or
Delta tables.

---

## Setup checklist

- [ ] Fabric capacity created, in-region, admins assigned
- [ ] Domain `Contoso Analytics` created; workspace assigned
- [ ] Workspace created, assigned to capacity + domain
- [ ] `LH_Bronze`, `LH_Silver`, `LH_Gold` created
- [ ] Roles assigned per least privilege
- [ ] Git integration connected to `/` on `main`
- [ ] Ingestion wired: Mirroring, Shortcut, Copy Job (see `ingestion-*.md`)
- [ ] Notebooks run; medallion tables present
- [ ] Sensitivity labels applied; Gold model endorsed
