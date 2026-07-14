# Semantic model field list

## `gold.sales_summary`

| Column | Type | Recommended use |
|---|---|---|
| `geo` | Text | Slicer / geography grouping |
| `sales_region` | Text | Axis |
| `country` | Text | Slicer / RLS demo |
| `segment` | Text | Legend / slicer |
| `industry` | Text | Axis / slicer |
| `category` | Text | Product category grouping |
| `sales_year` | Whole number | Date hierarchy |
| `sales_month` | Whole number | Date hierarchy |
| `total_sales` | Decimal | Hidden; use `Total Sales` measure |
| `active_customers` | Whole number | Hidden; use `Active Customers` measure |
| `order_count` | Whole number | Hidden; use `Order Count` measure |
| `average_discount_pct` | Decimal | Hidden; use `Average Discount %` measure |

## `gold.customer_360`

| Column | Type | Recommended use |
|---|---|---|
| `customer_id` | Text | Key |
| `customer_name` | Text | Detail table |
| `segment` | Text | Slicer |
| `industry` | Text | Axis / slicer |
| `country` | Text | Slicer / RLS demo |
| `account_owner` | Text | Axis / slicer |
| `sensitivity_tier` | Text | Governance/security talking point |
| `order_count` | Whole number | Hidden; use `Order Count` or detail table |
| `lifetime_sales` | Decimal | Hidden; use `Lifetime Sales` measure |
| `last_order_date` | Date | Detail table |
| `support_ticket_count` | Whole number | Hidden; use `Support Tickets` measure |
| `average_satisfaction_score` | Decimal | Hidden; use `Average Satisfaction` measure |
| `critical_ticket_count` | Whole number | Hidden; use `Critical Tickets` measure |

