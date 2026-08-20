/*
==============================================================================
  Data Cleaning & Transformation — Staging → Ecommerce / Marketing
------------------------------------------------------------------------------
  Casts types, trims text, normalizes booleans, and enforces load order
  so primary/foreign keys succeed.
==============================================================================
*/

BEGIN;

-- Wipe analytical tables (children first)
TRUNCATE TABLE
    marketing.closed_deals,
    marketing.qualified_leads,
    ecommerce.order_reviews,
    ecommerce.order_payments,
    ecommerce.order_items,
    ecommerce.orders,
    ecommerce.products,
    ecommerce.sellers,
    ecommerce.customers,
    ecommerce.geolocation,
    ecommerce.category_translation
RESTART IDENTITY;

-- ---------------------------------------------------------------------------
-- 1. Category translation (lookup)
-- ---------------------------------------------------------------------------
INSERT INTO ecommerce.category_translation (
    product_category_name,
    product_category_name_english
)
SELECT DISTINCT
    TRIM(product_category_name),
    TRIM(product_category_name_english)
FROM staging.category_translation
WHERE NULLIF(TRIM(product_category_name), '') IS NOT NULL
  AND NULLIF(TRIM(product_category_name_english), '') IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 2. Customers
-- ---------------------------------------------------------------------------
INSERT INTO ecommerce.customers (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
SELECT
    TRIM(customer_id),
    TRIM(customer_unique_id),
    NULLIF(TRIM(customer_zip_code_prefix), '')::INTEGER,
    INITCAP(TRIM(customer_city)),
    UPPER(TRIM(customer_state))
FROM staging.customers
WHERE NULLIF(TRIM(customer_id), '') IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 3. Sellers
-- ---------------------------------------------------------------------------
INSERT INTO ecommerce.sellers (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
SELECT
    TRIM(seller_id),
    NULLIF(TRIM(seller_zip_code_prefix), '')::INTEGER,
    LOWER(TRIM(seller_city)),
    UPPER(TRIM(seller_state))
FROM staging.sellers
WHERE NULLIF(TRIM(seller_id), '') IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 4. Products  (source CSV misspells length columns as "lenght")
-- ---------------------------------------------------------------------------
INSERT INTO ecommerce.products (
    product_id,
    product_category_name,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
SELECT
    TRIM(product_id),
    NULLIF(TRIM(product_category_name), ''),
    NULLIF(TRIM(product_name_lenght), '')::INTEGER,
    NULLIF(TRIM(product_description_lenght), '')::INTEGER,
    NULLIF(TRIM(product_photos_qty), '')::INTEGER,
    NULLIF(TRIM(product_weight_g), '')::INTEGER,
    NULLIF(TRIM(product_length_cm), '')::INTEGER,
    NULLIF(TRIM(product_height_cm), '')::INTEGER,
    NULLIF(TRIM(product_width_cm), '')::INTEGER
FROM staging.products
WHERE NULLIF(TRIM(product_id), '') IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 5. Geolocation
-- ---------------------------------------------------------------------------
INSERT INTO ecommerce.geolocation (
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
)
SELECT
    NULLIF(TRIM(geolocation_zip_code_prefix), '')::INTEGER,
    NULLIF(TRIM(geolocation_lat), '')::NUMERIC(10, 6),
    NULLIF(TRIM(geolocation_lng), '')::NUMERIC(10, 6),
    LOWER(TRIM(geolocation_city)),
    UPPER(TRIM(geolocation_state))
FROM staging.geolocation
WHERE NULLIF(TRIM(geolocation_zip_code_prefix), '') IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 6. Orders
-- ---------------------------------------------------------------------------
INSERT INTO ecommerce.orders (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
)
SELECT
    TRIM(order_id),
    TRIM(customer_id),
    LOWER(TRIM(order_status)),
    NULLIF(TRIM(order_purchase_timestamp), '')::TIMESTAMP,
    NULLIF(TRIM(order_approved_at), '')::TIMESTAMP,
    NULLIF(TRIM(order_delivered_carrier_date), '')::TIMESTAMP,
    NULLIF(TRIM(order_delivered_customer_date), '')::TIMESTAMP,
    NULLIF(TRIM(order_estimated_delivery_date), '')::TIMESTAMP
FROM staging.orders
WHERE NULLIF(TRIM(order_id), '') IS NOT NULL
  AND NULLIF(TRIM(customer_id), '') IS NOT NULL
  AND NULLIF(TRIM(order_purchase_timestamp), '') IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 7. Order items  (only rows that resolve to known parents)
-- ---------------------------------------------------------------------------
INSERT INTO ecommerce.order_items (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
)
SELECT
    TRIM(oi.order_id),
    TRIM(oi.order_item_id)::INTEGER,
    TRIM(oi.product_id),
    TRIM(oi.seller_id),
    NULLIF(TRIM(oi.shipping_limit_date), '')::TIMESTAMP,
    GREATEST(COALESCE(NULLIF(TRIM(oi.price), '')::NUMERIC(12, 2), 0), 0),
    GREATEST(COALESCE(NULLIF(TRIM(oi.freight_value), '')::NUMERIC(12, 2), 0), 0)
FROM staging.order_items oi
INNER JOIN ecommerce.orders o   ON o.order_id = TRIM(oi.order_id)
INNER JOIN ecommerce.products p ON p.product_id = TRIM(oi.product_id)
INNER JOIN ecommerce.sellers s  ON s.seller_id = TRIM(oi.seller_id);

-- ---------------------------------------------------------------------------
-- 8. Payments
-- ---------------------------------------------------------------------------
INSERT INTO ecommerce.order_payments (
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
)
SELECT
    TRIM(op.order_id),
    TRIM(op.payment_sequential)::INTEGER,
    LOWER(TRIM(op.payment_type)),
    COALESCE(NULLIF(TRIM(op.payment_installments), '')::INTEGER, 0),
    GREATEST(COALESCE(NULLIF(TRIM(op.payment_value), '')::NUMERIC(12, 2), 0), 0)
FROM staging.order_payments op
INNER JOIN ecommerce.orders o ON o.order_id = TRIM(op.order_id);

-- ---------------------------------------------------------------------------
-- 9. Reviews  (dedupe by review_id — keep first occurrence)
-- ---------------------------------------------------------------------------
INSERT INTO ecommerce.order_reviews (
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
)
SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
FROM (
    SELECT
        TRIM(r.review_id) AS review_id,
        TRIM(r.order_id) AS order_id,
        LEAST(GREATEST(NULLIF(TRIM(r.review_score), '')::INTEGER, 1), 5) AS review_score,
        NULLIF(TRIM(r.review_comment_title), '') AS review_comment_title,
        NULLIF(TRIM(r.review_comment_message), '') AS review_comment_message,
        NULLIF(TRIM(r.review_creation_date), '')::TIMESTAMP AS review_creation_date,
        NULLIF(TRIM(r.review_answer_timestamp), '')::TIMESTAMP AS review_answer_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY TRIM(r.review_id)
            ORDER BY NULLIF(TRIM(r.review_creation_date), '')::TIMESTAMP DESC NULLS LAST
        ) AS rn
    FROM staging.order_reviews r
    INNER JOIN ecommerce.orders o ON o.order_id = TRIM(r.order_id)
    WHERE NULLIF(TRIM(r.review_id), '') IS NOT NULL
      AND NULLIF(TRIM(r.review_score), '') IS NOT NULL
) d
WHERE rn = 1;

-- ---------------------------------------------------------------------------
-- 10. Marketing MQLs
-- ---------------------------------------------------------------------------
INSERT INTO marketing.qualified_leads (
    mql_id,
    first_contact_date,
    landing_page_id,
    origin
)
SELECT
    TRIM(mql_id),
    NULLIF(TRIM(first_contact_date), '')::DATE,
    NULLIF(TRIM(landing_page_id), ''),
    COALESCE(NULLIF(LOWER(TRIM(origin)), ''), 'unknown')
FROM staging.marketing_qualified_leads
WHERE NULLIF(TRIM(mql_id), '') IS NOT NULL
  AND NULLIF(TRIM(first_contact_date), '') IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 11. Marketing closed deals
-- ---------------------------------------------------------------------------
INSERT INTO marketing.closed_deals (
    mql_id,
    seller_id,
    sdr_id,
    sr_id,
    won_date,
    business_segment,
    lead_type,
    lead_behaviour_profile,
    has_company,
    has_gtin,
    average_stock,
    business_type,
    declared_product_catalog_size,
    declared_monthly_revenue
)
SELECT
    TRIM(c.mql_id),
    NULLIF(TRIM(c.seller_id), ''),
    NULLIF(TRIM(c.sdr_id), ''),
    NULLIF(TRIM(c.sr_id), ''),
    NULLIF(TRIM(c.won_date), '')::DATE,
    NULLIF(TRIM(c.business_segment), ''),
    NULLIF(TRIM(c.lead_type), ''),
    NULLIF(TRIM(c.lead_behaviour_profile), ''),
    CASE
        WHEN LOWER(TRIM(c.has_company)) IN ('true', 't', 'yes', '1') THEN TRUE
        WHEN LOWER(TRIM(c.has_company)) IN ('false', 'f', 'no', '0') THEN FALSE
        ELSE NULL
    END,
    CASE
        WHEN LOWER(TRIM(c.has_gtin)) IN ('true', 't', 'yes', '1') THEN TRUE
        WHEN LOWER(TRIM(c.has_gtin)) IN ('false', 'f', 'no', '0') THEN FALSE
        ELSE NULL
    END,
    NULLIF(TRIM(c.average_stock), ''),
    NULLIF(TRIM(c.business_type), ''),
    NULLIF(TRIM(c.declared_product_catalog_size), '')::NUMERIC(12, 2),
    NULLIF(TRIM(c.declared_monthly_revenue), '')::NUMERIC(14, 2)
FROM staging.marketing_closed_deals c
INNER JOIN marketing.qualified_leads m ON m.mql_id = TRIM(c.mql_id)
WHERE NULLIF(TRIM(c.won_date), '') IS NOT NULL;

COMMIT;

-- Post-clean counts
SELECT 'customers' AS entity, COUNT(*) FROM ecommerce.customers
UNION ALL SELECT 'orders', COUNT(*) FROM ecommerce.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM ecommerce.order_items
UNION ALL SELECT 'products', COUNT(*) FROM ecommerce.products
UNION ALL SELECT 'sellers', COUNT(*) FROM ecommerce.sellers
UNION ALL SELECT 'payments', COUNT(*) FROM ecommerce.order_payments
UNION ALL SELECT 'reviews', COUNT(*) FROM ecommerce.order_reviews
UNION ALL SELECT 'mqls', COUNT(*) FROM marketing.qualified_leads
UNION ALL SELECT 'closed_deals', COUNT(*) FROM marketing.closed_deals;
