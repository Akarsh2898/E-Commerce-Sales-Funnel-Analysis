/*
==============================================================================
  Client-side CSV load into staging (recommended on Windows)
------------------------------------------------------------------------------
  Edit the paths below to your machine, then:

    psql -U postgres -d olist_analytics -f sql/load/01b_psql_client_copy.sql

  Note: If Kaggle named the closed-deals file olist_closed_deals_dataset.csv,
  rename it to olist_marketing_closed_deals_dataset.csv (see data/README.md).
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

-- >>> EDIT THESE PATHS <<<
\copy staging.customers from 'C:/Users/ayush/Desktop/Olist-end-to-end-data-analytics-main/data/raw/olist_customers_dataset.csv' csv header
\copy staging.orders from 'C:/Users/ayush/Desktop/Olist-end-to-end-data-analytics-main/data/raw/olist_orders_dataset.csv' csv header
\copy staging.order_items from 'C:/Users/ayush/Desktop/Olist-end-to-end-data-analytics-main/data/raw/olist_order_items_dataset.csv' csv header
\copy staging.products from 'C:/Users/ayush/Desktop/Olist-end-to-end-data-analytics-main/data/raw/olist_products_dataset.csv' csv header
\copy staging.sellers from 'C:/Users/ayush/Desktop/Olist-end-to-end-data-analytics-main/data/raw/olist_sellers_dataset.csv' csv header
\copy staging.order_payments from 'C:/Users/ayush/Desktop/Olist-end-to-end-data-analytics-main/data/raw/olist_order_payments_dataset.csv' csv header
\copy staging.order_reviews from 'C:/Users/ayush/Desktop/Olist-end-to-end-data-analytics-main/data/raw/olist_order_reviews_dataset.csv' csv header
\copy staging.geolocation from 'C:/Users/ayush/Desktop/Olist-end-to-end-data-analytics-main/data/raw/olist_geolocation_dataset.csv' csv header
\copy staging.category_translation from 'C:/Users/ayush/Desktop/Olist-end-to-end-data-analytics-main/data/raw/product_category_name_translation.csv' csv header
\copy staging.marketing_qualified_leads from 'C:/Users/ayush/Desktop/Olist-end-to-end-data-analytics-main/data/raw/olist_marketing_qualified_leads_dataset.csv' csv header
\copy staging.marketing_closed_deals from 'C:/Users/ayush/Desktop/Olist-end-to-end-data-analytics-main/data/raw/olist_marketing_closed_deals_dataset.csv' csv header

SELECT 'customers' AS t, COUNT(*) n FROM staging.customers
UNION ALL SELECT 'orders', COUNT(*) FROM staging.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM staging.order_items
UNION ALL SELECT 'mqls', COUNT(*) FROM staging.marketing_qualified_leads
UNION ALL SELECT 'closed_deals', COUNT(*) FROM staging.marketing_closed_deals;
