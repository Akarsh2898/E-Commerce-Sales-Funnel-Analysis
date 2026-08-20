/*
==============================================================================
  Analysis 07 — Advanced SQL Patterns (Windows, Subqueries, Multi-joins)
==============================================================================
*/

-- Q20. Running 7-day order volume (frame clause)
WITH daily AS (
    SELECT
        d.full_date,
        COUNT(DISTINCT f.order_id) AS daily_orders,
        ROUND(SUM(f.item_revenue), 2) AS daily_gmv
    FROM analytics.fact_order_items f
    INNER JOIN analytics.dim_date d ON f.date_key = d.date_key
    GROUP BY d.full_date
)
SELECT
    full_date,
    daily_orders,
    daily_gmv,
    SUM(daily_orders) OVER (
        ORDER BY full_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS orders_7d_rolling,
    ROUND(AVG(daily_gmv) OVER (
        ORDER BY full_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS gmv_7d_avg
FROM daily
ORDER BY full_date;


-- Q21. Category contribution vs late-delivery rate (multi-metric)
SELECT
    p.product_category_name_english AS category,
    ROUND(SUM(f.item_revenue), 2) AS revenue,
    ROUND(AVG(o.delivery_days)::NUMERIC, 2) AS avg_delivery_days,
    ROUND(100.0 * AVG(CASE WHEN o.is_late_delivery THEN 1 ELSE 0 END), 2) AS late_pct,
    ROUND(AVG(r.review_score)::NUMERIC, 2) AS avg_review
FROM analytics.fact_order_items f
INNER JOIN analytics.dim_product p ON f.product_sk = p.product_sk
INNER JOIN analytics.dim_order o ON f.order_sk = o.order_sk
LEFT JOIN analytics.dim_review r ON f.review_sk = r.review_sk
WHERE p.product_category_name_english IS NOT NULL
  AND p.product_category_name_english <> 'untranslated'
GROUP BY p.product_category_name_english
HAVING COUNT(*) >= 200
ORDER BY late_pct DESC
LIMIT 20;


-- Q22. Payment mix and average order value by payment type
-- Demonstrates: subquery for order totals + JOIN to payments dim
WITH order_value AS (
    SELECT
        f.order_id,
        SUM(f.item_revenue) AS order_gmv
    FROM analytics.fact_order_items f
    GROUP BY f.order_id
)
SELECT
    p.primary_payment_type,
    COUNT(*) AS orders,
    ROUND(AVG(ov.order_gmv), 2) AS avg_order_value,
    ROUND(AVG(p.max_installments)::NUMERIC, 2) AS avg_max_installments,
    ROUND(SUM(p.total_payment_value), 2) AS total_paid
FROM order_value ov
INNER JOIN analytics.dim_payment p ON ov.order_id = p.order_id
GROUP BY p.primary_payment_type
ORDER BY total_paid DESC;


-- Q23. Sellers above category average (correlated subquery style via CTE)
WITH seller_cat AS (
    SELECT
        s.seller_id,
        p.product_category_name_english AS category,
        ROUND(SUM(f.item_revenue), 2) AS seller_cat_revenue
    FROM analytics.fact_order_items f
    INNER JOIN analytics.dim_seller s ON f.seller_sk = s.seller_sk
    INNER JOIN analytics.dim_product p ON f.product_sk = p.product_sk
    GROUP BY s.seller_id, p.product_category_name_english
),
cat_avg AS (
    SELECT category, AVG(seller_cat_revenue) AS avg_seller_revenue
    FROM seller_cat
    GROUP BY category
)
SELECT
    sc.seller_id,
    sc.category,
    sc.seller_cat_revenue,
    ROUND(ca.avg_seller_revenue, 2) AS category_avg_seller_revenue
FROM seller_cat sc
INNER JOIN cat_avg ca ON sc.category = ca.category
WHERE sc.seller_cat_revenue > ca.avg_seller_revenue * 3
ORDER BY sc.seller_cat_revenue DESC
LIMIT 25;
