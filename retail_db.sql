-- ============================================================
-- Retail Company Database
-- DBMS used: MySQL 8.0 (InnoDB)
--
-- Run order:  Section 1 -> Section 2 -> Section 3 -> Section 4
-- ============================================================


-- ============================================================
-- SECTION 1: DDL - CREATE THE DATABASE AND TABLES
-- ============================================================

DROP DATABASE IF EXISTS retail_db;
CREATE DATABASE retail_db;
USE retail_db;


-- ---------- Category ----------
CREATE TABLE category (
    category_id    INT           NOT NULL AUTO_INCREMENT,
    category_name  VARCHAR(50)   NOT NULL,
    description    VARCHAR(200),
    PRIMARY KEY (category_id),
    CONSTRAINT uq_category_name UNIQUE (category_name)
) ENGINE = InnoDB;


-- ---------- Product ----------
-- The foreign key to category is not written here on purpose.
-- We add it later in Section 2 with ALTER TABLE, to show that a
-- constraint can be added after the table already exists.
CREATE TABLE product (
    product_id    INT            NOT NULL AUTO_INCREMENT,
    sku           VARCHAR(20)    NOT NULL,
    product_name  VARCHAR(100)   NOT NULL,
    unit_price    DECIMAL(10,2)  NOT NULL,
    category_id   INT            NOT NULL,
    PRIMARY KEY (product_id),
    CONSTRAINT uq_product_sku  UNIQUE (sku),
    CONSTRAINT chk_product_price CHECK (unit_price > 0)
) ENGINE = InnoDB;


-- ---------- Customer ----------
-- The phone column is left out here on purpose and added in Section 2.
CREATE TABLE customer (
    customer_id        INT          NOT NULL AUTO_INCREMENT,
    first_name         VARCHAR(50)  NOT NULL,
    last_name          VARCHAR(50)  NOT NULL,
    email              VARCHAR(100) NOT NULL,
    city               VARCHAR(50),
    country            VARCHAR(50)  NOT NULL,
    registration_date  DATE         NOT NULL DEFAULT (CURRENT_DATE),
    PRIMARY KEY (customer_id),
    CONSTRAINT uq_customer_email UNIQUE (email)
) ENGINE = InnoDB;


-- ---------- Store ----------
CREATE TABLE store (
    store_id      INT          NOT NULL AUTO_INCREMENT,
    store_name    VARCHAR(100) NOT NULL,
    city          VARCHAR(50)  NOT NULL,
    country       VARCHAR(50)  NOT NULL,
    manager_name  VARCHAR(100),
    PRIMARY KEY (store_id),
    CONSTRAINT uq_store_name UNIQUE (store_name)
) ENGINE = InnoDB;


-- ---------- Store Inventory ----------
-- Stock belongs to a (store, product) pair, so that pair is the primary
-- key. No row means the store does not sell that product. A row with
-- quantity_on_hand = 0 means it sells it but is out of stock now.
CREATE TABLE store_inventory (
    store_id           INT   NOT NULL,
    product_id         INT   NOT NULL,
    quantity_on_hand   INT   NOT NULL DEFAULT 0,
    reorder_level      INT   NOT NULL DEFAULT 10,
    last_restocked_date DATE,
    PRIMARY KEY (store_id, product_id),
    CONSTRAINT fk_inventory_store
        FOREIGN KEY (store_id)   REFERENCES store (store_id),
    CONSTRAINT fk_inventory_product
        FOREIGN KEY (product_id) REFERENCES product (product_id),
    CONSTRAINT chk_inventory_qty CHECK (quantity_on_hand >= 0)
) ENGINE = InnoDB;


-- ---------- Orders ----------
-- "order" is a reserved word in SQL, so we named the table "orders".
CREATE TABLE orders (
    order_id      INT            NOT NULL AUTO_INCREMENT,
    customer_id   INT            NOT NULL,
    store_id      INT            NOT NULL,
    order_date    DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    order_status  VARCHAR(20)    NOT NULL DEFAULT 'PLACED',
    total_amount  DECIMAL(12,2)  NOT NULL DEFAULT 0.00,
    PRIMARY KEY (order_id),
    CONSTRAINT fk_order_customer
        FOREIGN KEY (customer_id) REFERENCES customer (customer_id),
    CONSTRAINT fk_order_store
        FOREIGN KEY (store_id)    REFERENCES store (store_id),
    CONSTRAINT chk_order_status
        CHECK (order_status IN ('PLACED','PAID','SHIPPED','DELIVERED','CANCELLED')),
    CONSTRAINT chk_order_total CHECK (total_amount >= 0)
) ENGINE = InnoDB;


