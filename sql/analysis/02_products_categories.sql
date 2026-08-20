/*
==============================================================================
  Analysis 02 — Top Products & Categories
  Techniques: JOINs, GROUP BY/HAVING, RANK window, CASE
==============================================================================
*/

-- Q3. Top 15 categories by revenue with rank and share of total
-- Demonstrates: CTE, window RANK, SUM() OVER() for share
WITH cat_rev AS (
    SELECT
        COALESCE(p.product_category_name_english, 'unknown') AS category,
        COUNT(*) AS units_sold,
        ROUND(SUM(f.item_revenue), 2) AS revenue,
        ROUND(AVG(f.price), 2) AS avg_price
    FROM analytics.fact_order_items f
    INNER JOIN analytics.dim_product p ON f.product_sk = p.product_sk
    GROUP BY 1
)
SELECT
    category,
    units_sold,
    revenue,
    avg_price,
    RANK() OVER (ORDER BY revenue DESC) AS revenue_rank,
    ROUND(100.0 * revenue / SUM(revenue) OVER (), 2) AS pct_of_total_revenue
FROM cat_rev
ORDER BY revenue DESC
LIMIT 15;


-- Q4. Categories with high volume but below-average AOV (opportunity / pricing)
-- Demonstrates: HAVING, subquery for global average
SELECT
    COALESCE(p.product_category_name_english, 'unknown') AS category,
    COUNT(*) AS units_sold,
    ROUND(AVG(f.price), 2) AS avg_item_price
FROM analytics.fact_order_items f
INNER JOIN analytics.dim_product p ON f.product_sk = p.product_sk
GROUP BY 1
HAVING COUNT(*) >= 500
   AND AVG(f.price) < (
        SELECT AVG(price) FROM analytics.fact_order_items
   )
ORDER BY units_sold DESC;


-- Q5. Price band mix using CASE
-- Demonstrates: CASE bucketing + aggregation
SELECT
    CASE
        WHEN f.price < 50 THEN 'A) < 50'
        WHEN f.price < 100 THEN 'B) 50-99'
        WHEN f.price < 200 THEN 'C) 100-199'
        WHEN f.price < 500 THEN 'D) 200-499'
        ELSE 'E) 500+'
    END AS price_band,
    COUNT(*) AS items,
    ROUND(SUM(f.item_revenue), 2) AS revenue,
    ROUND(AVG(f.freight_value), 2) AS avg_freight
FROM analytics.fact_order_items f
GROUP BY 1
ORDER BY 1;
