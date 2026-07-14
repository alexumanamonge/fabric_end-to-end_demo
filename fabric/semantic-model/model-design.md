# Semantic model design

Create semantic model `sm_customer360_gold` from the Lakehouse `lh_customer360` Gold tables.

## Tables

| Table | Use |
|---|---|
| `gold.sales_summary` | Monthly sales aggregations by geography, segment, industry, and product category |
| `gold.customer_360` | Customer-level metrics, support metrics, and security demo columns |
| `gold.executive_kpis` | Single-row executive KPI snapshot |

## Relationships

This demo can be delivered with a simple flat model:

- Use `gold.sales_summary` for trend and regional aggregate visuals.
- Use `gold.customer_360` for customer detail, support, and optional RLS.
- No relationship is required for the core demo because the Gold tables are already business-shaped.

If you want a richer model, add a shared date table and relate it to `gold.sales_summary[sales_year]` and `gold.sales_summary[sales_month]`.

## Measures

Use `fabric\semantic-model\measures.dax`.

## Recommended formatting

| Measure | Format |
|---|---|
| `Total Sales` | Currency, 0 decimals |
| `Lifetime Sales` | Currency, 0 decimals |
| `Average Sales per Customer` | Currency, 0 decimals |
| `Average Discount %` | Percentage, 1 decimal |
| `Average Satisfaction` | Decimal number, 1 decimal |

## Optional row-level security

Create role `Country - United States` on `gold.customer_360`:

```DAX
[country] = "United States"
```

Use this to demonstrate that the governed semantic model controls downstream Power BI and Data Agent access.