-- ---------- Order Item ----------
-- unit_price is copied from the product at the time of sale, so a later
-- price change does not change the value of old orders.
-- line_total is a generated column, so it can never go out of sync.
CREATE TABLE order_item (
    order_item_id INT            NOT NULL AUTO_INCREMENT,
    order_id      INT            NOT NULL,
    product_id    INT            NOT NULL,
    quantity      INT            NOT NULL,
    unit_price    DECIMAL(10,2)  NOT NULL,
    line_total    DECIMAL(12,2)  AS (quantity * unit_price) STORED,
    PRIMARY KEY (order_item_id),
    CONSTRAINT fk_item_order
        FOREIGN KEY (order_id)   REFERENCES orders (order_id),
    CONSTRAINT fk_item_product
        FOREIGN KEY (product_id) REFERENCES product (product_id),
    CONSTRAINT uq_order_product UNIQUE (order_id, product_id),
    CONSTRAINT chk_item_qty   CHECK (quantity > 0),
    CONSTRAINT chk_item_price CHECK (unit_price >= 0)
) ENGINE = InnoDB;


-- ---------- Payment ----------
-- order_id is a foreign key but not unique, because one order can have
-- many payments. Failed attempts are also kept, for audit.
CREATE TABLE payment (
    payment_id      INT            NOT NULL AUTO_INCREMENT,
    order_id        INT            NOT NULL,
    payment_date    DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    amount          DECIMAL(12,2)  NOT NULL,
    payment_method  VARCHAR(20)    NOT NULL,
    payment_status  VARCHAR(20)    NOT NULL DEFAULT 'PENDING',
    PRIMARY KEY (payment_id),
    CONSTRAINT fk_payment_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id),
    CONSTRAINT chk_payment_method
        CHECK (payment_method IN ('CARD','UPI','NETBANKING','WALLET','CASH')),
    CONSTRAINT chk_payment_status
        CHECK (payment_status IN ('PENDING','SUCCESS','FAILED','REFUNDED')),
    CONSTRAINT chk_payment_amount CHECK (amount > 0)
) ENGINE = InnoDB;


-- ============================================================
-- SECTION 2: ALTER - CHANGES APPLIED AFTER CREATION
-- ============================================================

-- 2a. Add the foreign key we left out of the product table.
ALTER TABLE product
    ADD CONSTRAINT fk_product_category
        FOREIGN KEY (category_id) REFERENCES category (category_id);

-- 2b. Add a column we missed in the first design.
ALTER TABLE customer
    ADD COLUMN phone VARCHAR(20) AFTER email;

-- 2c. Make a column bigger.
ALTER TABLE product
    MODIFY COLUMN product_name VARCHAR(150) NOT NULL;

-- 2d. Add indexes on columns used often in joins and filters.
--     MySQL indexes foreign keys by itself, so these cover the rest.
ALTER TABLE orders  ADD INDEX idx_order_date (order_date);
ALTER TABLE payment ADD INDEX idx_payment_status (payment_status);


-- ============================================================
-- SECTION 3: DML - SAMPLE DATA
-- ============================================================

INSERT INTO category (category_id, category_name, description) VALUES
(1, 'Electronics', 'Computing and electronic devices'),
(2, 'Accessories', 'Cables, stands and small add-ons'),
(3, 'Furniture',   'Desks, chairs and office furniture'),
(4, 'Stationery',  'Paper, pens and desk supplies'),
(5, 'Lighting',    'Lamps and lighting equipment');


