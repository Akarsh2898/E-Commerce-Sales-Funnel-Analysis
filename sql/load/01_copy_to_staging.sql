/*
==============================================================================
  Server-side COPY (requires CSVs on the PostgreSQL server filesystem
  and a role with pg_read_server_files / superuser).
  Prefer 01b_psql_client_copy.sql for local Windows setups.
==============================================================================
*/

TRUNCATE staging.customers,
         staging.orders,
         staging.order_items,
         staging.products,
         staging.sellers,
         staging.order_payments,
         staging.order_reviews,
         staging.geolocation,
         staging.category_translation,
         staging.marketing_qualified_leads,
         staging.marketing_closed_deals;

-- Replace DATA_DIR with the absolute server path to data/raw
COPY staging.customers FROM 'DATA_DIR/olist_customers_dataset.csv' CSV HEADER;
COPY staging.orders FROM 'DATA_DIR/olist_orders_dataset.csv' CSV HEADER;
COPY staging.order_items FROM 'DATA_DIR/olist_order_items_dataset.csv' CSV HEADER;
COPY staging.products FROM 'DATA_DIR/olist_products_dataset.csv' CSV HEADER;
COPY staging.sellers FROM 'DATA_DIR/olist_sellers_dataset.csv' CSV HEADER;
COPY staging.order_payments FROM 'DATA_DIR/olist_order_payments_dataset.csv' CSV HEADER;
COPY staging.order_reviews FROM 'DATA_DIR/olist_order_reviews_dataset.csv' CSV HEADER;
COPY staging.geolocation FROM 'DATA_DIR/olist_geolocation_dataset.csv' CSV HEADER;
COPY staging.category_translation FROM 'DATA_DIR/product_category_name_translation.csv' CSV HEADER;
COPY staging.marketing_qualified_leads FROM 'DATA_DIR/olist_marketing_qualified_leads_dataset.csv' CSV HEADER;
COPY staging.marketing_closed_deals FROM 'DATA_DIR/olist_marketing_closed_deals_dataset.csv' CSV HEADER;
