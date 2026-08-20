/*
==============================================================================
  Data Validation — E-Commerce Relational Layer
------------------------------------------------------------------------------
  Run after data_cleaning/01_clean_and_load_analytical.sql
  Each check is annotated with expected outcome for interview discussion.
==============================================================================
*/

-- 1. Primary key uniqueness
SELECT 'dup_customers' AS check_name, COUNT(*) AS failures
FROM (
    SELECT customer_id FROM ecommerce.customers GROUP BY 1 HAVING COUNT(*) > 1
) t
UNION ALL
SELECT 'dup_orders', COUNT(*) FROM (
    SELECT order_id FROM ecommerce.orders GROUP BY 1 HAVING COUNT(*) > 1
) t
UNION ALL
SELECT 'dup_order_items', COUNT(*) FROM (
    SELECT order_id, order_item_id FROM ecommerce.order_items GROUP BY 1, 2 HAVING COUNT(*) > 1
) t;

-- 2. Orphan foreign keys (should be 0 after cleaning joins)
SELECT 'orphan_orders_customer' AS check_name, COUNT(*) AS failures
FROM ecommerce.orders o
LEFT JOIN ecommerce.customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 'orphan_items_order', COUNT(*)
FROM ecommerce.order_items oi
LEFT JOIN ecommerce.orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'orphan_items_product', COUNT(*)
FROM ecommerce.order_items oi
LEFT JOIN ecommerce.products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'orphan_items_seller', COUNT(*)
FROM ecommerce.order_items oi
LEFT JOIN ecommerce.sellers s ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- 3. NULL critical fields
SELECT
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_pk,
    SUM(CASE WHEN customer_unique_id IS NULL THEN 1 ELSE 0 END) AS null_unique_id
FROM ecommerce.customers;

SELECT
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_pk,
    SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END) AS null_purchase_ts
FROM ecommerce.orders;

-- 4. Impossible timestamp sequences
SELECT COUNT(*) AS approval_before_purchase
FROM ecommerce.orders
WHERE order_approved_at < order_purchase_timestamp;

SELECT COUNT(*) AS delivered_before_carrier
FROM ecommerce.orders
WHERE order_delivered_customer_date < order_delivered_carrier_date;

-- 5. Status vs delivery consistency
SELECT COUNT(*) AS delivered_missing_date
FROM ecommerce.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

SELECT COUNT(*) AS canceled_but_delivered
FROM ecommerce.orders
WHERE order_status = 'canceled'
  AND order_delivered_customer_date IS NOT NULL;

-- 6. Price / freight sanity
SELECT COUNT(*) AS non_positive_price
FROM ecommerce.order_items
WHERE price <= 0;

SELECT COUNT(*) AS freight_gt_price
FROM ecommerce.order_items
WHERE freight_value > price;
-- Note: freight > price occurs in Olist (~4k rows) — logistics reality, not always an error

-- 7. Review score domain
SELECT COUNT(*) AS invalid_review_scores
FROM ecommerce.order_reviews
WHERE review_score NOT BETWEEN 1 AND 5;

-- 8. Categories without English translation (soft issue)
SELECT COUNT(DISTINCT p.product_category_name) AS untranslated_categories
FROM ecommerce.products p
LEFT JOIN ecommerce.category_translation t
    ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL;

-- 9. Volume sanity (approximate expected magnitudes for Olist)
SELECT
    (SELECT COUNT(*) FROM ecommerce.customers) AS customers,
    (SELECT COUNT(*) FROM ecommerce.orders) AS orders,
    (SELECT COUNT(*) FROM ecommerce.order_items) AS order_items,
    (SELECT COUNT(*) FROM ecommerce.sellers) AS sellers,
    (SELECT COUNT(*) FROM ecommerce.products) AS products;
-- Expected approx: ~99k customers, ~99k orders, ~112k items, ~3k sellers, ~33k products
