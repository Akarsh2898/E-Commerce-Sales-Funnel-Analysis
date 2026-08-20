/*
==============================================================================
  Physical Star Schema — Analytics Layer
  Schema: analytics
------------------------------------------------------------------------------
  Fact grain: 1 row = 1 order item (product line sold)
  Dimensions: date, customer, product, seller, order, payment summary, review

  This is a *physical* implementation (not just a diagram) so Power BI and
  SQL analysis can query denormalized, BI-friendly tables.
==============================================================================
*/

CREATE SCHEMA IF NOT EXISTS analytics;

DROP TABLE IF EXISTS analytics.fact_order_items CASCADE;
DROP TABLE IF EXISTS analytics.dim_date CASCADE;
DROP TABLE IF EXISTS analytics.dim_customer CASCADE;
DROP TABLE IF EXISTS analytics.dim_product CASCADE;
DROP TABLE IF EXISTS analytics.dim_seller CASCADE;
DROP TABLE IF EXISTS analytics.dim_order CASCADE;
DROP TABLE IF EXISTS analytics.dim_payment CASCADE;
DROP TABLE IF EXISTS analytics.dim_review CASCADE;

-- ---------------------------------------------------------------------------
-- Dimensions
-- ---------------------------------------------------------------------------

CREATE TABLE analytics.dim_date (
    date_key      INTEGER PRIMARY KEY,          -- YYYYMMDD
    full_date     DATE NOT NULL UNIQUE,
    day_of_week   SMALLINT NOT NULL,            -- 1=Mon … 7=Sun (ISO)
    day_name      VARCHAR(10) NOT NULL,
    day_of_month  SMALLINT NOT NULL,
    week_of_year  SMALLINT NOT NULL,
    month_number  SMALLINT NOT NULL,
    month_name    VARCHAR(10) NOT NULL,
    quarter       SMALLINT NOT NULL,
    year_number   INTEGER NOT NULL,
    is_weekend    BOOLEAN NOT NULL
);

CREATE TABLE analytics.dim_customer (
    customer_sk          SERIAL PRIMARY KEY,
    customer_id          VARCHAR(50) NOT NULL UNIQUE,
    customer_unique_id   VARCHAR(50) NOT NULL,
    customer_city        VARCHAR(100),
    customer_state       CHAR(2),
    customer_zip_prefix  INTEGER
);

CREATE TABLE analytics.dim_product (
    product_sk                    SERIAL PRIMARY KEY,
    product_id                    VARCHAR(50) NOT NULL UNIQUE,
    product_category_name         VARCHAR(100),
    product_category_name_english VARCHAR(100),
    product_weight_g              INTEGER,
    product_photos_qty            INTEGER
);

CREATE TABLE analytics.dim_seller (
    seller_sk         SERIAL PRIMARY KEY,
    seller_id         VARCHAR(50) NOT NULL UNIQUE,
    seller_city       VARCHAR(100),
    seller_state      CHAR(2),
    seller_zip_prefix INTEGER
);

CREATE TABLE analytics.dim_order (
    order_sk                      SERIAL PRIMARY KEY,
    order_id                      VARCHAR(50) NOT NULL UNIQUE,
    order_status                  VARCHAR(30) NOT NULL,
    order_purchase_timestamp      TIMESTAMP NOT NULL,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    delivery_days                 INTEGER,   -- purchase -> delivered
    estimated_delivery_days       INTEGER,
    is_late_delivery              BOOLEAN,
    delay_days                    INTEGER    -- positive = late
);

-- One row per order: aggregated payment attributes (avoids fan-out)
CREATE TABLE analytics.dim_payment (
    payment_sk             SERIAL PRIMARY KEY,
    order_id               VARCHAR(50) NOT NULL UNIQUE,
    primary_payment_type   VARCHAR(30),
    payment_count          INTEGER,
    total_payment_value    NUMERIC(14, 2),
    max_installments       INTEGER
);

-- One review row per order (latest review if duplicates exist)
CREATE TABLE analytics.dim_review (
    review_sk               SERIAL PRIMARY KEY,
    order_id                VARCHAR(50) NOT NULL UNIQUE,
    review_id               VARCHAR(50),
    review_score            SMALLINT,
    review_creation_date    TIMESTAMP,
    has_comment             BOOLEAN
);

-- ---------------------------------------------------------------------------
-- Fact table
-- ---------------------------------------------------------------------------

CREATE TABLE analytics.fact_order_items (
    fact_sk              BIGSERIAL PRIMARY KEY,
    order_id             VARCHAR(50) NOT NULL,
    order_item_id        INTEGER     NOT NULL,
    date_key             INTEGER     NOT NULL,
    customer_sk          INTEGER     NOT NULL,
    product_sk           INTEGER     NOT NULL,
    seller_sk            INTEGER     NOT NULL,
    order_sk             INTEGER     NOT NULL,
    payment_sk           INTEGER,
    review_sk            INTEGER,
    price                NUMERIC(12, 2) NOT NULL,
    freight_value        NUMERIC(12, 2) NOT NULL,
    -- Derived measures (stored for BI convenience)
    item_revenue         NUMERIC(12, 2) NOT NULL,  -- price
    item_contribution    NUMERIC(12, 2) NOT NULL,  -- price - freight (proxy margin)
    shipping_limit_date  TIMESTAMP,
    CONSTRAINT uq_fact_item UNIQUE (order_id, order_item_id),
    CONSTRAINT fk_fact_date     FOREIGN KEY (date_key)    REFERENCES analytics.dim_date (date_key),
    CONSTRAINT fk_fact_customer FOREIGN KEY (customer_sk) REFERENCES analytics.dim_customer (customer_sk),
    CONSTRAINT fk_fact_product  FOREIGN KEY (product_sk)  REFERENCES analytics.dim_product (product_sk),
    CONSTRAINT fk_fact_seller   FOREIGN KEY (seller_sk)   REFERENCES analytics.dim_seller (seller_sk),
    CONSTRAINT fk_fact_order    FOREIGN KEY (order_sk)    REFERENCES analytics.dim_order (order_sk),
    CONSTRAINT fk_fact_payment  FOREIGN KEY (payment_sk)  REFERENCES analytics.dim_payment (payment_sk),
    CONSTRAINT fk_fact_review   FOREIGN KEY (review_sk)   REFERENCES analytics.dim_review (review_sk)
);

CREATE INDEX idx_fact_date_key    ON analytics.fact_order_items (date_key);
CREATE INDEX idx_fact_customer_sk ON analytics.fact_order_items (customer_sk);
CREATE INDEX idx_fact_product_sk  ON analytics.fact_order_items (product_sk);
CREATE INDEX idx_fact_seller_sk   ON analytics.fact_order_items (seller_sk);
CREATE INDEX idx_fact_order_id    ON analytics.fact_order_items (order_id);

COMMENT ON TABLE analytics.fact_order_items IS
    'Star-schema fact: one row per order item. Connects to date/customer/product/seller/order/payment/review dims.';

COMMENT ON COLUMN analytics.fact_order_items.item_contribution IS
    'Proxy profit = price - freight_value (Olist does not publish COGS)';
