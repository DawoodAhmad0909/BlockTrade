CREATE DATABASE BTA_db;
USE BTA_db;

CREATE TABLE users (
	user_id            INT PRIMARY KEY AUTO_INCREMENT,
	username           TEXT,
	email              TEXT,
	kyc_verified       BOOLEAN,
	registration_date  DATETIME
);

SELECT * FROM users ;

INSERT INTO users (username, email, kyc_verified, registration_date) VALUES
	('crypto_trader', 'trader@example.com', TRUE, '2023-01-15 09:32:45'),
	('bitcoin_holder', 'holder@example.com', TRUE, '2023-02-18 14:21:33'),
	('day_trader', 'daytrader@example.com', FALSE, '2023-03-22 11:45:12'),
	('institutional_x', 'institution@example.com', TRUE, '2023-04-05 16:30:27'),
	('newbie123', 'newuser@example.com', FALSE, '2023-05-30 08:15:19');

CREATE TABLE cryptocurrencies (
	crypto_id             INT PRIMARY KEY AUTO_INCREMENT,
	symbol                TEXT,
	name                  TEXT,
	current_price         DECIMAL(20,9),
	market_cap            DECIMAL(30,5),
	circulating_supply    DECIMAL(20,5),
	last_updated          DATETIME
);

SELECT * FROM cryptocurrencies ;

INSERT INTO cryptocurrencies (symbol, name, current_price, market_cap, circulating_supply, last_updated) VALUES 
	('BTC', 'Bitcoin', 30245.50, 588324000000, 19424643, '2023-06-15 12:00:00'),
	('ETH', 'Ethereum', 1876.25, 225150000000, 120000000, '2023-06-15 12:00:00'),
	('USDT', 'Tether', 0.9998, 83200000000, 83200000000, '2023-06-15 12:00:00'),
	('XRP', 'Ripple', 0.4875, 25700000000, 52700000000, '2023-06-15 12:00:00'),
	('ADA', 'Cardano', 0.2763, 9700000000, 35000000000, '2023-06-15 12:00:00');

CREATE TABLE wallets (
	wallet_id     INT PRIMARY KEY AUTO_INCREMENT,
	user_id       INT,
	crypto_id     INT,
	balance       DECIMAL(20,5),
	FOREIGN KEY (user_id) REFERENCES users(user_id),
	FOREIGN KEY (crypto_id) REFERENCES cryptocurrencies(crypto_id)
);

SELECT * FROM wallets ;

INSERT INTO wallets (user_id, crypto_id, balance) VALUES 
	(1, 1, 2.5),    
	(1, 2, 15.0),   
	(1, 3, 50000.0),
	(2, 1, 0.8),    
	(2, 4, 2500.0), 
	(3, 2, 3.2),    
	(3, 5, 10000.0),
	(4, 1, 12.0),  
	(4, 3, 250000.0),
	(5, 2, 0.5);    

CREATE TABLE transactions (
	transaction_id       INT PRIMARY KEY AUTO_INCREMENT,
	user_id              INT,
	crypto_id            INT,
	amount               DECIMAL(20,5),
	price_per_unit       DECIMAL(20,5),
	transaction_type     TEXT,
	timestamp            DATETIME,
	status               TEXT,
	FOREIGN KEY (user_id) REFERENCES users(user_id),
	FOREIGN KEY (crypto_id) REFERENCES cryptocurrencies(crypto_id)
);

SELECT * FROM transactions ;

INSERT INTO transactions (user_id, crypto_id, amount, price_per_unit,transaction_type,timestamp, status) VALUES
	(1, 1, 0.5, 30120.00, 'sell', '2023-06-15 09:32:47', 'completed'),
	(2, 1, 0.2, 30150.00, 'buy', '2023-06-15 09:33:12', 'completed'),
	(3, 2, 1.0, 1872.50, 'sell', '2023-06-15 10:15:33', 'completed'),
	(1, 2, 2.0, 1875.00, 'buy', '2023-06-15 10:16:05', 'completed'),
	(4, 3, 50000.0, 1.00, 'transfer', '2023-06-15 11:22:18', 'completed'),
	(2, 4, 500.0, 0.4865, 'sell', '2023-06-15 12:45:22', 'completed'),
	(5, 5, 2000.0, 0.2750, 'buy', '2023-06-15 13:30:47', 'completed'),
	(4, 1, 1.5, 30200.00, 'buy', '2023-06-15 14:15:33', 'completed'),
	(5, 2, 0.3, 1878.00, 'buy', '2023-06-15 15:22:11', 'failed'),
	(1, 3, 10000.0, 1.00, 'sell', '2023-06-14 16:45:19', 'completed'),
	(3, 1, 0.1, 29980.00, 'buy', '2023-06-14 17:30:42', 'completed'),
	(2, 2, 0.5, 1865.00, 'buy', '2023-06-14 18:22:37', 'completed'),
	(4, 4, 1000.0, 0.4920, 'buy', '2023-06-14 19:15:28', 'completed'),
	(1, 5, 5000.0, 0.2740, 'sell', '2023-06-14 20:05:33', 'completed');

