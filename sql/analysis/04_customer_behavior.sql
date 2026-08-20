/*
==============================================================================
  Analysis 04 — Customer Purchasing Behavior
  Techniques: CTEs, subqueries, LEFT JOIN, window functions, CASE
==============================================================================
*/

-- Q9. Repeat vs one-time customers
-- Demonstrates: CTE + CASE + aggregation
WITH cust_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        ROUND(SUM(f.item_revenue), 2) AS lifetime_revenue
    FROM analytics.fact_order_items f
    INNER JOIN analytics.dim_customer c ON f.customer_sk = c.customer_sk
    INNER JOIN analytics.dim_order o ON f.order_sk = o.order_sk
    GROUP BY c.customer_unique_id
)
SELECT
    CASE WHEN order_count = 1 THEN 'one_time' ELSE 'repeat' END AS customer_type,
    COUNT(*) AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_customers,
    ROUND(AVG(lifetime_revenue), 2) AS avg_lifetime_revenue,
    ROUND(SUM(lifetime_revenue), 2) AS total_revenue
FROM cust_orders
GROUP BY 1;


-- Q10. Top 10 customers by lifetime value (CLV proxy)
SELECT
    c.customer_unique_id,
    c.customer_state,
    COUNT(DISTINCT f.order_id) AS orders,
    ROUND(SUM(f.item_revenue), 2) AS lifetime_value,
    ROUND(AVG(f.price), 2) AS avg_item_price
FROM analytics.fact_order_items f
INNER JOIN analytics.dim_customer c ON f.customer_sk = c.customer_sk
GROUP BY c.customer_unique_id, c.customer_state
ORDER BY lifetime_value DESC
LIMIT 10;


-- Q11. Customers who never left a review (LEFT JOIN anti-pattern)
-- Demonstrates: LEFT JOIN + IS NULL filter (anti-join)
SELECT COUNT(DISTINCT c.customer_unique_id) AS customers_without_reviews
FROM analytics.dim_customer c
INNER JOIN analytics.fact_order_items f ON c.customer_sk = f.customer_sk
LEFT JOIN analytics.dim_review r ON f.review_sk = r.review_sk
WHERE r.review_sk IS NULL;


-- Q12. RFM-style segmentation with NTILE windows
-- Demonstrates: multiple window functions, CASE scoring
WITH rfm_base AS (
    SELECT
        c.customer_unique_id,
        MAX(d.full_date) AS last_purchase_date,
        COUNT(DISTINCT f.order_id) AS frequency,
        ROUND(SUM(f.item_revenue), 2) AS monetary
    FROM analytics.fact_order_items f
    INNER JOIN analytics.dim_customer c ON f.customer_sk = c.customer_sk
    INNER JOIN analytics.dim_date d ON f.date_key = d.date_key
    GROUP BY c.customer_unique_id
),
scored AS (
    SELECT
        customer_unique_id,
        last_purchase_date,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY last_purchase_date DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM rfm_base
)
SELECT
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'Promising'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        ELSE 'Others'
    END AS segment,
    COUNT(*) AS customers,
    ROUND(AVG(monetary), 2) AS avg_monetary
FROM scored
GROUP BY 1
ORDER BY customers DESC;
