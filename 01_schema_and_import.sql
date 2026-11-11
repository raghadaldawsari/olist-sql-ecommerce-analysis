-- =====================================================================
-- Olist E-commerce Analysis | Step 1: Schema + Data Import (MySQL 8+)
-- Dataset: Brazilian E-Commerce Public Dataset by Olist (Kaggle)
-- =====================================================================
-- Before running:
--   1) Download the 9 CSV files from Kaggle and note the folder path.
--   2) Replace /path/to/archive/ below with your own folder path.
--   3) Enable local infile:
--        - Server:  SET GLOBAL local_infile = 1;
--        - Workbench connection > Advanced > Others: OPT_LOCAL_INFILE=1
--      (then reconnect)
-- Tip: run each LOAD DATA statement on its own and check the row count.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS olist_project;
USE olist_project;

-- ---------------------------------------------------------------------
-- 1. Schema (drop + create, safe to re-run)
-- ---------------------------------------------------------------------
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS order_items, order_payments, order_reviews, orders,
  customers, sellers, products, category_translation, geolocation;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE customers (
  customer_id VARCHAR(50) PRIMARY KEY,
  customer_unique_id VARCHAR(50),
  customer_zip_code_prefix VARCHAR(10),
  customer_city VARCHAR(100),
  customer_state CHAR(2)
);

CREATE TABLE sellers (
  seller_id VARCHAR(50) PRIMARY KEY,
  seller_zip_code_prefix VARCHAR(10),
  seller_city VARCHAR(100),
  seller_state CHAR(2)
);

CREATE TABLE products (
  product_id VARCHAR(50) PRIMARY KEY,
  product_category_name VARCHAR(100),
  product_name_length INT,
  product_description_length INT,
  product_photos_qty INT,
  product_weight_g INT,
  product_length_cm INT,
  product_height_cm INT,
  product_width_cm INT
);

CREATE TABLE category_translation (
  product_category_name VARCHAR(100) PRIMARY KEY,
  product_category_name_english VARCHAR(100)
);

CREATE TABLE orders (
  order_id VARCHAR(50) PRIMARY KEY,
  customer_id VARCHAR(50),
  order_status VARCHAR(20),
  order_purchase_timestamp DATETIME,
  order_approved_at DATETIME,
  order_delivered_carrier_date DATETIME,
  order_delivered_customer_date DATETIME,
  order_estimated_delivery_date DATETIME,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
  order_id VARCHAR(50),
  order_item_id INT,
  product_id VARCHAR(50),
  seller_id VARCHAR(50),
  shipping_limit_date DATETIME,
  price DECIMAL(10,2),
  freight_value DECIMAL(10,2),
  PRIMARY KEY (order_id, order_item_id),
  FOREIGN KEY (order_id) REFERENCES orders(order_id),
  FOREIGN KEY (product_id) REFERENCES products(product_id),
  FOREIGN KEY (seller_id) REFERENCES sellers(seller_id)
);

CREATE TABLE order_payments (
  order_id VARCHAR(50),
  payment_sequential INT,
  payment_type VARCHAR(30),
  payment_installments INT,
  payment_value DECIMAL(10,2),
  PRIMARY KEY (order_id, payment_sequential),
  FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- No PK: review_id is not unique in the source data
CREATE TABLE order_reviews (
  review_id VARCHAR(50),
  order_id VARCHAR(50),
  review_score INT,
  review_comment_title TEXT,
  review_comment_message TEXT,
  review_creation_date DATETIME,
  review_answer_timestamp DATETIME,
  KEY idx_order (order_id)
);

-- No PK: many rows share the same zip prefix
CREATE TABLE geolocation (
  geolocation_zip_code_prefix VARCHAR(10),
  geolocation_lat DECIMAL(18,15),
  geolocation_lng DECIMAL(18,15),
  geolocation_city VARCHAR(100),
  geolocation_state CHAR(2),
  KEY idx_zip (geolocation_zip_code_prefix)
);

-- ---------------------------------------------------------------------
-- 2. Import (order matters because of foreign keys)
--    Empty strings are converted to NULL with NULLIF; '\r' is stripped
--    from the last column to handle Windows line endings.
-- ---------------------------------------------------------------------

-- category_translation (expected: 71)
LOAD DATA LOCAL INFILE '/path/to/archive/product_category_name_translation.csv'
INTO TABLE category_translation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@c1, @c2)
SET product_category_name = TRIM(REPLACE(@c1, '\r', '')),
    product_category_name_english = TRIM(REPLACE(@c2, '\r', ''));
SELECT COUNT(*) FROM category_translation;

