-- =======================================================
-- FRAUD DETECTION AND DATA QUALITY CHECKS
-- Vanessa's SQL Project 
-- =======================================================

-- Database
CREATE DATABASE Fraud_Detection_and_Data_Quality_Checks;

-- Create Table
-- users
CREATE TABLE IF NOT EXISTS users (
    user_id SERIAL PRIMARY KEY,
    name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20)
);

-- payment_methods
CREATE TABLE IF NOT EXISTS payment_methods (
    payment_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    payment_type VARCHAR(20), 
    card_number VARCHAR(16)
);

-- transactions
CREATE TABLE transactions (
    txn_id INT PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    amount DECIMAL(10,2),
    txn_date DATE,
    status VARCHAR(20),
    payment_id INT NOT NULL REFERENCES payment_methods(payment_id) ON DELETE CASCADE
);

-- Insert Into Tables
-- users
INSERT INTO users (user_id, name, email, phone) VALUES
(1, 'Alice', 'alice@mail.com', '0812345678'),
(2, 'Bob', 'bob@mail.com', '0823456789'),
(3, 'Charlie', 'charlie@mail.com', '0834567890'),
(4, 'Bob2', 'bob@mail.com', '0823456789'),  -- duplicate email & phone
(5, 'Evan', 'evan@mail.com', NULL);

-- payment_methods
INSERT INTO payment_methods (payment_id, user_id, payment_type, card_number) VALUES
(1, 1, 'credit_card', '1234567890123456'),
(2, 2, 'credit_card', '1234567890123456'), -- suspicious: same card used by 2 users
(3, 3, 'bank_transfer', NULL),
(4, 4, 'credit_card', '5555444433332222'),
(5, 5, 'credit_card', NULL); -- missing card number

--transactions
INSERT INTO transactions (txn_id, user_id, amount, txn_date, status, payment_id) VALUES
(1, 1, 200.00, '2025-01-01', 'success', 1),
(2, 2, 5000.00, '2025-01-02', 'success', 2),
(3, 3, 250.00, '2025-01-02', 'success', 3),
(4, 4, 5000.00, '2025-01-02', 'success', 4),
(5, 5, NULL,    '2025-01-03', 'pending', 5),
(6, 2, 5000.00, '2025-01-02', 'success', 2), -- duplicate transaction
(7, 2, 7000.00, '2025-01-04', 'failed', 2); -- suspicious failed txn

-- Detect Duplicate Transactions
-- Finds transaction that appear more than one (possible fraud or double charge)
WITH duplicate_txns AS (
	SELECT *,
			ROW_NUMBER() OVER(PARTITION BY user_id, amount, txn_date ORDER BY txn_id) AS row_num
	FROM transactions
)
SELECT *
FROM duplicate_txns
WHERE row_num > 1;

-- Identify Users with shared payment methods
-- Flags credit cards use by multiple users (possible fraud)
SELECT card_number, COUNT(DISTINCT user_id) AS users_with_same_card
FROM payment_methods
WHERE card_number IS NOT NULL
GROUP BY card_number
HAVING COUNT(DISTINCT user_id) > 1;

-- High Value Transactions and Risk Scoring
-- Classifies transactions based on amount
SELECT t.txn_id, t.user_id, t.amount,
CASE
	WHEN t.amount >= 5000 THEN 'HIGH RISK'
	WHEN t.amount BETWEEN 2000 AND 4999 THEN 'MEDIUM RISK'
	ELSE 'LOW RISK'
END AS risk_level
FROM transactions t
WHERE status = 'success';

-- Running Total Per Users
-- Shows each transaction and cumulative spending per user over time
SELECT user_id, txn_date, amount, 
		SUM(amount) OVER (PARTITION BY user_id ORDER BY txn_date) AS running_total
FROM transactions
WHERE amount IS NOT NULL
ORDER BY user_id, txn_date;

-- Fraud Monitoring View
CREATE OR REPLACE VIEW fraud_alerts AS
SELECT 
    t.txn_id, 
    t.user_id, 
    t.amount, 
    t.txn_date,
    CASE 
        WHEN t.amount IS NULL THEN 'MISSING AMOUNT'
        WHEN t.amount >= 5000 THEN 'HIGH VALUE TXN'
        WHEN pm.card_number IN (
            SELECT card_number 
            FROM payment_methods
            GROUP BY card_number
            HAVING COUNT(DISTINCT user_id) > 1
        ) THEN 'SHARED CARD NUMBER'
        ELSE 'NORMAL'
    END AS alert_reason
FROM transactions t
JOIN payment_methods pm ON t.payment_id = pm.payment_id;

SELECT * FROM fraud_alerts;