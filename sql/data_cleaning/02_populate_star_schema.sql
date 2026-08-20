/*
==============================================================================
  Populate Star Schema (analytics.*) from cleaned relational tables
------------------------------------------------------------------------------
  Rebuilds dimensions then the fact table. Safe to re-run.
==============================================================================
*/

BEGIN;

TRUNCATE TABLE
    analytics.fact_order_items,
    analytics.dim_review,
    analytics.dim_payment,
    analytics.dim_order,
    analytics.dim_seller,
    analytics.dim_product,
    analytics.dim_customer,
    analytics.dim_date
RESTART IDENTITY CASCADE;

-- ---------------------------------------------------------------------------
-- dim_date: cover the full purchase date range in the dataset
-- ---------------------------------------------------------------------------
INSERT INTO analytics.dim_date (
    date_key, full_date, day_of_week, day_name, day_of_month,
    week_of_year, month_number, month_name, quarter, year_number, is_weekend
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INTEGER AS date_key,
    d AS full_date,
    EXTRACT(ISODOW FROM d)::SMALLINT AS day_of_week,
    TO_CHAR(d, 'Dy') AS day_name,
    EXTRACT(DAY FROM d)::SMALLINT AS day_of_month,
    EXTRACT(WEEK FROM d)::SMALLINT AS week_of_year,
    EXTRACT(MONTH FROM d)::SMALLINT AS month_number,
    TO_CHAR(d, 'Mon') AS month_name,
    EXTRACT(QUARTER FROM d)::SMALLINT AS quarter,
    EXTRACT(YEAR FROM d)::INTEGER AS year_number,
    EXTRACT(ISODOW FROM d) IN (6, 7) AS is_weekend
FROM generate_series(
    (SELECT MIN(order_purchase_timestamp)::DATE FROM ecommerce.orders),
    (SELECT MAX(order_purchase_timestamp)::DATE FROM ecommerce.orders),
    INTERVAL '1 day'
) AS g(d);

-- ---------------------------------------------------------------------------
-- dim_customer
-- ---------------------------------------------------------------------------
INSERT INTO analytics.dim_customer (
    customer_id, customer_unique_id, customer_city, customer_state, customer_zip_prefix
)
SELECT
    customer_id,
    customer_unique_id,
    customer_city,
    customer_state,
    customer_zip_code_prefix
FROM ecommerce.customers;

-- ---------------------------------------------------------------------------
-- dim_product
-- ---------------------------------------------------------------------------
INSERT INTO analytics.dim_product (
    product_id,
    product_category_name,
    product_category_name_english,
    product_weight_g,
    product_photos_qty
)
SELECT
    p.product_id,
    p.product_category_name,
    COALESCE(t.product_category_name_english, 'untranslated'),
    p.product_weight_g,
    p.product_photos_qty
FROM ecommerce.products p
LEFT JOIN ecommerce.category_translation t
    ON p.product_category_name = t.product_category_name;

-- ---------------------------------------------------------------------------
-- dim_seller
-- ---------------------------------------------------------------------------
INSERT INTO analytics.dim_seller (
    seller_id, seller_city, seller_state, seller_zip_prefix
)
SELECT seller_id, seller_city, seller_state, seller_zip_code_prefix
FROM ecommerce.sellers;

-- ---------------------------------------------------------------------------
-- dim_order  (delivery KPIs pre-computed)
-- ---------------------------------------------------------------------------
INSERT INTO analytics.dim_order (
    order_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    delivery_days,
    estimated_delivery_days,
    is_late_delivery,
    delay_days
)
SELECT
    order_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    CASE
        WHEN order_delivered_customer_date IS NOT NULL
        THEN (order_delivered_customer_date::DATE - order_purchase_timestamp::DATE)
    END,
    CASE
        WHEN order_estimated_delivery_date IS NOT NULL
        THEN (order_estimated_delivery_date::DATE - order_purchase_timestamp::DATE)
    END,
    CASE
        WHEN order_delivered_customer_date IS NOT NULL
         AND order_estimated_delivery_date IS NOT NULL
        THEN order_delivered_customer_date > order_estimated_delivery_date
    END,
    CASE
        WHEN order_delivered_customer_date IS NOT NULL
         AND order_estimated_delivery_date IS NOT NULL
        THEN (order_delivered_customer_date::DATE - order_estimated_delivery_date::DATE)
    END
FROM ecommerce.orders;

-- ---------------------------------------------------------------------------
-- dim_payment  (order-level aggregation — prevents payment fan-out in facts)
-- ---------------------------------------------------------------------------
INSERT INTO analytics.dim_payment (
    order_id,
    primary_payment_type,
    payment_count,
    total_payment_value,
    max_installments
)
SELECT
    order_id,
    (ARRAY_AGG(payment_type ORDER BY payment_sequential))[1] AS primary_payment_type,
    COUNT(*) AS payment_count,
    SUM(payment_value) AS total_payment_value,
    MAX(payment_installments) AS max_installments
FROM ecommerce.order_payments
GROUP BY order_id;

-- ---------------------------------------------------------------------------
-- dim_review  (one row per order — latest review if multiple)
-- ---------------------------------------------------------------------------
INSERT INTO analytics.dim_review (
    order_id,
    review_id,
    review_score,
    review_creation_date,
    has_comment
)
SELECT
    order_id,
    review_id,
    review_score,
    review_creation_date,
    review_comment_message IS NOT NULL
FROM (
    SELECT
        r.*,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY review_creation_date DESC NULLS LAST, review_id
        ) AS rn
    FROM ecommerce.order_reviews r
) x
WHERE rn = 1;

