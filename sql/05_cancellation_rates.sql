-- Overall cancellation rate across the raw table
SELECT 
    COUNT(DISTINCT invoice_no) AS total_distinct_invoices,
    COUNT(DISTINCT CASE WHEN invoice_no LIKE 'C%' THEN invoice_no END) AS total_cancelled_invoices,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN invoice_no LIKE 'C%' THEN invoice_no END) 
        / COUNT(DISTINCT invoice_no), 
        2
    ) AS overall_cancellation_rate_pct
FROM raw_retail;

-- Products with highest cancellation rates (filtered to min 20 orders to exclude single-order anomalies)
WITH product_cancellations AS (
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
FROM product_cancellations
WHERE total_orders >= 20
ORDER BY cancellation_rate_pct DESC
LIMIT 15;
