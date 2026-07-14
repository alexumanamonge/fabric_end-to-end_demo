# Governance and security checklist

## Administration

- Workspace: `Fabric End-to-End Demo`
- Capacity: assigned to Fabric capacity before the demo
- Domain: assign to the appropriate business domain if available
- Owners: add at least two workspace admins

## Permissions

| Surface | Demo permission point |
|---|---|
| Workspace | Admin, Member, Contributor, Viewer roles |
| Lakehouse | ReadData / ReadAll access for governed users |
| SQL analytics endpoint | SQL access for analysts |
| Semantic model | Build permission and RLS where applicable |
| Report | App or direct sharing for consumers |
| Data Agent | Access flows through governed data items |

## Governance

- Apply a sensitivity label to the Lakehouse or semantic model.
- Promote or certify the Gold semantic model.
- Show lineage from ingestion to Lakehouse, semantic model, report, and Data Agent.
- Explain impact analysis before changing upstream tables.

## Optional security demo

Create a role in the semantic model that filters `gold customer_360` by `account_owner` or `country`, then show how the same report returns different rows for different users.