SELECT 
    u.username,
    ROUND(SUM(w.balance * c.current_price), 2) AS total_portfolio_usd,
    COUNT(DISTINCT w.crypto_id) AS crypto_count
FROM users u
JOIN wallets w ON u.user_id = w.user_id
JOIN cryptocurrencies c ON w.crypto_id = c.crypto_id
WHERE u.kyc_verified = TRUE
GROUP BY u.username
ORDER BY total_portfolio_usd DESC;

SELECT 
    u.username,
    COUNT(DISTINCT t.crypto_id) AS assets_traded,
    MAX(DATE(t.timestamp)) AS last_trade_date
FROM transactions t
JOIN users u ON t.user_id = u.user_id
WHERE t.status = 'completed'
GROUP BY u.username
HAVING COUNT(DISTINCT t.crypto_id) > 3
ORDER BY assets_traded DESC;
    
SELECT 
    user_type,
    ROUND(AVG(DATEDIFF(NOW(), registration_date)), 2) AS average_account_age_days
FROM (
    SELECT 
        u.user_id,
        u.username,
        u.registration_date,
        CASE 
            WHEN EXISTS (
                SELECT 1 
                FROM transactions t 
                WHERE t.user_id = u.user_id
                  AND t.transaction_type IN ('buy', 'sell')
                  AND t.status = 'completed'
            )
            THEN 'Trader'
            ELSE 'Holder'
        END AS user_type
    FROM users u
) AS categorized_users
GROUP BY user_type;

SELECT 
    DATE(t.timestamp) AS trade_date,c.symbol,
    ROUND(SUM(t.amount * t.price_per_unit), 2) AS volume_usd
FROM transactions t
JOIN cryptocurrencies c ON t.crypto_id = c.crypto_id
WHERE 
    t.transaction_type IN ('buy', 'sell')
    AND t.status = 'completed'
GROUP BY DATE(t.timestamp), c.symbol
ORDER BY trade_date DESC, c.symbol;

SELECT 
    c.symbol AS pair,
    COUNT(*) AS total_transactions,
    ROUND(SUM(t.amount * t.price_per_unit), 2) AS total_volume_usd
FROM transactions t
JOIN cryptocurrencies c ON t.crypto_id = c.crypto_id
WHERE 
    t.transaction_type IN ('buy', 'sell')
    AND t.status = 'completed'
GROUP BY c.symbol
ORDER BY total_transactions DESC;

SELECT 
    u.username,
    c.symbol,
    b.timestamp AS buy_time,
    s.timestamp AS sell_time,
    ROUND((s.price_per_unit - b.price_per_unit) * LEAST(b.amount, s.amount), 2) AS profit_loss
FROM 
    transactions b
JOIN 
    transactions s 
    ON b.user_id = s.user_id
    AND b.crypto_id = s.crypto_id
    AND b.transaction_type = 'buy'
    AND s.transaction_type = 'sell'
    AND b.status = 'completed'
    AND s.status = 'completed'
    AND b.timestamp < s.timestamp
    AND TIMESTAMPDIFF(HOUR, b.timestamp, s.timestamp) <= 24
JOIN users u ON b.user_id = u.user_id
JOIN cryptocurrencies c ON b.crypto_id = c.crypto_id
ORDER BY u.username, c.symbol, b.timestamp;

