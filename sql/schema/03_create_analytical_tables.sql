/*
==============================================================================
  Analytical Relational Tables — Cleaned E-Commerce + Marketing Models
  Schemas: ecommerce, marketing
------------------------------------------------------------------------------
  Proper types, primary keys, and foreign keys.
  Load order matters: parents before children.
==============================================================================
*/

CREATE SCHEMA IF NOT EXISTS ecommerce;
CREATE SCHEMA IF NOT EXISTS marketing;

-- Drop children first to allow clean re-runs
DROP TABLE IF EXISTS marketing.closed_deals CASCADE;
DROP TABLE IF EXISTS marketing.qualified_leads CASCADE;
DROP TABLE IF EXISTS ecommerce.order_reviews CASCADE;
DROP TABLE IF EXISTS ecommerce.order_payments CASCADE;
DROP TABLE IF EXISTS ecommerce.order_items CASCADE;
DROP TABLE IF EXISTS ecommerce.orders CASCADE;
DROP TABLE IF EXISTS ecommerce.products CASCADE;
DROP TABLE IF EXISTS ecommerce.sellers CASCADE;
DROP TABLE IF EXISTS ecommerce.customers CASCADE;
DROP TABLE IF EXISTS ecommerce.geolocation CASCADE;
DROP TABLE IF EXISTS ecommerce.category_translation CASCADE;

-- ---------------------------------------------------------------------------
-- Dimension-like reference tables
-- ---------------------------------------------------------------------------

CREATE TABLE ecommerce.customers (
    customer_id              VARCHAR(50)  PRIMARY KEY,
    customer_unique_id       VARCHAR(50)  NOT NULL,
    customer_zip_code_prefix INTEGER,
    customer_city            VARCHAR(100),
    customer_state           CHAR(2)
);

CREATE TABLE ecommerce.sellers (
    seller_id              VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix INTEGER,
    seller_city            VARCHAR(100),
    seller_state           CHAR(2)
);

CREATE TABLE ecommerce.category_translation (
    product_category_name         VARCHAR(100) PRIMARY KEY,
    product_category_name_english VARCHAR(100) NOT NULL
);

CREATE TABLE ecommerce.products (
    product_id                   VARCHAR(50) PRIMARY KEY,
    product_category_name        VARCHAR(100),
    product_name_length          INTEGER,
    product_description_length   INTEGER,
    product_photos_qty           INTEGER,
    product_weight_g             INTEGER,
    product_length_cm            INTEGER,
    product_height_cm            INTEGER,
    product_width_cm             INTEGER
    -- Category is a soft lookup: some source categories lack English translations
);

-- Geolocation is multi-row per ZIP (sample points); no unique PK on ZIP alone
CREATE TABLE ecommerce.geolocation (
    geolocation_id              BIGSERIAL PRIMARY KEY,
    geolocation_zip_code_prefix INTEGER NOT NULL,
    geolocation_lat             NUMERIC(10, 6),
    geolocation_lng             NUMERIC(10, 6),
    geolocation_city            VARCHAR(100),
    geolocation_state           CHAR(2)
);

CREATE INDEX idx_geo_zip ON ecommerce.geolocation (geolocation_zip_code_prefix);

-- ---------------------------------------------------------------------------
-- Transactional core
-- ---------------------------------------------------------------------------

CREATE TABLE ecommerce.orders (
    order_id                      VARCHAR(50) PRIMARY KEY,
    customer_id                   VARCHAR(50) NOT NULL,
    order_status                  VARCHAR(30) NOT NULL,
    order_purchase_timestamp      TIMESTAMP NOT NULL,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES ecommerce.customers (customer_id)
);

CREATE INDEX idx_orders_customer ON ecommerce.orders (customer_id);
CREATE INDEX idx_orders_purchase ON ecommerce.orders (order_purchase_timestamp);
CREATE INDEX idx_orders_status   ON ecommerce.orders (order_status);

