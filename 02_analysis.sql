-- =====================================================================
-- Olist E-commerce Analysis | Step 2: Business Questions (MySQL 8+)
-- Run 01_schema_and_import.sql first.
-- Scope: delivered orders only unless stated otherwise.
-- =====================================================================
USE olist_project;

-- ---------------------------------------------------------------------
-- Q1. How do monthly revenue and order volume evolve?
-- Revenue = payment_value (includes freight). Skills: JOIN, GROUP BY
-- ---------------------------------------------------------------------
SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
       ROUND(SUM(p.payment_value), 2) AS revenue,
       COUNT(DISTINCT o.order_id) AS orders
FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY month
ORDER BY month;

-- ---------------------------------------------------------------------
-- Q2. What is the month-over-month revenue growth?
-- 2016 is excluded: the data for that year is too sparse to compare.
-- Skills: CTE, LAG window function
-- ---------------------------------------------------------------------
WITH monthly AS (
  SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
         ROUND(SUM(p.payment_value), 2) AS revenue
  FROM orders o
  JOIN order_payments p ON o.order_id = p.order_id
  WHERE o.order_status = 'delivered'
  GROUP BY month
)
SELECT month, revenue,
       LAG(revenue) OVER (ORDER BY month) AS prev_revenue,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY month))
             / LAG(revenue) OVER (ORDER BY month) * 100, 1) AS growth_pct
FROM monthly
WHERE month >= '2017-01'
ORDER BY month;

-- ---------------------------------------------------------------------
-- Q3. Which product categories generate the most revenue?
-- Revenue here = item price only (excludes freight).
-- Skills: multi-table JOIN, LEFT JOIN, COALESCE
-- ---------------------------------------------------------------------
SELECT COALESCE(t.product_category_name_english, 'unknown') AS category,
       COUNT(DISTINCT oi.order_id) AS orders,
       ROUND(SUM(oi.price), 2) AS revenue,
       ROUND(AVG(oi.price), 2) AS avg_price
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN category_translation t
       ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY category
ORDER BY revenue DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- Q4. Does late delivery affect customer review scores?
-- Late = delivered after the estimated delivery date.
-- Skills: CASE, JOIN, AVG
-- ---------------------------------------------------------------------
SELECT
  CASE
    WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 'On time'
    ELSE 'Late'
  END AS delivery_status,
  COUNT(DISTINCT o.order_id) AS orders,
  ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY delivery_status;

-- ---------------------------------------------------------------------
-- Q5. Which states have the highest late-delivery rate?
-- States with fewer than 500 delivered orders are excluded (small samples).
-- Skills: conditional aggregation, HAVING
-- ---------------------------------------------------------------------
SELECT c.customer_state AS state,
       COUNT(*) AS delivered_orders,
       SUM(o.order_delivered_customer_date > o.order_estimated_delivery_date) AS late_orders,
       ROUND(100 * SUM(o.order_delivered_customer_date > o.order_estimated_delivery_date) / COUNT(*), 1) AS late_pct
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
HAVING COUNT(*) >= 500
ORDER BY late_pct DESC;

-- ---------------------------------------------------------------------
-- Q6. What share of customers buy more than once?
-- Uses customer_unique_id: customer_id changes with every order in Olist.
-- Skills: CTE, window function over aggregate
-- ---------------------------------------------------------------------
WITH cust AS (
  SELECT c.customer_unique_id,
         COUNT(DISTINCT o.order_id) AS orders_count
  FROM orders o
  JOIN customers c ON o.customer_id = c.customer_id
  WHERE o.order_status = 'delivered'
  GROUP BY c.customer_unique_id
)
SELECT CASE WHEN orders_count = 1 THEN 'One-time'
            ELSE 'Repeat' END AS customer_type,
       COUNT(*) AS customers,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM cust
GROUP BY customer_type;

-- ---------------------------------------------------------------------
-- Q7. Customer segmentation (RFM-style: Recency + Monetary)
-- Frequency is left out on purpose: ~97% of customers ordered only once,
-- so it would not separate customers.
-- Skills: multiple CTEs, NTILE, subquery, CASE
-- ---------------------------------------------------------------------
WITH cust AS (
  SELECT c.customer_unique_id,
         MAX(o.order_purchase_timestamp) AS last_purchase,
         SUM(p.payment_value) AS monetary
  FROM orders o
  JOIN customers c ON o.customer_id = c.customer_id
  JOIN order_payments p ON o.order_id = p.order_id
  WHERE o.order_status = 'delivered'
  GROUP BY c.customer_unique_id
),
scored AS (
  SELECT customer_unique_id, monetary,
         DATEDIFF((SELECT MAX(order_purchase_timestamp) FROM orders), last_purchase) AS recency_days,
         NTILE(4) OVER (ORDER BY last_purchase) AS r_score,
         NTILE(4) OVER (ORDER BY monetary) AS m_score
  FROM cust
)
SELECT CASE
         WHEN r_score = 4 AND m_score = 4 THEN 'Champions'
         WHEN r_score >= 3 AND m_score >= 3 THEN 'Loyal / High value'
         WHEN r_score = 4 THEN 'Recent'
         WHEN m_score = 4 THEN 'Big spenders (inactive)'
         WHEN r_score = 1 AND m_score = 1 THEN 'Lost'
         ELSE 'Others'
       END AS segment,
       COUNT(*) AS customers,
       ROUND(AVG(monetary), 2) AS avg_spent,
       ROUND(AVG(recency_days), 0) AS avg_recency_days
FROM scored
GROUP BY segment
ORDER BY customers DESC;
