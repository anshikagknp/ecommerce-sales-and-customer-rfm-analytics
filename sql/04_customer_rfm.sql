-- RFM metrics and top 10 spenders ranked with DENSE_RANK
-- Note: customer_id IS NOT NULL excludes anonymous guest checkouts
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
        -- Recency: Days between last date in dataset and customer's latest purchase
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

-- Segment customers into actionable cohorts based on RFM behavior
WITH customer_orders AS (
    SELECT 
        customer_id,
        invoice_no,
        invoice_date::date AS order_date,
        total_revenue
    FROM clean_retail
    WHERE customer_id IS NOT NULL
),
rfm_base AS (
    SELECT 
        customer_id,
        (SELECT MAX(order_date) FROM customer_orders) - MAX(order_date) AS recency_days,
        COUNT(DISTINCT invoice_no) AS frequency,
        ROUND(SUM(total_revenue), 2) AS monetary_total
    FROM customer_orders
    GROUP BY customer_id
),
rfm_segments AS (
    SELECT 
        customer_id,
        recency_days,
        frequency,
        monetary_total,
        CASE 
            WHEN recency_days <= 30 AND frequency >= 5 THEN 'Champion / VIP'
            WHEN recency_days <= 90 AND frequency >= 2 THEN 'Loyal Customer'
            WHEN recency_days <= 60 AND frequency = 1  THEN 'New Active Customer'
            WHEN recency_days > 90 AND monetary_total >= 1000 THEN 'At-Risk High Spender'
            WHEN recency_days > 180 THEN 'Lapsed / Churned'
            ELSE 'Occasional Buyer'
        END AS customer_segment
    FROM rfm_base
)
SELECT 
    customer_segment,
    COUNT(*) AS total_customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS customer_pct,
    ROUND(SUM(monetary_total), 2) AS segment_revenue,
    ROUND(100.0 * SUM(monetary_total) / SUM(SUM(monetary_total)) OVER (), 2) AS revenue_pct,
    ROUND(AVG(monetary_total), 2) AS avg_spend_per_customer
FROM rfm_segments
GROUP BY customer_segment
ORDER BY segment_revenue DESC;
