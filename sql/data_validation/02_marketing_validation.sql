/*
==============================================================================
  Data Validation — Marketing Funnel
==============================================================================
*/

-- 1. PK uniqueness
SELECT mql_id, COUNT(*) AS n
FROM marketing.qualified_leads
GROUP BY mql_id
HAVING COUNT(*) > 1;

SELECT mql_id, COUNT(*) AS n
FROM marketing.closed_deals
GROUP BY mql_id
HAVING COUNT(*) > 1;

-- 2. Closed deals must reference an MQL
SELECT COUNT(*) AS orphan_closed_deals
FROM marketing.closed_deals c
LEFT JOIN marketing.qualified_leads m ON c.mql_id = m.mql_id
WHERE m.mql_id IS NULL;

-- 3. Won date before first contact (data-entry anomalies)
SELECT COUNT(*) AS won_before_contact
FROM marketing.closed_deals c
INNER JOIN marketing.qualified_leads m ON c.mql_id = m.mql_id
WHERE c.won_date < m.first_contact_date;

-- 4. Seller linkage coverage (expected gap vs marketplace extract)
SELECT
    COUNT(*) AS closed_deals,
    COUNT(s.seller_id) AS matched_sellers,
    ROUND(100.0 * COUNT(s.seller_id) / NULLIF(COUNT(*), 0), 2) AS pct_matched
FROM marketing.closed_deals c
LEFT JOIN ecommerce.sellers s ON c.seller_id = s.seller_id;

-- 5. Funnel drop-off volume
SELECT
    (SELECT COUNT(*) FROM marketing.qualified_leads) AS total_mqls,
    (SELECT COUNT(*) FROM marketing.closed_deals) AS closed_deals,
    ROUND(
        100.0 * (SELECT COUNT(*) FROM marketing.closed_deals)
             / NULLIF((SELECT COUNT(*) FROM marketing.qualified_leads), 0),
        2
    ) AS conversion_pct;

-- 6. Origin null/unknown share
SELECT origin, COUNT(*) AS leads
FROM marketing.qualified_leads
GROUP BY origin
ORDER BY leads DESC;

-- 7. Declared revenue completeness
SELECT
    ROUND(100.0 * COUNT(*) FILTER (WHERE declared_monthly_revenue IS NOT NULL) / COUNT(*), 2)
        AS pct_with_revenue,
    ROUND(100.0 * COUNT(*) FILTER (WHERE declared_monthly_revenue > 0) / COUNT(*), 2)
        AS pct_with_positive_revenue
FROM marketing.closed_deals;
