# Fabric IQ ontology — build guide

**Fabric IQ** provides a business **ontology** (semantic layer of entities,
properties, and relationships) over your OneLake data so agents and analysts can
reason over real-world concepts instead of raw tables. Fabric IQ is in preview
and authored in the UI, so this repo ships the ontology as **config-as-code** in
[`ontology.yaml`](./ontology.yaml) — the source of truth to reproduce it.

## What this ontology models

Entities bound to the certified **Gold** Lakehouse (`LH_Gold`, schema `dbo`):

| Entity | Bound table | Role |
|---|---|---|
| **Customer** | `customer_360` | Core account with lifetime sales, tickets, satisfaction. |
| **Region** | `customer_360` (denormalized) | Geo / sales_region / country. |
| **SalesFact** | `sales_summary` | Aggregated sales grain for market analysis. |
| **Product** | `sales_summary` | Product category dimension. |
| **SupportTicket** | `customer_360` | Aggregated support signals per customer. |

Relationships: Customer→Region, Customer→SupportTicket, SalesFact→Region,
SalesFact→Product (see `ontology.yaml › relationships`).

> Order, Product, and SupportTicket are conceptual demo entities that are
> pre-aggregated into Gold. To model them at native grain, expose the **Silver**
> tables to Fabric IQ and rebind those entities to their base tables.

## Prerequisites
- Gold Lakehouse `LH_Gold` populated (run the medallion notebooks).
- Fabric IQ / ontology preview enabled for your tenant + capacity.

## Steps

1. In the workspace, create a new **Fabric IQ ontology** (or **Digital twin
   builder** ontology, depending on your tenant's preview surface).
2. **Add the data source**: connect `LH_Gold` (OneLake).
3. For each entity in `ontology.yaml › entities`:
   - Create the entity, set its **key** and **label** property.
   - Bind it to the listed `table` and map each property to its `source` column.
   - Flag `measure: true` properties as measures/metrics.
4. Create each **relationship** from `ontology.yaml › relationships`, matching the
   `from`, `to`, `cardinality`, and join key(s).
5. **Govern**: mark the ontology **Certified**, apply the **Confidential**
   sensitivity label, and confirm it inherits the Gold/model **RLS** on `country`.
6. **Validate**: from the ontology / a connected agent, ask a concept-level
   question (e.g. "Which regions have the lowest average satisfaction?") and
   confirm it resolves via entities, not raw SQL.

## Keeping it in sync
`ontology.yaml` is the source of truth. Update it first when Gold columns change,
then re-apply the mapping in the Fabric IQ UI.