INSERT INTO product (product_id, sku, product_name, unit_price, category_id) VALUES
(101, 'SKU-MOU-001', 'Wireless Mouse',       25.00, 1),
(102, 'SKU-KEY-002', 'Mechanical Keyboard',  89.00, 1),
(103, 'SKU-MON-003', '27-inch Monitor',     245.00, 1),
(104, 'SKU-CAB-004', 'USB-C Cable',           9.50, 2),
(105, 'SKU-STA-005', 'Laptop Stand',         39.00, 2),
(106, 'SKU-CHR-006', 'Office Chair',        320.00, 3),
(107, 'SKU-DSK-007', 'Standing Desk',       540.00, 3),
(108, 'SKU-NTB-008', 'Notebook A5',           4.50, 4),
(109, 'SKU-PEN-009', 'Gel Pen Pack',          6.00, 4),
(110, 'SKU-LMP-010', 'Desk Lamp',            45.00, 5);


INSERT INTO store (store_id, store_name, city, country, manager_name) VALUES
(1, 'Mumbai Flagship',  'Mumbai',    'India',         'Ananya Desai'),
(2, 'Singapore Orchard','Singapore', 'Singapore',     'Wei Lin Tan'),
(3, 'Austin Downtown',  'Austin',    'United States', 'Marcus Reed');


INSERT INTO customer (customer_id, first_name, last_name, email, phone, city, country, registration_date) VALUES
(1001, 'Rohan',  'Mehta',    'rohan.mehta@example.com',   '+91-9820011223',  'Mumbai',    'India',         '2024-01-15'),
(1002, 'Priya',  'Nair',     'priya.nair@example.com',    '+91-9845566778',  'Pune',      'India',         '2024-02-02'),
(1003, 'Wei',    'Chen',     'wei.chen@example.com',      '+65-81234567',    'Singapore', 'Singapore',     '2024-02-20'),
(1004, 'Siti',   'Rahman',   'siti.rahman@example.com',   '+65-89998877',    'Singapore', 'Singapore',     '2024-03-11'),
(1005, 'Emily',  'Carter',   'emily.carter@example.com',  '+1-512-555-0134', 'Austin',    'United States', '2024-03-28'),
(1006, 'James',  'Okafor',   'james.okafor@example.com',  '+1-512-555-0199', 'Austin',    'United States', '2024-04-05'),
(1007, 'Aditi',  'Sharma',   'aditi.sharma@example.com',  '+91-9812233445',  'Delhi',     'India',         '2024-05-19'),
(1008, 'Daniel', 'Lim',      'daniel.lim@example.com',    '+65-87776655',    'Singapore', 'Singapore',     '2024-06-30');


-- Not every store sells every product. Product 107 has no row for Singapore.
INSERT INTO store_inventory (store_id, product_id, quantity_on_hand, reorder_level, last_restocked_date) VALUES
(1, 101, 120, 20, '2025-07-01'), (1, 102,  60, 15, '2025-07-01'),
(1, 103,  35, 10, '2025-06-20'), (1, 104, 300, 50, '2025-07-10'),
(1, 105,  80, 20, '2025-06-28'), (1, 106,  25,  8, '2025-06-15'),
(1, 107,  12,  5, '2025-06-15'), (1, 108, 500, 80, '2025-07-12'),
(1, 109, 450, 80, '2025-07-12'), (1, 110,  70, 15, '2025-07-05'),
(2, 101,  90, 20, '2025-07-03'), (2, 102,  45, 15, '2025-07-03'),
(2, 103,  28, 10, '2025-06-22'), (2, 104, 210, 50, '2025-07-09'),
(2, 105,  55, 20, '2025-06-30'), (2, 106,  18,  8, '2025-06-18'),
(2, 108, 320, 80, '2025-07-11'), (2, 110,  40, 15, '2025-07-06'),
(3, 101, 140, 25, '2025-07-02'), (3, 102,  75, 15, '2025-07-02'),
(3, 103,  50, 12, '2025-06-25'), (3, 104, 260, 50, '2025-07-08'),
(3, 105,  95, 20, '2025-06-29'), (3, 106,  30,  8, '2025-06-17'),
(3, 107,  20,  5, '2025-06-17'), (3, 108, 400, 80, '2025-07-13'),
(3, 109, 380, 80, '2025-07-13'), (3, 110,  85, 15, '2025-07-04');


