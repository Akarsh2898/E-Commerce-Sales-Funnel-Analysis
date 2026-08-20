/*
==============================================================================
  Staging Tables — Raw Landing Zone
  Schema: staging
------------------------------------------------------------------------------
  All columns are TEXT to absorb messy CSV types safely.
  Transformations happen later in data_cleaning scripts.
==============================================================================
*/

CREATE SCHEMA IF NOT EXISTS staging;

-- ---------------------------------------------------------------------------
-- E-commerce raw tables
-- ---------------------------------------------------------------------------

DROP TABLE IF EXISTS staging.customers CASCADE;
CREATE TABLE staging.customers (
    customer_id              TEXT,
    customer_unique_id       TEXT,
    customer_zip_code_prefix TEXT,
    customer_city            TEXT,
    customer_state           TEXT
);

DROP TABLE IF EXISTS staging.orders CASCADE;
CREATE TABLE staging.orders (
    order_id                      TEXT,
    customer_id                   TEXT,
    order_status                  TEXT,
    order_purchase_timestamp      TEXT,
    order_approved_at             TEXT,
    order_delivered_carrier_date  TEXT,
    order_delivered_customer_date TEXT,
    order_estimated_delivery_date TEXT
);

DROP TABLE IF EXISTS staging.order_items CASCADE;
CREATE TABLE staging.order_items (
    order_id            TEXT,
    order_item_id       TEXT,
    product_id          TEXT,
    seller_id           TEXT,
    shipping_limit_date TEXT,
    price               TEXT,
    freight_value       TEXT
);

DROP TABLE IF EXISTS staging.products CASCADE;
CREATE TABLE staging.products (
    product_id                 TEXT,
    product_category_name      TEXT,
    product_name_lenght        TEXT,  -- source column spelling (typo in Kaggle file)
    product_description_lenght TEXT,  -- source column spelling (typo in Kaggle file)
    product_photos_qty         TEXT,
    product_weight_g           TEXT,
    product_length_cm          TEXT,
    product_height_cm          TEXT,
    product_width_cm           TEXT
);

DROP TABLE IF EXISTS staging.sellers CASCADE;
CREATE TABLE staging.sellers (
    seller_id              TEXT,
    seller_zip_code_prefix TEXT,
    seller_city            TEXT,
    seller_state           TEXT
);

DROP TABLE IF EXISTS staging.order_payments CASCADE;
CREATE TABLE staging.order_payments (
    order_id             TEXT,
    payment_sequential   TEXT,
    payment_type         TEXT,
    payment_installments TEXT,
    payment_value        TEXT
);

DROP TABLE IF EXISTS staging.order_reviews CASCADE;
CREATE TABLE staging.order_reviews (
    review_id               TEXT,
    order_id                TEXT,
    review_score            TEXT,
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TEXT,
    review_answer_timestamp TEXT
);

DROP TABLE IF EXISTS staging.geolocation CASCADE;
CREATE TABLE staging.geolocation (
    geolocation_zip_code_prefix TEXT,
    geolocation_lat             TEXT,
    geolocation_lng             TEXT,
    geolocation_city            TEXT,
    geolocation_state           TEXT
);

DROP TABLE IF EXISTS staging.category_translation CASCADE;
CREATE TABLE staging.category_translation (
    product_category_name         TEXT,
    product_category_name_english TEXT
);

-- ---------------------------------------------------------------------------
-- Marketing funnel raw tables
-- ---------------------------------------------------------------------------

DROP TABLE IF EXISTS staging.marketing_qualified_leads CASCADE;
CREATE TABLE staging.marketing_qualified_leads (
    mql_id             TEXT,
    first_contact_date TEXT,
    landing_page_id    TEXT,
    origin             TEXT
);

DROP TABLE IF EXISTS staging.marketing_closed_deals CASCADE;
CREATE TABLE staging.marketing_closed_deals (
    mql_id                         TEXT,
    seller_id                      TEXT,
    sdr_id                         TEXT,
    sr_id                          TEXT,
    won_date                       TEXT,
    business_segment               TEXT,
    lead_type                      TEXT,
    lead_behaviour_profile         TEXT,
    has_company                    TEXT,
    has_gtin                       TEXT,
    average_stock                  TEXT,
    business_type                  TEXT,
    declared_product_catalog_size  TEXT,
    declared_monthly_revenue       TEXT
);

COMMENT ON TABLE staging.customers IS 'Raw olist_customers_dataset.csv';
COMMENT ON TABLE staging.orders    IS 'Raw olist_orders_dataset.csv';
