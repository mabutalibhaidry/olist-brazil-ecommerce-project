USE olist_ecommerce;

SELECT * FROM olist_ecommerce.customers;

SELECT * FROM olist_ecommerce.geolocation;

SELECT * FROM olist_ecommerce.order_items;

SELECT * FROM olist_ecommerce.order_payments;

SELECT * FROM olist_ecommerce.orders;

SELECT * FROM olist_ecommerce.product_category_name_translation;

SELECT * FROM olist_ecommerce.products;

SELECT * FROM olist_ecommerce.order_reviews;

SELECT * FROM olist_ecommerce.sellers;


-- 1. ROW COUNTS per table

SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'product_category_name_translation', COUNT(*) FROM product_category_name_translation
UNION ALL
SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews;


-- 2. NULL CHECKS in key columns

SELECT
    SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END) AS null_orders_approved_at,
    SUM(CASE WHEN order_delivered_carrier_date IS NULL THEN 1 ELSE 0 END) AS null_orders_carrier_date,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS null_orders_delivered_date
FROM orders;

SELECT
    SUM(CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END) AS null_row_product_category,
    SUM(CASE WHEN product_weight_g IS NULL THEN 1 ELSE 0 END) AS null_row_product_weight
FROM products;

SELECT
    SUM(CASE WHEN review_comment_message IS NULL THEN 1 ELSE 0 END) AS null_review_message,
    SUM(CASE WHEN review_score IS NULL THEN 1 ELSE 0 END) AS null_review_score
FROM order_reviews;


-- 3. DUPLICATE CHECKS

-- Duplicate customer_id in customers
SELECT customer_id, COUNT(*) AS cnt
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Duplicate rows in geolocation (same zip code can repeat)
SELECT geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, COUNT(*) AS cnt
FROM geolocation
GROUP BY geolocation_zip_code_prefix, geolocation_lat, geolocation_lng
HAVING COUNT(*) > 1;

-- Orders with more than 1 payment row
SELECT order_id, COUNT(*) AS payment_rows
FROM order_payments
GROUP BY order_id
HAVING COUNT(*) > 1
LIMIT 10;


-- 4. ORDER STATUS BREAKDOWN

SELECT order_status, COUNT(*) AS cnt
FROM orders
GROUP BY order_status
ORDER BY cnt DESC;

