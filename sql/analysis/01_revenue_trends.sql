/*
==============================================================================
  Analysis 01 — Revenue & Contribution Trends
  Techniques: CTEs, JOINs, GROUP BY, date trunc, window functions (running total)
  Layer: analytics star schema
==============================================================================
*/

-- Q1. Monthly GMV (Gross Merchandise Value) and contribution (price - freight)
-- Demonstrates: CTE, INNER JOIN, date aggregation, ROUND
WITH monthly AS (
    SELECT
        d.year_number,
        d.month_number,
        d.month_name,
        COUNT(DISTINCT f.order_id) AS orders,
        COUNT(*) AS items_sold,
        ROUND(SUM(f.item_revenue), 2) AS gmv,
        ROUND(SUM(f.freight_value), 2) AS freight_cost,
        ROUND(SUM(f.item_contribution), 2) AS contribution
    FROM analytics.fact_order_items f
    INNER JOIN analytics.dim_date d ON f.date_key = d.date_key
    INNER JOIN analytics.dim_order o ON f.order_sk = o.order_sk
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY d.year_number, d.month_number, d.month_name
)
SELECT
    year_number,
    month_number,
    month_name,
    orders,
    items_sold,
    gmv,
    freight_cost,
    contribution,
    -- Running total of GMV across months (window)
    ROUND(SUM(gmv) OVER (ORDER BY year_number, month_number
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2)
        AS running_gmv,
    -- Month-over-month growth
    ROUND(
        100.0 * (gmv - LAG(gmv) OVER (ORDER BY year_number, month_number))
            / NULLIF(LAG(gmv) OVER (ORDER BY year_number, month_number), 0),
        2
    ) AS mom_gmv_growth_pct
FROM monthly
ORDER BY year_number, month_number;


-- Q2. Yearly revenue summary with YoY growth
-- Demonstrates: CTE, LAG window, CASE
WITH yearly AS (
    SELECT
        d.year_number,
        ROUND(SUM(f.item_revenue), 2) AS gmv,
        COUNT(DISTINCT f.order_id) AS orders
    FROM analytics.fact_order_items f
    INNER JOIN analytics.dim_date d ON f.date_key = d.date_key
    GROUP BY d.year_number
)
SELECT
    year_number,
    gmv,
    orders,
    LAG(gmv) OVER (ORDER BY year_number) AS prior_year_gmv,
    CASE
        WHEN LAG(gmv) OVER (ORDER BY year_number) IS NULL THEN NULL
        ELSE ROUND(100.0 * (gmv - LAG(gmv) OVER (ORDER BY year_number))
                   / NULLIF(LAG(gmv) OVER (ORDER BY year_number), 0), 2)
    END AS yoy_growth_pct
FROM yearly
ORDER BY year_number;
