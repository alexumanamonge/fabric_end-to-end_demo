# Report — `Customer 360 Executive Overview` (deployable PBIR)

A 3-page Power BI report authored in the **PBIR** (`definition/` folder) format so
it is Git-deployable and diff-friendly. It binds to the `sm_customer360_gold`
semantic model in this repo via a relative path.

## Pages & visuals

**Executive Overview** — cards (Total Sales, Active Customers, Order Count,
Average Satisfaction), column chart (Total Sales by `sales_region`), line chart
(Total Sales by year/month), donut (Total Sales by `segment`).

**Customer 360** — customer table (name, segment, industry, country, Lifetime
Sales, Support Tickets, Avg Satisfaction), bar charts (Lifetime Sales by
`industry` and by `account_owner`), slicers (`country`, `segment`).

**Support & Governance** — cards (Support Tickets, Avg Satisfaction, Critical
Tickets), tickets-by-industry bar, support detail table (with `sensitivity_tier`).

## Binding

`definition.pbir` references the model **by relative path**:

```json
"datasetReference": { "byPath": { "path": "../sm_customer360_gold.SemanticModel" }, "byConnection": null }
```

Keep the `.Report` and `.SemanticModel` folders **as siblings** (they are, at the
repo root). When deploying to Fabric via **Git integration**, both items land in
the same workspace and stay bound.

## One-time open in Power BI Desktop (optional)

This report is written directly as text files (the **PBIR** format) so it works
with Git. It has never been opened in the **Power BI Desktop** app.

It will deploy and run as-is. If you want Desktop to "bless" the files — tidy the
formatting and stamp its own internal IDs so future edits in Desktop round-trip
cleanly — do this once:

1. Open the paired **`.pbip`** file (the Power BI *project* file that pairs the
   `.Report` and `.SemanticModel` folders) in **Power BI Desktop**.
2. Save. That's it — Desktop rewrites the files in its normalized form.

This step is **optional** and only needed if you plan to edit the report in
Desktop; the Git-deployed version works without it.

> Schemas used: report `3.1.0`, page `2.0.0`, visualContainer `2.4.0`,
> pagesMetadata `1.0.0`, platform `2.0.0`. All field bindings reference table and
> measure names exactly as defined in the semantic model.

## Governance

Certify the report and apply a sensitivity label after publishing (see
`fabric/governance/checklist.md`). Use **View as › US Only** on the model to demo
RLS flowing through to this report.
