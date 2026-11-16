-- Monthly revenue and month-over-month growth using LAG
WITH monthly_sales AS (
    SELECT 
        TO_CHAR(invoice_date, 'YYYY-MM') AS sales_month,
        COUNT(DISTINCT invoice_no) AS total_orders,
        COUNT(*) AS total_items_sold,
        ROUND(SUM(total_revenue), 2) AS monthly_revenue
    FROM clean_retail
    GROUP BY TO_CHAR(invoice_date, 'YYYY-MM')
)
SELECT 
    sales_month,
    total_orders,
    monthly_revenue,
    LAG(monthly_revenue, 1) OVER (ORDER BY sales_month) AS prev_month_revenue,
    ROUND(
        100.0 * (monthly_revenue - LAG(monthly_revenue, 1) OVER (ORDER BY sales_month)) 
        / LAG(monthly_revenue, 1) OVER (ORDER BY sales_month), 
        2
    ) AS mom_growth_pct
FROM monthly_sales
ORDER BY sales_month;

-- Hourly order volume to find peak ordering times during the day
SELECT 
    EXTRACT(HOUR FROM invoice_date)::INTEGER AS order_hour,
    COUNT(DISTINCT invoice_no) AS total_orders,
    ROUND(SUM(total_revenue), 2) AS hourly_revenue,
    ROUND(100.0 * COUNT(DISTINCT invoice_no) / SUM(COUNT(DISTINCT invoice_no)) OVER (), 2) AS pct_of_daily_orders
FROM clean_retail
GROUP BY EXTRACT(HOUR FROM invoice_date)::INTEGER
ORDER BY total_orders DESC;
