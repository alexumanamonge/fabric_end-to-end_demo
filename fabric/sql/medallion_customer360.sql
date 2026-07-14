-- Run in a Fabric Spark SQL notebook attached to lakehouse lh_customer360.
-- Upload generated CSV files to Files/bronze before running.

CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

CREATE OR REPLACE TEMPORARY VIEW v_regions
USING csv
OPTIONS (path "Files/bronze/regions_shortcut.csv", header "true", inferSchema "true");

CREATE OR REPLACE TEMPORARY VIEW v_customers
USING csv
OPTIONS (path "Files/bronze/customers_mirrored.csv", header "true", inferSchema "true");

CREATE OR REPLACE TEMPORARY VIEW v_products
USING csv
OPTIONS (path "Files/bronze/products_mirrored.csv", header "true", inferSchema "true");

CREATE OR REPLACE TEMPORARY VIEW v_orders
USING csv
OPTIONS (path "Files/bronze/orders_copy_job.csv", header "true", inferSchema "true");

CREATE OR REPLACE TEMPORARY VIEW v_support_tickets
USING csv
OPTIONS (path "Files/bronze/support_tickets_copy_job.csv", header "true", inferSchema "true");

CREATE OR REPLACE TABLE bronze.regions AS SELECT * FROM v_regions;
CREATE OR REPLACE TABLE bronze.customers AS SELECT * FROM v_customers;
CREATE OR REPLACE TABLE bronze.products AS SELECT * FROM v_products;
CREATE OR REPLACE TABLE bronze.orders AS SELECT * FROM v_orders;
CREATE OR REPLACE TABLE bronze.support_tickets AS SELECT * FROM v_support_tickets;

CREATE OR REPLACE TABLE silver.customers AS
SELECT DISTINCT
    customer_id,
    initcap(customer_name) AS customer_name,
    segment,
    industry,
    region_id,
    country,
    account_owner,
    to_date(created_date) AS created_date,
    sensitivity_tier
FROM bronze.customers
WHERE customer_id IS NOT NULL;

CREATE OR REPLACE TABLE silver.orders AS
SELECT
    order_id,
    customer_id,
    product_id,
    to_date(order_date) AS order_date,
    cast(quantity AS int) AS quantity,
    cast(discount_pct AS double) AS discount_pct,
    cast(sales_amount AS double) AS sales_amount,
    channel,
    source_system
FROM bronze.orders
WHERE order_id IS NOT NULL
  AND sales_amount > 0;

CREATE OR REPLACE TABLE silver.customer_orders AS
SELECT
    o.order_id,
    o.order_date,
    o.customer_id,
    c.customer_name,
    c.segment,
    c.industry,
    c.country,
    c.account_owner,
    c.sensitivity_tier,
    r.geo,
    r.sales_region,
    o.product_id,
    p.product_name,
    p.category,
    o.quantity,
    o.discount_pct,
    o.sales_amount,
    o.channel,
    o.source_system
FROM silver.orders o
JOIN silver.customers c ON o.customer_id = c.customer_id
LEFT JOIN bronze.regions r ON c.region_id = r.region_id
LEFT JOIN bronze.products p ON o.product_id = p.product_id;

CREATE OR REPLACE TABLE silver.support_tickets AS
SELECT
    ticket_id,
    customer_id,
    to_date(opened_date) AS opened_date,
    CASE WHEN closed_date = '' THEN NULL ELSE to_date(closed_date) END AS closed_date,
    priority,
    category,
    CASE WHEN satisfaction_score = '' THEN NULL ELSE cast(satisfaction_score AS int) END AS satisfaction_score
FROM bronze.support_tickets;

CREATE OR REPLACE TABLE gold.sales_summary AS
SELECT
    geo,
    sales_region,
    country,
    segment,
    industry,
    category,
    year(order_date) AS sales_year,
    month(order_date) AS sales_month,
    sum(sales_amount) AS total_sales,
    count(DISTINCT customer_id) AS active_customers,
    count(DISTINCT order_id) AS order_count,
    avg(discount_pct) AS average_discount_pct
FROM silver.customer_orders
GROUP BY geo, sales_region, country, segment, industry, category, year(order_date), month(order_date);

CREATE OR REPLACE TABLE gold.customer_360 AS
SELECT
    c.customer_id,
    c.customer_name,
    c.segment,
    c.industry,
    c.country,
    c.account_owner,
    c.sensitivity_tier,
    count(DISTINCT o.order_id) AS order_count,
    sum(o.sales_amount) AS lifetime_sales,
    max(o.order_date) AS last_order_date,
    count(DISTINCT t.ticket_id) AS support_ticket_count,
    avg(t.satisfaction_score) AS average_satisfaction_score
FROM silver.customers c
LEFT JOIN silver.orders o ON c.customer_id = o.customer_id
LEFT JOIN silver.support_tickets t ON c.customer_id = t.customer_id
GROUP BY c.customer_id, c.customer_name, c.segment, c.industry, c.country, c.account_owner, c.sensitivity_tier;

