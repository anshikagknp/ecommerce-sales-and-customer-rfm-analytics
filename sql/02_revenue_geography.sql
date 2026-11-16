-- Domestic (UK) vs International revenue comparison
SELECT 
    CASE 
        WHEN country = 'United Kingdom' THEN 'United Kingdom' 
        ELSE 'International (Non-UK)' 
    END AS market_segment,
    COUNT(DISTINCT invoice_no) AS total_orders,
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(100.0 * SUM(total_revenue) / SUM(SUM(total_revenue)) OVER (), 2) AS pct_of_total_revenue
FROM clean_retail
GROUP BY 
    CASE 
        WHEN country = 'United Kingdom' THEN 'United Kingdom' 
        ELSE 'International (Non-UK)' 
    END
ORDER BY total_revenue DESC;

-- Top 5 revenue-generating countries outside the UK
SELECT 
    country,
    COUNT(DISTINCT invoice_no) AS total_unique_orders,
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(SUM(total_revenue) / COUNT(DISTINCT invoice_no), 2) AS avg_order_value,
    ROUND(100.0 * SUM(total_revenue) / SUM(SUM(total_revenue)) OVER (), 2) AS intl_revenue_share_pct
FROM clean_retail
WHERE country != 'United Kingdom'
GROUP BY country
ORDER BY total_revenue DESC
LIMIT 5;
