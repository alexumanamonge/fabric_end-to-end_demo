# Semantic model design

Create semantic model `sm_customer360_gold` from Lakehouse `LH_Gold`.

## Tables

| Table | Use |
|---|---|
| `LH_Gold.sales_summary` | Monthly sales aggregations by geography, segment, industry, and product category |
| `LH_Gold.customer_360` | Customer-level metrics, support metrics, and security demo columns |
| `LH_Gold.executive_kpis` | Single-row executive KPI snapshot |

## Relationships

This demo can be delivered with a simple flat model:

- Use `sales_summary` for trend and regional aggregate visuals.
- Use `customer_360` for customer detail, support, and optional RLS.
- No relationship is required for the core demo because the Gold tables are already business-shaped.

If you want a richer model, add a shared date table and relate it to `sales_summary[sales_year]` and `sales_summary[sales_month]`.

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

Create role `Country - United States` on `customer_360`:

```DAX
[country] = "United States"
```

Use this to demonstrate that the governed semantic model controls downstream Power BI and Data Agent access.
