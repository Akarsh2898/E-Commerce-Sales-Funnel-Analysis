/*
==============================================================================
  Analysis 03 — Seller Performance
  Techniques: JOINs, CTEs, window DENSE_RANK, HAVING
==============================================================================
*/

-- Q6. Top 20 sellers by GMV with dense rank
WITH seller_perf AS (
    SELECT
        s.seller_id,
        s.seller_state,
        COUNT(DISTINCT f.order_id) AS orders,
        COUNT(*) AS items,
        ROUND(SUM(f.item_revenue), 2) AS gmv,
        ROUND(AVG(r.review_score), 2) AS avg_review
    FROM analytics.fact_order_items f
    INNER JOIN analytics.dim_seller s ON f.seller_sk = s.seller_sk
    LEFT JOIN analytics.dim_review r ON f.review_sk = r.review_sk
    GROUP BY s.seller_id, s.seller_state
    HAVING COUNT(DISTINCT f.order_id) >= 10
)
SELECT
    seller_id,
    seller_state,
    orders,
    items,
    gmv,
    avg_review,
    DENSE_RANK() OVER (ORDER BY gmv DESC) AS gmv_rank
FROM seller_perf
ORDER BY gmv DESC
LIMIT 20;


-- Q7. Sellers with strong sales but weak reviews (quality risk)
-- Demonstrates: HAVING on multiple metrics, LEFT JOIN
SELECT
    s.seller_id,
    s.seller_state,
    COUNT(DISTINCT f.order_id) AS orders,
    ROUND(SUM(f.item_revenue), 2) AS gmv,
    ROUND(AVG(r.review_score), 2) AS avg_review,
    ROUND(100.0 * AVG(CASE WHEN o.is_late_delivery THEN 1 ELSE 0 END), 2)
        AS late_delivery_pct
FROM analytics.fact_order_items f
INNER JOIN analytics.dim_seller s ON f.seller_sk = s.seller_sk
INNER JOIN analytics.dim_order o ON f.order_sk = o.order_sk
LEFT JOIN analytics.dim_review r ON f.review_sk = r.review_sk
GROUP BY s.seller_id, s.seller_state
HAVING COUNT(DISTINCT f.order_id) >= 50
   AND AVG(r.review_score) < 3.5
ORDER BY gmv DESC
LIMIT 25;


-- Q8. Seller state contribution (RIGHT JOIN pattern vs geography)
-- Demonstrates: RIGHT JOIN — keep all sellers even if some states dominate listing
SELECT
    COALESCE(s.seller_state, 'UNK') AS seller_state,
    COUNT(DISTINCT s.seller_id) AS sellers,
    COUNT(f.fact_sk) AS items_sold,
    ROUND(SUM(f.item_revenue), 2) AS gmv
FROM analytics.fact_order_items f
RIGHT JOIN analytics.dim_seller s ON f.seller_sk = s.seller_sk
GROUP BY COALESCE(s.seller_state, 'UNK')
ORDER BY gmv DESC NULLS LAST;
