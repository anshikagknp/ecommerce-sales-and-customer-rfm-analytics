import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sqlalchemy import create_engine

# Ensure output directory exists and set a clean visual style
os.makedirs('reports/figures', exist_ok=True)
sns.set_theme(style='whitegrid', font_scale=1.05)

engine = create_engine('postgresql://localhost:5432/online_retail_analytics')

# Chart 1: Monthly sales trend (highlighting holiday seasonality)
print("Creating monthly sales chart...")
monthly_sql = """
SELECT 
    TO_CHAR(invoice_date, 'YYYY-MM') AS sales_month,
    ROUND(SUM(total_revenue), 2) AS monthly_revenue
FROM clean_retail
GROUP BY TO_CHAR(invoice_date, 'YYYY-MM')
ORDER BY sales_month;
"""
df_monthly = pd.read_sql(monthly_sql, engine)

plt.figure(figsize=(10, 4.8))

# Highlight the peak month (November 2011) in red and the rest in standard blue
bar_colors = ['#d62728' if m == '2011-11' else '#1f77b4' for m in df_monthly['sales_month']]
bars = plt.bar(df_monthly['sales_month'], df_monthly['monthly_revenue'] / 1e6, color=bar_colors, width=0.65)
plt.title('Monthly Sales Trend: Q4 Holiday Spike', fontsize=13, weight='bold', pad=12)
plt.xlabel('Month', weight='bold')
plt.ylabel('Revenue (£ Millions)', weight='bold')
plt.xticks(rotation=45)
plt.ylim(0, 1.8)

# Add revenue value on top of each bar
for bar in bars:
    y_val = bar.get_height()
    plt.text(bar.get_x() + bar.get_width() / 2, y_val + 0.04, f'£{y_val:.2f}M', ha='center', va='bottom', fontsize=8.5)

plt.tight_layout()
plt.savefig('reports/figures/01_monthly_sales_trend.png', dpi=200)
plt.close()

# Chart 2: Top 5 international revenue markets outside the UK
print("Creating international markets chart...")
intl_sql = """
SELECT 
    country,
    ROUND(SUM(total_revenue) / 1000.0, 1) AS total_revenue_k
FROM clean_retail
WHERE country != 'United Kingdom'
GROUP BY country
ORDER BY total_revenue_k DESC
LIMIT 5;
"""
df_intl = pd.read_sql(intl_sql, engine)

plt.figure(figsize=(8.5, 4.2))
ax = sns.barplot(data=df_intl, y='country', x='total_revenue_k', hue='country', palette='Blues_r', legend=False)
plt.title('Top 5 International Markets by Revenue (Outside UK)', fontsize=13, weight='bold', pad=12)
plt.xlabel('Revenue (£ Thousands)', weight='bold')
plt.ylabel('Country', weight='bold')

for p in ax.patches:
    val = p.get_width()
    ax.annotate(f'£{val:.1f}K', xy=(val + 4, p.get_y() + p.get_height() / 2), va='center', fontsize=9.5)

plt.xlim(0, 330)
plt.tight_layout()
plt.savefig('reports/figures/02_international_markets.png', dpi=200)
plt.close()

# Chart 3: Order volume by hour of day (identifying peak ordering windows)
print("Creating hourly demand chart...")
hourly_sql = """
SELECT 
    EXTRACT(HOUR FROM invoice_date)::INTEGER AS order_hour,
    COUNT(DISTINCT invoice_no) AS total_orders
FROM clean_retail
GROUP BY EXTRACT(HOUR FROM invoice_date)::INTEGER
ORDER BY order_hour;
"""
df_hourly = pd.read_sql(hourly_sql, engine)

plt.figure(figsize=(9.5, 4.2))
# Highlight peak midday hours (11 AM to 2 PM) in orange
peak_hours = [11, 12, 13, 14]
hour_colors = ['#ff7f0e' if h in peak_hours else '#aec7e8' for h in df_hourly['order_hour']]
plt.bar(df_hourly['order_hour'], df_hourly['total_orders'], color=hour_colors, width=0.7)
plt.title('Order Volume by Hour of Day (Peak: 11 AM - 2 PM)', fontsize=13, weight='bold', pad=12)
plt.xlabel('Hour of Day (24-Hour Clock)', weight='bold')
plt.ylabel('Orders Placed', weight='bold')
plt.xticks(df_hourly['order_hour'])

plt.tight_layout()
plt.savefig('reports/figures/03_hourly_demand.png', dpi=200)
plt.close()

# Chart 4: RFM customer segmentation (customer count % vs revenue share %)
print("Creating RFM segmentation chart...")
rfm_sql = """
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
        CASE 
            WHEN recency_days <= 30 AND frequency >= 5 THEN 'Champion / VIP'
            WHEN recency_days <= 90 AND frequency >= 2 THEN 'Loyal Customer'
            WHEN recency_days <= 60 AND frequency = 1  THEN 'New Active'
            WHEN recency_days > 90 AND monetary_total >= 1000 THEN 'At-Risk High Spender'
            WHEN recency_days > 180 THEN 'Lapsed / Churned'
            ELSE 'Occasional Buyer'
        END AS customer_segment,
        monetary_total
    FROM rfm_base
)
SELECT 
    customer_segment,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS customer_pct,
    ROUND(100.0 * SUM(monetary_total) / SUM(SUM(monetary_total)) OVER (), 1) AS revenue_pct
FROM rfm_segments
GROUP BY customer_segment
ORDER BY SUM(monetary_total) DESC;
"""
df_rfm = pd.read_sql(rfm_sql, engine)

fig, ax = plt.subplots(figsize=(9.5, 4.8))
indices = range(len(df_rfm))
bar_width = 0.35

bars1 = ax.bar([i - bar_width / 2 for i in indices], df_rfm['customer_pct'], bar_width, label='% of Customers', color='#4a90e2')
bars2 = ax.bar([i + bar_width / 2 for i in indices], df_rfm['revenue_pct'], bar_width, label='% of Revenue', color='#50e3c2')

ax.set_ylabel('Percentage (%)', weight='bold')
ax.set_title('Customer Base vs. Revenue Share by RFM Segment', fontsize=13, weight='bold', pad=12)
ax.set_xticks(indices)
ax.set_xticklabels(df_rfm['customer_segment'], rotation=20, ha='right')
ax.legend()
ax.set_ylim(0, 70)

# Add percentage labels above bars
for bar in bars1:
    h = bar.get_height()
    ax.annotate(f'{h:.1f}%', xy=(bar.get_x() + bar.get_width() / 2, h + 1), ha='center', va='bottom', fontsize=8)

for bar in bars2:
    h = bar.get_height()
    ax.annotate(f'{h:.1f}%', xy=(bar.get_x() + bar.get_width() / 2, h + 1), ha='center', va='bottom', fontsize=8, weight='bold')

plt.tight_layout()
plt.savefig('reports/figures/04_rfm_segments.png', dpi=200)
plt.close()

print("All charts updated in reports/figures/.")