-- ---------------------------------------------------------------------------
-- fact_order_items
-- ---------------------------------------------------------------------------
INSERT INTO analytics.fact_order_items (
    order_id,
    order_item_id,
    date_key,
    customer_sk,
    product_sk,
    seller_sk,
    order_sk,
    payment_sk,
    review_sk,
    price,
    freight_value,
    item_revenue,
    item_contribution,
    shipping_limit_date
)
SELECT
    oi.order_id,
    oi.order_item_id,
    TO_CHAR(o.order_purchase_timestamp, 'YYYYMMDD')::INTEGER AS date_key,
    dc.customer_sk,
    dp.product_sk,
    ds.seller_sk,
    do_.order_sk,
    dpay.payment_sk,
    drev.review_sk,
    oi.price,
    oi.freight_value,
    oi.price AS item_revenue,
    (oi.price - oi.freight_value) AS item_contribution,
    oi.shipping_limit_date
FROM ecommerce.order_items oi
INNER JOIN ecommerce.orders o
    ON oi.order_id = o.order_id
INNER JOIN analytics.dim_customer dc
    ON o.customer_id = dc.customer_id
INNER JOIN analytics.dim_product dp
    ON oi.product_id = dp.product_id
INNER JOIN analytics.dim_seller ds
    ON oi.seller_id = ds.seller_id
INNER JOIN analytics.dim_order do_
    ON oi.order_id = do_.order_id
LEFT JOIN analytics.dim_payment dpay
    ON oi.order_id = dpay.order_id
LEFT JOIN analytics.dim_review drev
    ON oi.order_id = drev.order_id;

COMMIT;

-- Fact / dim sanity
SELECT 'fact_order_items' AS table_name, COUNT(*) AS n FROM analytics.fact_order_items
UNION ALL SELECT 'dim_date', COUNT(*) FROM analytics.dim_date
UNION ALL SELECT 'dim_customer', COUNT(*) FROM analytics.dim_customer
UNION ALL SELECT 'dim_product', COUNT(*) FROM analytics.dim_product
UNION ALL SELECT 'dim_seller', COUNT(*) FROM analytics.dim_seller
UNION ALL SELECT 'dim_order', COUNT(*) FROM analytics.dim_order
UNION ALL SELECT 'dim_payment', COUNT(*) FROM analytics.dim_payment
UNION ALL SELECT 'dim_review', COUNT(*) FROM analytics.dim_review;