INSERT INTO orders (order_id, customer_id, store_id, order_date, order_status, total_amount) VALUES
(5001, 1001, 1, '2025-07-02 10:15:00', 'DELIVERED',  629.00),
(5002, 1003, 2, '2025-07-04 14:40:00', 'DELIVERED',  334.00),
(5003, 1005, 3, '2025-07-06 09:05:00', 'DELIVERED', 1080.00),
(5004, 1002, 1, '2025-07-08 17:22:00', 'SHIPPED',     58.50),
(5005, 1006, 3, '2025-07-11 11:30:00', 'DELIVERED',  885.00),
(5006, 1004, 2, '2025-07-14 16:10:00', 'PAID',       320.00),
(5007, 1001, 1, '2025-07-18 12:00:00', 'DELIVERED',  245.00),
(5008, 1007, 1, '2025-07-21 08:45:00', 'PLACED',      66.00),
(5009, 1008, 2, '2025-07-25 19:20:00', 'DELIVERED',  468.00),
(5010, 1005, 3, '2025-07-29 13:55:00', 'PAID',       860.00);


INSERT INTO order_item (order_id, product_id, quantity, unit_price) VALUES
(5001, 106, 1, 320.00), (5001, 103, 1, 245.00), (5001, 105, 1,  39.00), (5001, 101, 1,  25.00),
(5002, 103, 1, 245.00), (5002, 102, 1,  89.00),
(5003, 107, 2, 540.00),
(5004, 104, 3,   9.50), (5004, 105, 1,  30.00),
(5005, 107, 1, 540.00), (5005, 106, 1, 320.00), (5005, 109, 5,   5.00),
(5006, 106, 1, 320.00),
(5007, 103, 1, 245.00),
(5008, 108, 8,   4.50), (5008, 109, 5,   6.00),
(5009, 102, 2,  89.00), (5009, 103, 1, 245.00), (5009, 110, 1,  45.00),
(5010, 107, 1, 540.00), (5010, 106, 1, 320.00);


-- Payments cover three real cases:
--   order 5003 was paid in two parts,
--   order 5005 had a card payment fail, then a UPI payment worked,
--   order 5008 has no payment row because it is still PLACED.
INSERT INTO payment (order_id, payment_date, amount, payment_method, payment_status) VALUES
(5001, '2025-07-02 10:16:00',  629.00, 'CARD',       'SUCCESS'),
(5002, '2025-07-04 14:41:00',  334.00, 'NETBANKING', 'SUCCESS'),
(5003, '2025-07-06 09:06:00',  600.00, 'CARD',       'SUCCESS'),
(5003, '2025-07-09 20:10:00',  480.00, 'UPI',        'SUCCESS'),
(5004, '2025-07-08 17:23:00',   58.50, 'UPI',        'SUCCESS'),
(5005, '2025-07-11 11:31:00',  885.00, 'CARD',       'FAILED'),
(5005, '2025-07-11 11:35:00',  885.00, 'UPI',        'SUCCESS'),
(5006, '2025-07-14 16:11:00',  320.00, 'WALLET',     'SUCCESS'),
(5007, '2025-07-18 12:01:00',  245.00, 'CARD',       'SUCCESS'),
(5009, '2025-07-25 19:21:00',  468.00, 'CARD',       'SUCCESS'),
(5010, '2025-07-29 13:56:00',  500.00, 'CARD',       'SUCCESS'),
(5010, '2025-07-30 09:00:00',  360.00, 'NETBANKING', 'SUCCESS');


-- Check the data loaded
SELECT 'category' AS table_name, COUNT(*) AS rows_loaded FROM category
UNION ALL SELECT 'product',         COUNT(*) FROM product
UNION ALL SELECT 'customer',        COUNT(*) FROM customer
UNION ALL SELECT 'store',           COUNT(*) FROM store
UNION ALL SELECT 'store_inventory', COUNT(*) FROM store_inventory
UNION ALL SELECT 'orders',          COUNT(*) FROM orders
UNION ALL SELECT 'order_item',      COUNT(*) FROM order_item
UNION ALL SELECT 'payment',         COUNT(*) FROM payment;


-- ============================================================
-- SECTION 4: SQL RETRIEVAL
-- ============================================================

-- ---------- Query 1 ----------
-- Each order with its customer name and order date.
SELECT
    o.order_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    o.order_date,
    o.order_status,
    o.total_amount
