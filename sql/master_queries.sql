-- 1. Data Cleaning: Create clean view
DROP VIEW IF EXISTS clean_retail;

CREATE VIEW clean_retail AS
SELECT 
    invoice_no,
    stock_code,
    description,
    quantity,
    invoice_date,
    unit_price,
    ROUND((quantity * unit_price), 2) AS total_revenue,
    customer_id,
    country
FROM raw_retail
WHERE invoice_no NOT LIKE 'C%'
  AND quantity > 0
  AND unit_price > 0;

-- 2. Geographic breakdown: Top 5 non-UK markets
SELECT 
    country,
    COUNT(DISTINCT invoice_no) AS total_orders,
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(SUM(total_revenue) / COUNT(DISTINCT invoice_no), 2) AS avg_order_value,
    ROUND(100.0 * SUM(total_revenue) / SUM(SUM(total_revenue)) OVER (), 2) AS intl_revenue_share_pct
FROM clean_retail
WHERE country != 'United Kingdom'
GROUP BY country
ORDER BY total_revenue DESC
LIMIT 5;

-- 3. Monthly revenue & MoM growth %
WITH monthly_sales AS (
    SELECT 
        TO_CHAR(invoice_date, 'YYYY-MM') AS sales_month,
        COUNT(DISTINCT invoice_no) AS total_orders,
        ROUND(SUM(total_revenue), 2) AS monthly_revenue
    FROM clean_retail
    GROUP BY TO_CHAR(invoice_date, 'YYYY-MM')
)
SELECT 
    sales_month,
    total_orders,
    monthly_revenue,
    ROUND(
        100.0 * (monthly_revenue - LAG(monthly_revenue, 1) OVER (ORDER BY sales_month)) 
        / LAG(monthly_revenue, 1) OVER (ORDER BY sales_month), 
        2
    ) AS mom_growth_pct
FROM monthly_sales
ORDER BY sales_month;

-- Peak ordering hours
SELECT 
    EXTRACT(HOUR FROM invoice_date)::INTEGER AS order_hour,
    COUNT(DISTINCT invoice_no) AS total_orders,
    ROUND(100.0 * COUNT(DISTINCT invoice_no) / SUM(COUNT(DISTINCT invoice_no)) OVER (), 2) AS pct_of_daily_orders
FROM clean_retail
GROUP BY EXTRACT(HOUR FROM invoice_date)::INTEGER
ORDER BY total_orders DESC;

-- 4. Customer RFM: Top 10 spenders
WITH customer_orders AS (
    SELECT 
        customer_id,
        invoice_no,
        invoice_date::date AS order_date,
        total_revenue
    FROM clean_retail
    WHERE customer_id IS NOT NULL
),
rfm_raw AS (
    SELECT 
        customer_id,
        (SELECT MAX(order_date) FROM customer_orders) - MAX(order_date) AS recency_days,
        COUNT(DISTINCT invoice_no) AS frequency,
        ROUND(SUM(total_revenue), 2) AS monetary_total
    FROM customer_orders
    GROUP BY customer_id
)
SELECT 
    DENSE_RANK() OVER (ORDER BY monetary_total DESC) AS spend_rank,
    customer_id,
    recency_days,
    frequency,
    monetary_total,
    ROUND(monetary_total / frequency, 2) AS avg_order_value
FROM rfm_raw
ORDER BY spend_rank
LIMIT 10;

-- 5. Product cancellation rates from raw data
WITH product_orders AS (
    SELECT 
        stock_code,
        MAX(CASE WHEN description IS NOT NULL AND description != '' THEN description END) AS product_name,
        COUNT(DISTINCT invoice_no) AS total_orders,
        COUNT(DISTINCT CASE WHEN invoice_no LIKE 'C%' THEN invoice_no END) AS cancelled_orders
    FROM raw_retail
    GROUP BY stock_code
)
SELECT 
    stock_code,
    COALESCE(product_name, 'No Description') AS product_description,
    total_orders,
    cancelled_orders,
    ROUND(100.0 * cancelled_orders / total_orders, 2) AS cancellation_rate_pct
FROM product_orders
WHERE total_orders >= 20
ORDER BY cancellation_rate_pct DESC
LIMIT 10;
