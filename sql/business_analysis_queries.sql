-- Olist E-Commerce: Business Analysis Queries
-- Business Problem: Understand drivers of delivery performance and
-- customer satisfaction, and identify where Olist should focus improvement.


USE olist_ecommerce;

-- SECTION 1: SALES & REVENUE

-- 1.1 Monthly revenue trend
-- Business Q: How has revenue evolved over time?
SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY order_month
ORDER BY order_month;


-- 1.2 Top 10 product categories by revenue
-- Which categories generate the most revenue?
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name) AS category,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    COUNT(DISTINCT oi.order_id) AS total_orders
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY category
ORDER BY total_revenue DESC
LIMIT 10;


-- 1.3 Revenue by customer state (geographic concentration)
-- Business Q: Which states contribute most to revenue?
SELECT
    c.customer_state,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_state
ORDER BY total_revenue DESC;


-- 1.4 Average Order Value by payment type
-- Does payment method affect order value?
SELECT
    pay.payment_type,
    ROUND(AVG(pay.payment_value), 2) AS avg_order_value,
    COUNT(DISTINCT pay.order_id) AS total_orders
FROM order_payments pay
GROUP BY pay.payment_type
ORDER BY avg_order_value DESC;


-- ================================================================
-- SECTION 2: DELIVERY & LOGISTICS PERFORMANCE
-- ================================================================

-- 2.1 On-time vs Late vs Early delivery %
-- What share of orders are delivered late?
SELECT
    CASE
        WHEN order_delivered_customer_date IS NULL THEN 'Not Delivered'
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'Late'
        WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 'On-time / Early'
    END AS delivery_status,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders), 2) AS pct_of_total
FROM orders
GROUP BY delivery_status;


-- 2.2 Average delivery delay by state
-- Which states have the worst delivery performance?
-- (positive value = late by X days, negative = early)
SELECT
    c.customer_state,
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date)), 2) AS avg_delay_days,
    COUNT(*) AS total_delivered_orders
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_delay_days DESC;


-- 2.3 Average delivery delay by product category
-- Are certain product categories consistently delayed?
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name) AS category,
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date)), 2) AS avg_delay_days,
    COUNT(*) AS total_orders
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY category
ORDER BY avg_delay_days DESC
LIMIT 15;


-- 2.4 Top 10 sellers with the worst average delivery delay (min 20 orders, to avoid noise)
-- Which sellers need logistics/process intervention?
SELECT
    oi.seller_id,
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date)), 2) AS avg_delay_days,
    COUNT(*) AS total_orders
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY oi.seller_id
HAVING COUNT(*) >= 20
ORDER BY avg_delay_days DESC
LIMIT 10;


-- ================================================================
-- SECTION 3: CUSTOMER SATISFACTION (REVIEWS)
-- ================================================================

-- 3.1 Overall review score distribution
-- How are review scores distributed?
SELECT
    review_score,
    COUNT(*) AS total_reviews,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM order_reviews), 2) AS pct_of_total
FROM order_reviews
GROUP BY review_score
ORDER BY review_score DESC;


-- 3.2 Average review score trend over time
-- Is customer satisfaction improving or declining?
SELECT
    DATE_FORMAT(r.review_creation_date, '%Y-%m') AS review_month,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    COUNT(*) AS total_reviews
FROM order_reviews r
GROUP BY review_month
ORDER BY review_month;


-- 3.3 *** KEY QUERY *** Delivery delay vs review score (core hypothesis test)
-- Business Q: Do delayed orders get worse reviews? (this directly tests the business hypothesis)
SELECT
    CASE
        WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) <= 0 THEN 'On-time / Early'
        WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) BETWEEN 1 AND 7 THEN 'Late (1-7 days)'
        ELSE 'Very Late (8+ days)'
    END AS delivery_bucket,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    COUNT(*) AS total_orders
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY delivery_bucket
ORDER BY avg_review_score;


-- 3.4 Categories with highest share of 1-2 star (negative) reviews
-- Business Q: Which categories are hurting customer satisfaction most?
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name) AS category,
    COUNT(*) AS total_reviews,
    SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) AS negative_reviews,
    ROUND(SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS pct_negative
FROM order_reviews r
JOIN orders o ON r.order_id = o.order_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
GROUP BY category
HAVING total_reviews >= 30
ORDER BY pct_negative DESC
LIMIT 10;


-- ================================================================
-- SECTION 4: CUSTOMER BEHAVIOR
-- ================================================================

-- 4.1 Repeat vs One-time customers
-- Business Q: What % of customers come back to buy again?
SELECT
    CASE WHEN order_count = 1 THEN 'One-time Customer' ELSE 'Repeat Customer' END AS customer_type,
    COUNT(*) AS num_customers,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(DISTINCT customer_unique_id) FROM customers), 2) AS pct_of_total
FROM (
    SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS order_count
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
) AS customer_orders
GROUP BY customer_type;


-- 4.2 Top 10 customers by number of orders
-- Business Q: Who are the most valuable repeat customers?
SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_unique_id
ORDER BY total_orders DESC
LIMIT 10;