WITH user_portfolio AS (
    SELECT 
        w.user_id,
        c.symbol,
        SUM(w.balance * c.current_price) AS asset_value_usd
    FROM wallets w
    JOIN cryptocurrencies c ON w.crypto_id = c.crypto_id
    GROUP BY w.user_id, c.symbol
),
user_totals AS (
    SELECT 
        user_id,
        SUM(asset_value_usd) AS total_value
    FROM user_portfolio
    GROUP BY user_id
),
user_distribution AS (
    SELECT
        up.user_id,
        up.symbol,
        up.asset_value_usd,
        ut.total_value,
        CASE 
            WHEN up.symbol = 'BTC' THEN 'BTC'
            WHEN up.symbol = 'ETH' THEN 'ETH'
            WHEN up.symbol = 'USDT' THEN 'Stablecoins'
            ELSE 'Altcoins'
        END AS category
    FROM user_portfolio up
    JOIN user_totals ut ON up.user_id = ut.user_id
),
category_sums AS (
    SELECT
        user_id,
        category,
        SUM(asset_value_usd) AS category_value,
        MAX(total_value) AS total_value
    FROM user_distribution
    GROUP BY user_id, category
)
SELECT 
    u.username,
    ROUND(COALESCE(MAX(CASE WHEN cs.category = 'BTC' THEN (cs.category_value / cs.total_value) * 100 END), 0), 2) AS BTC_percent,
    ROUND(COALESCE(MAX(CASE WHEN cs.category = 'ETH' THEN (cs.category_value / cs.total_value) * 100 END), 0), 2) AS ETH_percent,
    ROUND(COALESCE(MAX(CASE WHEN cs.category = 'Stablecoins' THEN (cs.category_value / cs.total_value) * 100 END), 0), 2) AS Stablecoins_percent,
    ROUND(COALESCE(MAX(CASE WHEN cs.category = 'Altcoins' THEN (cs.category_value / cs.total_value) * 100 END), 0), 2) AS Altcoins_percent
FROM category_sums cs
JOIN users u ON cs.user_id = u.user_id
GROUP BY u.username
ORDER BY u.username;

SELECT 
    u.username,c.symbol,w.balance,
    ROUND(w.balance * c.current_price, 2) AS value_used
FROM wallets w
JOIN users u ON w.user_id = u.user_id
JOIN cryptocurrencies c ON w.crypto_id = c.crypto_id
WHERE w.balance * c.current_price > 10000
ORDER BY value_used DESC;

WITH user_type_cte AS (
    SELECT 
        user_id,
        username,
        CASE 
            WHEN LOWER(username) LIKE '%institution%' THEN 'Institutional'
            ELSE 'Retail'
        END AS user_type
    FROM users
),
portfolio_values AS (
    SELECT 
        w.user_id,
        SUM(w.balance * c.current_price) AS portfolio_value
    FROM wallets w
    JOIN cryptocurrencies c ON w.crypto_id = c.crypto_id
    GROUP BY w.user_id
),
transaction_sizes AS (
    SELECT 
        t.user_id,
        AVG(t.amount * t.price_per_unit) AS avg_txn_size
    FROM transactions t
    WHERE t.status = 'completed'
    GROUP BY t.user_id
)
SELECT 
    u.user_type,
    ROUND(AVG(p.portfolio_value), 2) AS avg_portfolio_usd,
    ROUND(AVG(ts.avg_txn_size), 2) AS avg_transaction_size_usd
FROM 
    user_type_cte u
LEFT JOIN portfolio_values p ON u.user_id = p.user_id
LEFT JOIN transaction_sizes ts ON u.user_id = ts.user_id
GROUP BY u.user_type;

WITH price_data AS (
    SELECT 
        t.crypto_id,
        c.symbol,
        t.price_per_unit,
        t.timestamp,
        ROW_NUMBER() OVER (PARTITION BY t.crypto_id ORDER BY t.timestamp ASC) AS rn_asc,
        ROW_NUMBER() OVER (PARTITION BY t.crypto_id ORDER BY t.timestamp DESC) AS rn_desc
    FROM 
        transactions t
    JOIN cryptocurrencies c ON t.crypto_id = c.crypto_id
    WHERE 
        t.status = 'completed'
        AND t.timestamp >= NOW() - INTERVAL 1 DAY
)
SELECT 
    symbol,
    MIN(CASE WHEN rn_asc = 1 THEN price_per_unit END) AS open_price,
    MIN(CASE WHEN rn_desc = 1 THEN price_per_unit END) AS close_price,
    ROUND(
        ((MIN(CASE WHEN rn_desc = 1 THEN price_per_unit END) - MIN(CASE WHEN rn_asc = 1 THEN price_per_unit END))
         / MIN(CASE WHEN rn_asc = 1 THEN price_per_unit END)) * 100, 2
    ) AS percentage_change
