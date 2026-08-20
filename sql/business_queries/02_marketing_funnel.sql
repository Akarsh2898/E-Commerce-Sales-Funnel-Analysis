/*
==============================================================================
  Business Queries 02 — Marketing Funnel & Seller Acquisition Quality
  Techniques: LEFT JOIN funnel, conversion rates, cross-domain JOIN to ecommerce
==============================================================================
*/

-- BQ1. Overall MQL → Closed Deal conversion
SELECT
    COUNT(DISTINCT m.mql_id) AS total_mqls,
    COUNT(DISTINCT c.mql_id) AS closed_deals,
    ROUND(
        100.0 * COUNT(DISTINCT c.mql_id) / NULLIF(COUNT(DISTINCT m.mql_id), 0),
        2
    ) AS conversion_pct
FROM marketing.qualified_leads m
LEFT JOIN marketing.closed_deals c ON m.mql_id = c.mql_id;


-- BQ2. Conversion by lead origin (LEFT JOIN preserves non-converting origins)
SELECT
    m.origin,
    COUNT(DISTINCT m.mql_id) AS mqls,
    COUNT(DISTINCT c.mql_id) AS closed,
    ROUND(
        100.0 * COUNT(DISTINCT c.mql_id) / NULLIF(COUNT(DISTINCT m.mql_id), 0),
        2
    ) AS conversion_pct
FROM marketing.qualified_leads m
LEFT JOIN marketing.closed_deals c ON m.mql_id = c.mql_id
GROUP BY m.origin
ORDER BY conversion_pct DESC, mqls DESC;


-- BQ3. Declared revenue quality by business type
SELECT
    COALESCE(business_type, 'unknown') AS business_type,
    COUNT(*) AS sellers_closed,
    ROUND(AVG(declared_monthly_revenue) FILTER (WHERE declared_monthly_revenue > 0), 2)
        AS avg_positive_declared_revenue,
    ROUND(SUM(declared_monthly_revenue), 2) AS total_declared_revenue
FROM marketing.closed_deals
GROUP BY 1
ORDER BY total_declared_revenue DESC NULLS LAST;


-- BQ4. Acquired sellers that became active in marketplace + their GMV
-- Demonstrates: marketing → ecommerce bridge via seller_id
WITH acquired AS (
    SELECT
        c.seller_id,
        c.business_type,
        c.origin_proxy
    FROM (
        SELECT
            cd.seller_id,
            cd.business_type,
            m.origin AS origin_proxy
        FROM marketing.closed_deals cd
        INNER JOIN marketing.qualified_leads m ON cd.mql_id = m.mql_id
        WHERE cd.seller_id IS NOT NULL
    ) c
)
SELECT
    a.business_type,
    a.origin_proxy AS lead_origin,
    COUNT(DISTINCT a.seller_id) AS acquired_sellers,
    COUNT(DISTINCT f.order_id) AS marketplace_orders,
    ROUND(SUM(f.item_revenue), 2) AS marketplace_gmv
FROM acquired a
INNER JOIN analytics.dim_seller s ON a.seller_id = s.seller_id
INNER JOIN analytics.fact_order_items f ON s.seller_sk = f.seller_sk
GROUP BY a.business_type, a.origin_proxy
ORDER BY marketplace_gmv DESC NULLS LAST
LIMIT 30;


-- BQ5. Time-to-close distribution (contact → won)
SELECT
    CASE
        WHEN (c.won_date - m.first_contact_date) <= 7 THEN '0-7 days'
        WHEN (c.won_date - m.first_contact_date) <= 30 THEN '8-30 days'
        WHEN (c.won_date - m.first_contact_date) <= 90 THEN '31-90 days'
        ELSE '90+ days'
    END AS close_speed_bucket,
    COUNT(*) AS deals
FROM marketing.closed_deals c
INNER JOIN marketing.qualified_leads m ON c.mql_id = m.mql_id
WHERE c.won_date >= m.first_contact_date
GROUP BY 1
ORDER BY MIN(c.won_date - m.first_contact_date);


-- BQ6. Post-acquisition delivery quality by business type
SELECT
    COALESCE(cd.business_type, 'unknown') AS business_type,
    COUNT(DISTINCT f.order_id) AS orders,
    ROUND(AVG(o.delivery_days)::NUMERIC, 2) AS avg_delivery_days,
    ROUND(100.0 * AVG(CASE WHEN o.is_late_delivery THEN 1 ELSE 0 END), 2)
        AS late_pct,
    ROUND(AVG(r.review_score)::NUMERIC, 2) AS avg_review
FROM marketing.closed_deals cd
INNER JOIN analytics.dim_seller s ON cd.seller_id = s.seller_id
INNER JOIN analytics.fact_order_items f ON s.seller_sk = f.seller_sk
INNER JOIN analytics.dim_order o ON f.order_sk = o.order_sk
LEFT JOIN analytics.dim_review r ON f.review_sk = r.review_sk
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY 1
HAVING COUNT(DISTINCT f.order_id) >= 20
ORDER BY late_pct DESC;