CREATE TABLE ecommerce.order_items (
    order_id            VARCHAR(50) NOT NULL,
    order_item_id       INTEGER     NOT NULL,
    product_id          VARCHAR(50) NOT NULL,
    seller_id           VARCHAR(50) NOT NULL,
    shipping_limit_date TIMESTAMP,
    price               NUMERIC(12, 2) NOT NULL CHECK (price >= 0),
    freight_value       NUMERIC(12, 2) NOT NULL CHECK (freight_value >= 0),
    PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT fk_items_order
        FOREIGN KEY (order_id) REFERENCES ecommerce.orders (order_id),
    CONSTRAINT fk_items_product
        FOREIGN KEY (product_id) REFERENCES ecommerce.products (product_id),
    CONSTRAINT fk_items_seller
        FOREIGN KEY (seller_id) REFERENCES ecommerce.sellers (seller_id)
);

CREATE INDEX idx_items_product ON ecommerce.order_items (product_id);
CREATE INDEX idx_items_seller  ON ecommerce.order_items (seller_id);

CREATE TABLE ecommerce.order_payments (
    order_id             VARCHAR(50) NOT NULL,
    payment_sequential   INTEGER     NOT NULL,
    payment_type         VARCHAR(30) NOT NULL,
    payment_installments INTEGER     CHECK (payment_installments >= 0),
    payment_value        NUMERIC(12, 2) NOT NULL CHECK (payment_value >= 0),
    PRIMARY KEY (order_id, payment_sequential),
    CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id) REFERENCES ecommerce.orders (order_id)
);

CREATE TABLE ecommerce.order_reviews (
    review_id               VARCHAR(50) PRIMARY KEY,
    order_id                VARCHAR(50) NOT NULL,
    review_score            SMALLINT NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title    VARCHAR(255),
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP,
    CONSTRAINT fk_reviews_order
        FOREIGN KEY (order_id) REFERENCES ecommerce.orders (order_id)
);

CREATE INDEX idx_reviews_order ON ecommerce.order_reviews (order_id);
CREATE INDEX idx_reviews_score ON ecommerce.order_reviews (review_score);

-- ---------------------------------------------------------------------------
-- Marketing funnel (event-based; intentionally not star-modeled)
-- ---------------------------------------------------------------------------

CREATE TABLE marketing.qualified_leads (
    mql_id             VARCHAR(50) PRIMARY KEY,
    first_contact_date DATE NOT NULL,
    landing_page_id    VARCHAR(50),
    origin             VARCHAR(50)
);

CREATE TABLE marketing.closed_deals (
    mql_id                        VARCHAR(50) PRIMARY KEY,
    seller_id                     VARCHAR(50),
    sdr_id                        VARCHAR(50),
    sr_id                         VARCHAR(50),
    won_date                      DATE NOT NULL,
    business_segment              VARCHAR(100),
    lead_type                     VARCHAR(50),
    lead_behaviour_profile        VARCHAR(50),
    has_company                   BOOLEAN,
    has_gtin                      BOOLEAN,
    average_stock                 VARCHAR(50),
    business_type                 VARCHAR(50),
    declared_product_catalog_size NUMERIC(12, 2),
    declared_monthly_revenue      NUMERIC(14, 2),
    CONSTRAINT fk_closed_mql
        FOREIGN KEY (mql_id) REFERENCES marketing.qualified_leads (mql_id)
    -- seller_id is intentionally not hard-FK'd: many closed deals never
    -- appear in the marketplace sellers extract (expected CRM/marketplace lag)
);

CREATE INDEX idx_mql_origin ON marketing.qualified_leads (origin);
CREATE INDEX idx_closed_won ON marketing.closed_deals (won_date);

COMMENT ON TABLE ecommerce.order_items IS 'Grain: one product line within an order';
COMMENT ON TABLE marketing.qualified_leads IS 'Top of seller-acquisition funnel (MQLs)';
COMMENT ON TABLE marketing.closed_deals IS 'Bottom of funnel — converted sellers';
