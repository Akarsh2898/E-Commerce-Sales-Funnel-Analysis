/*
==============================================================================
  Business Queries 01 — Executive KPI Pack
  One-screen metrics for leadership / resume demo
==============================================================================
*/

-- KPI-1: Marketplace snapshot
SELECT
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    COUNT(DISTINCT s.seller_id) AS active_sellers,
    ROUND(SUM(f.item_revenue), 2) AS total_gmv,
    ROUND(SUM(f.item_contribution), 2) AS total_contribution,
    ROUND(AVG(r.review_score)::NUMERIC, 2) AS avg_review_score
FROM analytics.fact_order_items f
INNER JOIN analytics.dim_order o ON f.order_sk = o.order_sk
INNER JOIN analytics.dim_customer c ON f.customer_sk = c.customer_sk
INNER JOIN analytics.dim_seller s ON f.seller_sk = s.seller_sk
LEFT JOIN analytics.dim_review r ON f.review_sk = r.review_sk
WHERE o.order_status NOT IN ('canceled', 'unavailable');


-- KPI-2: On-time delivery rate
SELECT
    ROUND(100.0 * COUNT(*) FILTER (WHERE NOT is_late_delivery) / NULLIF(COUNT(*), 0), 2)
        AS on_time_delivery_pct
FROM analytics.dim_order
WHERE is_late_delivery IS NOT NULL;


-- KPI-3: Top category this period (subquery)
SELECT category, revenue
FROM (
    SELECT
        p.product_category_name_english AS category,
        ROUND(SUM(f.item_revenue), 2) AS revenue,
        RANK() OVER (ORDER BY SUM(f.item_revenue) DESC) AS rk
    FROM analytics.fact_order_items f
    INNER JOIN analytics.dim_product p ON f.product_sk = p.product_sk
    GROUP BY 1
) t
WHERE rk = 1;


-- KPI-4: Repeat purchase rate
WITH cust AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT f.order_id) AS orders
    FROM analytics.fact_order_items f
    INNER JOIN analytics.dim_customer c ON f.customer_sk = c.customer_sk
    GROUP BY 1
)
SELECT
    ROUND(100.0 * COUNT(*) FILTER (WHERE orders > 1) / COUNT(*), 2)
        AS repeat_customer_pct
FROM cust;