FROM orders o
JOIN customer c ON c.customer_id = o.customer_id
ORDER BY o.order_date;


-- ---------- Query 2 ----------
-- Total amount spent by each customer.
--
-- One order can have many payments, so we take "spent" as the money the
-- company actually received, that is the sum of SUCCESS payments. FAILED
-- attempts are left out. LEFT JOIN keeps customers who have not paid
-- anything and shows them as 0.00 instead of dropping them.
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.country,
    COALESCE(SUM(p.amount), 0.00) AS total_spent
FROM customer c
LEFT JOIN orders  o ON o.customer_id = c.customer_id
LEFT JOIN payment p ON p.order_id = o.order_id
                   AND p.payment_status = 'SUCCESS'
GROUP BY c.customer_id, c.first_name, c.last_name, c.country
ORDER BY total_spent DESC;


-- For comparison: how much the customers ordered. This is a different
-- number while some orders are still unpaid.
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    COALESCE(SUM(o.total_amount), 0.00) AS total_ordered
FROM customer c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_ordered DESC;


-- ---------- Query 3 ----------
-- The three products with the highest sales revenue.
--
-- Revenue uses order_item.unit_price, the price at the time of sale, and
-- not the current product.unit_price.
SELECT
    p.product_id,
    p.product_name,
    cat.category_name,
    SUM(oi.quantity)   AS units_sold,
    SUM(oi.line_total) AS total_revenue
FROM order_item oi
JOIN product  p   ON p.product_id  = oi.product_id
JOIN category cat ON cat.category_id = p.category_id
GROUP BY p.product_id, p.product_name, cat.category_name
ORDER BY total_revenue DESC
LIMIT 3;


-- ============================================================
-- SECTION 5: TRANSACTION MANAGEMENT
-- ============================================================
-- A customer orders two products and pays for them.
-- These five statements must all pass or all fail:
--   1. insert the order
--   2. insert order item 1
--   3. insert order item 2
--   4. reduce the fulfilling store's inventory
--   5. insert the payment

-- ---------- 5A. Successful transaction, ending in COMMIT ----------

START TRANSACTION;

INSERT INTO orders (order_id, customer_id, store_id, order_date, order_status, total_amount)
VALUES (5011, 1001, 1, '2025-08-02 10:00:00', 'PLACED', 179.00);

INSERT INTO order_item (order_id, product_id, quantity, unit_price)
VALUES (5011, 102, 1, 89.00);

INSERT INTO order_item (order_id, product_id, quantity, unit_price)
VALUES (5011, 110, 2, 45.00);

UPDATE store_inventory
   SET quantity_on_hand = quantity_on_hand - 1
 WHERE store_id = 1 AND product_id = 102;

UPDATE store_inventory
   SET quantity_on_hand = quantity_on_hand - 2
 WHERE store_id = 1 AND product_id = 110;

INSERT INTO payment (order_id, payment_date, amount, payment_method, payment_status)
VALUES (5011, '2025-08-02 10:01:00', 179.00, 'CARD', 'SUCCESS');

UPDATE orders SET order_status = 'PAID' WHERE order_id = 5011;

COMMIT;

-- Verify the committed result
SELECT * FROM orders     WHERE order_id = 5011;
SELECT * FROM order_item WHERE order_id = 5011;
SELECT * FROM payment    WHERE order_id = 5011;
SELECT * FROM store_inventory WHERE store_id = 1 AND product_id IN (102, 110);


-- ---------- 5B. Failed payment, ending in ROLLBACK ----------
-- Stock before the attempt, so we can compare it later.
SELECT store_id, product_id, quantity_on_hand
  FROM store_inventory
 WHERE store_id = 1 AND product_id IN (103, 105);

START TRANSACTION;

INSERT INTO orders (order_id, customer_id, store_id, order_date, order_status, total_amount)
VALUES (5012, 1002, 1, '2025-08-03 11:00:00', 'PLACED', 284.00);

INSERT INTO order_item (order_id, product_id, quantity, unit_price)
VALUES (5012, 103, 1, 245.00);

INSERT INTO order_item (order_id, product_id, quantity, unit_price)
VALUES (5012, 105, 1, 39.00);

UPDATE store_inventory
   SET quantity_on_hand = quantity_on_hand - 1
 WHERE store_id = 1 AND product_id = 103;

