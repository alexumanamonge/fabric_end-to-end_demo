# Power BI report specification

Build this report from semantic model `sm_customer360_gold`, connected to the Gold Lakehouse tables.

## Page 1: Executive Overview

| Visual | Fields / measures |
|---|---|
| Card | `Total Sales` |
| Card | `Active Customers` |
| Card | `Order Count` |
| Card | `Average Satisfaction` |
| Clustered column chart | Axis: `sales_region`; Values: `Total Sales` |
| Line chart | Axis: `sales_year`, `sales_month`; Values: `Total Sales` |
| Donut chart | Legend: `segment`; Values: `Total Sales` |

## Page 2: Customer 360

| Visual | Fields / measures |
|---|---|
| Table | `customer_name`, `segment`, `industry`, `country`, `Lifetime Sales`, `Support Tickets`, `Average Satisfaction` |
| Bar chart | Axis: `industry`; Values: `Lifetime Sales` |
| Bar chart | Axis: `account_owner`; Values: `Lifetime Sales` |
| Slicer | `country` |
| Slicer | `segment` |

## Page 3: Support and Governance

| Visual | Fields / measures |
|---|---|
| Card | `Support Tickets` |
| Card | `Average Satisfaction` |
| Bar chart | Axis: `industry`; Values: `Support Tickets` |
| Table | `customer_name`, `support_ticket_count`, `critical_ticket_count`, `sensitivity_tier` |

## Optional security demo

Create a role named `Country - United States` with this filter on `gold customer_360`:

```DAX
[country] = "United States"
```

Then use **View as** to demonstrate that the semantic model governs what the report and Data Agent can access.