-- customers (expected: 99441)
LOAD DATA LOCAL INFILE '/path/to/archive/olist_customers_dataset.csv'
INTO TABLE customers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@a,@b,@c,@d,@e)
SET customer_id=TRIM(REPLACE(@a,'\r','')), customer_unique_id=TRIM(@b),
    customer_zip_code_prefix=TRIM(@c), customer_city=TRIM(@d),
    customer_state=TRIM(REPLACE(@e,'\r',''));
SELECT COUNT(*) FROM customers;

-- sellers (expected: 3095)
LOAD DATA LOCAL INFILE '/path/to/archive/olist_sellers_dataset.csv'
INTO TABLE sellers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@a,@b,@c,@d)
SET seller_id=TRIM(REPLACE(@a,'\r','')), seller_zip_code_prefix=TRIM(@b),
    seller_city=TRIM(@c), seller_state=TRIM(REPLACE(@d,'\r',''));
SELECT COUNT(*) FROM sellers;

-- products (expected: 32951)
LOAD DATA LOCAL INFILE '/path/to/archive/olist_products_dataset.csv'
INTO TABLE products
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@a,@b,@c,@d,@e,@f,@g,@h,@i)
SET product_id=TRIM(@a), product_category_name=NULLIF(TRIM(@b),''),
    product_name_length=NULLIF(TRIM(@c),''), product_description_length=NULLIF(TRIM(@d),''),
    product_photos_qty=NULLIF(TRIM(@e),''), product_weight_g=NULLIF(TRIM(@f),''),
    product_length_cm=NULLIF(TRIM(@g),''), product_height_cm=NULLIF(TRIM(@h),''),
    product_width_cm=NULLIF(TRIM(REPLACE(@i,'\r','')),'');
SELECT COUNT(*) FROM products;

-- orders (expected: 99441)
LOAD DATA LOCAL INFILE '/path/to/archive/olist_orders_dataset.csv'
INTO TABLE orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@a,@b,@c,@d,@e,@f,@g,@h)
SET order_id=TRIM(@a), customer_id=TRIM(@b), order_status=TRIM(@c),
    order_purchase_timestamp=NULLIF(TRIM(@d),''),
    order_approved_at=NULLIF(TRIM(@e),''),
    order_delivered_carrier_date=NULLIF(TRIM(@f),''),
    order_delivered_customer_date=NULLIF(TRIM(@g),''),
    order_estimated_delivery_date=NULLIF(TRIM(REPLACE(@h,'\r','')),'');
SELECT COUNT(*) FROM orders;

-- order_items (expected: 112650)
LOAD DATA LOCAL INFILE '/path/to/archive/olist_order_items_dataset.csv'
INTO TABLE order_items
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@a,@b,@c,@d,@e,@f,@g)
SET order_id=TRIM(@a), order_item_id=TRIM(@b), product_id=TRIM(@c), seller_id=TRIM(@d),
    shipping_limit_date=NULLIF(TRIM(@e),''), price=TRIM(@f),
    freight_value=TRIM(REPLACE(@g,'\r',''));
SELECT COUNT(*) FROM order_items;

-- order_payments (expected: 103886)
LOAD DATA LOCAL INFILE '/path/to/archive/olist_order_payments_dataset.csv'
INTO TABLE order_payments
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@a,@b,@c,@d,@e)
SET order_id=TRIM(@a), payment_sequential=TRIM(@b), payment_type=TRIM(@c),
    payment_installments=TRIM(@d), payment_value=TRIM(REPLACE(@e,'\r',''));
SELECT COUNT(*) FROM order_payments;

-- geolocation (expected: 1000163, slowest file)
LOAD DATA LOCAL INFILE '/path/to/archive/olist_geolocation_dataset.csv'
INTO TABLE geolocation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@a,@b,@c,@d,@e)
SET geolocation_zip_code_prefix=TRIM(@a), geolocation_lat=TRIM(@b),
    geolocation_lng=TRIM(@c), geolocation_city=TRIM(@d),
    geolocation_state=TRIM(REPLACE(@e,'\r',''));
SELECT COUNT(*) FROM geolocation;

-- order_reviews (expected: 99224; comments contain commas and line breaks)
LOAD DATA LOCAL INFILE '/path/to/archive/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@a,@b,@c,@d,@e,@f,@g)
SET review_id=TRIM(@a), order_id=TRIM(@b), review_score=TRIM(@c),
    review_comment_title=NULLIF(TRIM(@d),''), review_comment_message=NULLIF(TRIM(@e),''),
    review_creation_date=NULLIF(TRIM(@f),''),
    review_answer_timestamp=NULLIF(TRIM(REPLACE(@g,'\r','')),'');
SELECT COUNT(*) FROM order_reviews;

-- ---------------------------------------------------------------------
-- 3. Final row-count check
-- ---------------------------------------------------------------------
SELECT 'customers' AS t, COUNT(*) AS n FROM customers
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'category_translation', COUNT(*) FROM category_translation
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'geolocation', COUNT(*) FROM geolocation;