UPDATE store_inventory
   SET quantity_on_hand = quantity_on_hand - 1
 WHERE store_id = 1 AND product_id = 105;

-- Inside the transaction our own session can already see these rows.
SELECT * FROM orders     WHERE order_id = 5012;
SELECT * FROM order_item WHERE order_id = 5012;

-- The payment now fails. We intentionally use 'CRYPTO', which violates
-- chk_payment_method. This simulates a payment-gateway failure.
-- Run this statement, note the constraint error, then execute ROLLBACK.
-- In MySQL/InnoDB, the failed statement does not end the transaction, so
-- the transaction can still be rolled back.

INSERT INTO payment (order_id, amount, payment_method, payment_status)
VALUES (5012, 284.00, 'CRYPTO', 'SUCCESS');

-- After the payment statement fails, execute this separately:
ROLLBACK;

-- Check that nothing is left. All three queries return no rows and the
-- stock is back to the values from before the transaction.
SELECT * FROM orders     WHERE order_id = 5012;
SELECT * FROM order_item WHERE order_id = 5012;
SELECT * FROM payment    WHERE order_id = 5012;
SELECT store_id, product_id, quantity_on_hand
  FROM store_inventory
 WHERE store_id = 1 AND product_id IN (103, 105);


-- ============================================================
-- SECTION 6: SCHEMA EVOLUTION - LOYALTY PROGRAMME
-- ============================================================

-- ---------- Recommended: a new table ----------
CREATE TABLE customer_loyalty (
    loyalty_id        VARCHAR(20)  NOT NULL,
    customer_id       INT          NOT NULL,
    loyalty_points    INT          NOT NULL DEFAULT 0,
    membership_level  VARCHAR(20)  NOT NULL DEFAULT 'BRONZE',
    enrolled_date     DATE         NOT NULL DEFAULT (CURRENT_DATE),
    PRIMARY KEY (loyalty_id),
    CONSTRAINT uq_loyalty_customer UNIQUE (customer_id),
    CONSTRAINT fk_loyalty_customer
        FOREIGN KEY (customer_id) REFERENCES customer (customer_id),
    CONSTRAINT chk_loyalty_level
        CHECK (membership_level IN ('BRONZE','SILVER','GOLD','PLATINUM')),
    CONSTRAINT chk_loyalty_points CHECK (loyalty_points >= 0)
) ENGINE = InnoDB;

-- Add some existing customers. Joining is optional, so not everyone is here.
INSERT INTO customer_loyalty (loyalty_id, customer_id, loyalty_points, membership_level, enrolled_date) VALUES
('LOY-2025-0001', 1001, 1250, 'GOLD',     '2025-01-10'),
('LOY-2025-0002', 1003,  340, 'SILVER',   '2025-02-14'),
('LOY-2025-0003', 1005, 2680, 'PLATINUM', '2025-01-22'),
('LOY-2025-0004', 1008,   90, 'BRONZE',   '2025-06-01');

-- A view so the old application code can read customer and loyalty data
-- together without being rewritten. The LEFT JOIN keeps customers who
-- never joined the programme.
CREATE OR REPLACE VIEW v_customer_with_loyalty AS
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.phone,
    c.city,
    c.country,
    c.registration_date,
    l.loyalty_id,
    COALESCE(l.loyalty_points, 0)        AS loyalty_points,
    COALESCE(l.membership_level, 'NONE') AS membership_level
FROM customer c
LEFT JOIN customer_loyalty l ON l.customer_id = c.customer_id;

SELECT * FROM v_customer_with_loyalty;


-- ---------- Alternative: extra columns on customer ----------
-- Kept here only for comparison. It is shorter but weaker, because the
-- three columns stay NULL for every customer who never joins, and loyalty
-- history cannot be kept separate from the customer record.
--
-- ALTER TABLE customer
--     ADD COLUMN loyalty_id       VARCHAR(20) NULL,
--     ADD COLUMN loyalty_points   INT         NOT NULL DEFAULT 0,
--     ADD COLUMN membership_level VARCHAR(20) NULL;
--
-- ALTER TABLE customer
--     ADD CONSTRAINT uq_customer_loyalty_id UNIQUE (loyalty_id);
