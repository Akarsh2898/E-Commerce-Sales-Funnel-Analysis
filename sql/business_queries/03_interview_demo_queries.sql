/*
==============================================================================
  Business Queries 03 — Interview Demo Set (talk-track friendly)
------------------------------------------------------------------------------
  Five polished queries you can walk through live in an interview.
==============================================================================
*/

-- DEMO 1: "Show me revenue by month with MoM growth"
WITH m AS (
    SELECT
        DATE_TRUNC('month', d.full_date)::DATE AS month,
        ROUND(SUM(f.item_revenue), 2) AS gmv
    FROM analytics.fact_order_items f
    JOIN analytics.dim_date d ON f.date_key = d.date_key
    GROUP BY 1
)
SELECT
    month,
    gmv,
    ROUND(100.0 * (gmv - LAG(gmv) OVER (ORDER BY month))
          / NULLIF(LAG(gmv) OVER (ORDER BY month), 0), 2) AS mom_pct
FROM m
ORDER BY month;


-- DEMO 2: "Which categories drive 80% of revenue?" (Pareto)
WITH cat AS (
    SELECT
        p.product_category_name_english AS category,
        SUM(f.item_revenue) AS revenue
    FROM analytics.fact_order_items f
    JOIN analytics.dim_product p ON f.product_sk = p.product_sk
    GROUP BY 1
),
ordered AS (
    SELECT
        category,
        revenue,
        SUM(revenue) OVER (ORDER BY revenue DESC
                           ROWS UNBOUNDED PRECEDING) AS running_rev,
        SUM(revenue) OVER () AS total_rev
    FROM cat
)
SELECT
    category,
    ROUND(revenue, 2) AS revenue,
    ROUND(100.0 * running_rev / total_rev, 2) AS cumulative_pct
FROM ordered
WHERE running_rev / total_rev <= 0.80
   OR running_rev - revenue <= 0.80 * total_rev
ORDER BY revenue DESC;


-- DEMO 3: "Do late deliveries hurt ratings?"
SELECT
    CASE WHEN is_late_delivery THEN 'Late' ELSE 'On Time' END AS status,
    ROUND(AVG(r.review_score)::NUMERIC, 2) AS avg_score,
    COUNT(*) AS n
FROM analytics.dim_order o
JOIN analytics.dim_review r ON o.order_id = r.order_id
WHERE is_late_delivery IS NOT NULL
GROUP BY 1;


-- DEMO 4: "Repeat purchase rate by state"
WITH cust AS (
    SELECT
        c.customer_state,
        c.customer_unique_id,
        COUNT(DISTINCT f.order_id) AS orders
    FROM analytics.fact_order_items f
    JOIN analytics.dim_customer c ON f.customer_sk = c.customer_sk
    GROUP BY 1, 2
)
SELECT
    customer_state,
    COUNT(*) AS customers,
    ROUND(100.0 * COUNT(*) FILTER (WHERE orders > 1) / COUNT(*), 2)
        AS repeat_pct
FROM cust
GROUP BY customer_state
HAVING COUNT(*) >= 500
ORDER BY repeat_pct DESC;


-- DEMO 5: "Best marketing origin for high-GMV sellers"
SELECT
    m.origin,
    COUNT(DISTINCT cd.seller_id) AS closed_sellers_in_marketplace,
    ROUND(SUM(f.item_revenue), 2) AS attributed_gmv,
    ROUND(AVG(r.review_score)::NUMERIC, 2) AS avg_review
FROM marketing.qualified_leads m
JOIN marketing.closed_deals cd ON m.mql_id = cd.mql_id
JOIN analytics.dim_seller s ON cd.seller_id = s.seller_id
JOIN analytics.fact_order_items f ON s.seller_sk = f.seller_sk
LEFT JOIN analytics.dim_review r ON f.review_sk = r.review_sk
GROUP BY m.origin
ORDER BY attributed_gmv DESC;
