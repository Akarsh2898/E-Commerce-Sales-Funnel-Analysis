/*
==============================================================================
  Analysis 06 — Growth, Cohort Retention & Repeat Purchases
  Techniques: CTEs, self-joins/subqueries, date_trunc, window functions
==============================================================================
*/

-- Q17. Monthly new vs returning customer orders
-- Demonstrates: CTE with first-purchase window + conditional aggregation
WITH first_purchase AS (
    SELECT
        c.customer_unique_id,
        MIN(d.full_date) AS first_order_date
    FROM analytics.fact_order_items f
    INNER JOIN analytics.dim_customer c ON f.customer_sk = c.customer_sk
    INNER JOIN analytics.dim_date d ON f.date_key = d.date_key
    GROUP BY c.customer_unique_id
),
order_level AS (
    SELECT DISTINCT
        c.customer_unique_id,
        f.order_id,
        DATE_TRUNC('month', d.full_date)::DATE AS order_month,
        DATE_TRUNC('month', fp.first_order_date)::DATE AS cohort_month
    FROM analytics.fact_order_items f
    INNER JOIN analytics.dim_customer c ON f.customer_sk = c.customer_sk
    INNER JOIN analytics.dim_date d ON f.date_key = d.date_key
    INNER JOIN first_purchase fp ON c.customer_unique_id = fp.customer_unique_id
)
SELECT
    order_month,
    COUNT(*) FILTER (WHERE order_month = cohort_month) AS new_customer_orders,
    COUNT(*) FILTER (WHERE order_month > cohort_month) AS returning_customer_orders,
    COUNT(*) AS total_orders
FROM order_level
GROUP BY order_month
ORDER BY order_month;


-- Q18. Cohort retention: % of cohort that returns in month N
-- Demonstrates: nested CTEs, date arithmetic, LEFT JOIN pattern for cohorts
WITH first_purchase AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', MIN(d.full_date))::DATE AS cohort_month
    FROM analytics.fact_order_items f
    INNER JOIN analytics.dim_customer c ON f.customer_sk = c.customer_sk
    INNER JOIN analytics.dim_date d ON f.date_key = d.date_key
    GROUP BY c.customer_unique_id
),
activity AS (
    SELECT DISTINCT
        c.customer_unique_id,
        DATE_TRUNC('month', d.full_date)::DATE AS activity_month
    FROM analytics.fact_order_items f
    INNER JOIN analytics.dim_customer c ON f.customer_sk = c.customer_sk
    INNER JOIN analytics.dim_date d ON f.date_key = d.date_key
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS cohort_customers
    FROM first_purchase
    GROUP BY cohort_month
),
retained AS (
    SELECT
        fp.cohort_month,
        (
            EXTRACT(YEAR FROM a.activity_month) * 12
          + EXTRACT(MONTH FROM a.activity_month)
        ) - (
            EXTRACT(YEAR FROM fp.cohort_month) * 12
          + EXTRACT(MONTH FROM fp.cohort_month)
        ) AS month_number,
        COUNT(DISTINCT fp.customer_unique_id) AS active_customers
    FROM first_purchase fp
    INNER JOIN activity a ON fp.customer_unique_id = a.customer_unique_id
    GROUP BY 1, 2
)
SELECT
    r.cohort_month,
    r.month_number,
    cs.cohort_customers,
    r.active_customers,
    ROUND(100.0 * r.active_customers / cs.cohort_customers, 2) AS retention_pct
FROM retained r
INNER JOIN cohort_size cs ON r.cohort_month = cs.cohort_month
WHERE r.month_number BETWEEN 0 AND 6
ORDER BY r.cohort_month, r.month_number;


-- Q19. Customers with repeat purchases within 90 days (subquery)
SELECT COUNT(*) AS customers_with_90d_repeat
FROM (
    SELECT
        c.customer_unique_id,
        MIN(d.full_date) AS first_dt,
        MAX(d.full_date) AS last_dt,
        COUNT(DISTINCT f.order_id) AS orders
    FROM analytics.fact_order_items f
    INNER JOIN analytics.dim_customer c ON f.customer_sk = c.customer_sk
    INNER JOIN analytics.dim_date d ON f.date_key = d.date_key
    GROUP BY c.customer_unique_id
    HAVING COUNT(DISTINCT f.order_id) >= 2
       AND (MAX(d.full_date) - MIN(d.full_date)) <= 90
) t;
