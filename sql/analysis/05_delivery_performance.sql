/*
==============================================================================
  Analysis 05 — Order & Delivery Performance
  Techniques: date arithmetic, CASE, GROUP BY/HAVING, JOINs
==============================================================================
*/

-- Q13. Overall delivery KPI summary
SELECT
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NOT NULL) AS delivered_orders,
    ROUND(AVG(delivery_days)::NUMERIC, 2) AS avg_delivery_days,
    ROUND(AVG(estimated_delivery_days)::NUMERIC, 2) AS avg_estimated_days,
    ROUND(100.0 * AVG(CASE WHEN is_late_delivery THEN 1 ELSE 0 END), 2)
        AS late_delivery_pct,
    ROUND(AVG(delay_days) FILTER (WHERE is_late_delivery)::NUMERIC, 2)
        AS avg_delay_when_late
FROM analytics.dim_order
WHERE order_status = 'delivered';


-- Q14. Late delivery by customer state
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(AVG(o.delivery_days)::NUMERIC, 2) AS avg_delivery_days,
    ROUND(100.0 * AVG(CASE WHEN o.is_late_delivery THEN 1 ELSE 0 END), 2)
        AS late_pct
FROM analytics.fact_order_items f
INNER JOIN analytics.dim_order o ON f.order_sk = o.order_sk
INNER JOIN analytics.dim_customer c ON f.customer_sk = c.customer_sk
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
HAVING COUNT(DISTINCT o.order_id) >= 100
ORDER BY late_pct DESC;


-- Q15. Impact of late delivery on review scores
-- Demonstrates: CASE grouping + JOIN
SELECT
    CASE WHEN o.is_late_delivery THEN 'Late' ELSE 'On Time' END AS delivery_flag,
    COUNT(*) AS review_rows,
    ROUND(AVG(r.review_score)::NUMERIC, 2) AS avg_score,
    ROUND(100.0 * COUNT(*) FILTER (WHERE r.review_score <= 2) / COUNT(*), 2)
        AS pct_low_scores
FROM analytics.dim_order o
INNER JOIN analytics.dim_review r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.is_late_delivery IS NOT NULL
GROUP BY 1;


-- Q16. Delivery time distribution buckets
SELECT
    CASE
        WHEN delivery_days <= 3 THEN '0-3 days'
        WHEN delivery_days <= 7 THEN '4-7 days'
        WHEN delivery_days <= 14 THEN '8-14 days'
        WHEN delivery_days <= 30 THEN '15-30 days'
        ELSE '30+ days'
    END AS delivery_bucket,
    COUNT(*) AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM analytics.dim_order
WHERE delivery_days IS NOT NULL
GROUP BY 1
ORDER BY MIN(delivery_days);