FROM price_data
GROUP BY crypto_id, symbol
ORDER BY symbol;

SELECT 
    c.symbol,
    ROUND(SUM(t.amount * t.price_per_unit), 2) AS volume_24h,
    ROUND(MAX(t.price_per_unit) - MIN(t.price_per_unit), 6) AS price_range,
    ROUND(STDDEV_POP(t.price_per_unit), 6) AS price_volatility
FROM transactions t
JOIN cryptocurrencies c ON t.crypto_id = c.crypto_id
WHERE 
    t.status = 'completed'
    AND t.transaction_type IN ('buy', 'sell')
    AND t.timestamp >= NOW() - INTERVAL 1 DAY
GROUP BY c.symbol
ORDER BY volume_24h DESC;

SELECT
    c.symbol,
    MAX(CASE WHEN t.transaction_type = 'buy' THEN t.price_per_unit ELSE NULL END) AS highest_bid,
    MIN(CASE WHEN t.transaction_type = 'sell' THEN t.price_per_unit ELSE NULL END) AS lowest_ask,
    ROUND(
        MIN(CASE WHEN t.transaction_type = 'sell' THEN t.price_per_unit ELSE NULL END) 
        - MAX(CASE WHEN t.transaction_type = 'buy' THEN t.price_per_unit ELSE NULL END), 
        6
    ) AS spread,
    ROUND(
        ((MIN(CASE WHEN t.transaction_type = 'sell' THEN t.price_per_unit ELSE NULL END)
        - MAX(CASE WHEN t.transaction_type = 'buy' THEN t.price_per_unit ELSE NULL END)) 
        / MAX(CASE WHEN t.transaction_type = 'buy' THEN t.price_per_unit ELSE NULL END)) * 100,
        4
    ) AS spread_percent
FROM transactions t
JOIN cryptocurrencies c ON t.crypto_id = c.crypto_id
WHERE
    t.status = 'completed'
    AND t.timestamp >= NOW() - INTERVAL 1 DAY
    AND t.transaction_type IN ('buy', 'sell')
GROUP BY c.symbol
HAVING highest_bid IS NOT NULL AND lowest_ask IS NOT NULL
ORDER BY spread_percent DESC;

SELECT 
    c.symbol,
    COUNT(*) AS fail_count,
    ROUND(AVG(t.amount), 4) AS avg_amount,
    HOUR(t.timestamp) AS hour
FROM transactions t
JOIN cryptocurrencies c ON t.crypto_id = c.crypto_id
WHERE t.status = 'failed'
GROUP BY c.symbol, hour
ORDER BY fail_count DESC;

SELECT 
    u.username,c.symbol,t.timestamp,
    t.amount,ROUND(t.amount * t.price_per_unit, 2) AS value
FROM transactions t
JOIN users u ON t.user_id = u.user_id
JOIN cryptocurrencies c ON t.crypto_id = c.crypto_id
WHERE 
    t.status = 'completed'
    AND (t.amount * t.price_per_unit) > 50000
ORDER BY value DESC;

WITH user_types AS (
    SELECT 
        user_id,
        CASE 
            WHEN LOWER(username) LIKE '%institution%' THEN 'Institutional'
            ELSE 'Retail'
        END AS user_type
    FROM users
)
SELECT 
    ut.user_type,
    ROUND(AVG(t.amount * t.price_per_unit), 2) AS avg_transaction_size_usd
FROM transactions t
JOIN user_types ut ON t.user_id = ut.user_id
WHERE t.status = 'completed'
GROUP BY ut.user_type;

SELECT 
    u.username,
    ROUND(t.amount * t.price_per_unit, 2) AS transaction_amount,
    c.symbol,t.timestamp AS transaction_date
FROM transactions t
JOIN users u ON t.user_id = u.user_id
JOIN cryptocurrencies c ON t.crypto_id = c.crypto_id
WHERE 
    u.kyc_verified = FALSE
    AND t.status = 'completed'
    AND (t.amount * t.price_per_unit) > 10000
ORDER BY transaction_amount DESC;
