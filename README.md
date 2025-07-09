# BlockTrade
## Overview 

This SQL project models a cryptocurrency trading platform with rich analytics on users, wallets, transactions, and market behavior. The schema includes tables for users, cryptocurrencies, wallets, and transactions, with extended logic for portfolio analysis and trade behavior. Advanced queries were executed to extract insights such as:

 •Portfolio distribution by crypto type (BTC, ETH, stablecoins, altcoins)

 •Trading activity (volume, profit/loss, active pairs)

 •User segmentation (retail vs institutional, verified vs unverified)

 •Market indicators (price change %, volatility, bid-ask spreads)

 •Security checks (large transactions, failed trades, high-risk sources)

## Objectives 

To develop a comprehensive cryptocurrency exchange database system that enables secure trading operations, real-time market analytics, and regulatory compliance monitoring while providing users with portfolio insights and risk management tools.

## Creating Database 
``` sql
CREATE DATABASE BTA_db;
USE BTA_db;
```
## Creating Tables
### Table:
### Table:users
``` sql
CREATE TABLE users (
        user_id            INT PRIMARY KEY AUTO_INCREMENT,
        username           TEXT,
        email              TEXT,
        kyc_verified       BOOLEAN,
        registration_date  DATETIME
);

SELECT * FROM users ;
```
### Table:cryptocurrencies
``` sql
CREATE TABLE cryptocurrencies(
        crypto_id             INT PRIMARY KEY AUTO_INCREMENT,
        symbol                TEXT,
        name                  TEXT,
        current_price         DECIMAL(20,9),
        market_cap            DECIMAL(30,5),
        circulating_supply    DECIMAL(20,5),
        last_updated          DATETIME
);

SELECT * FROM cryptocurrencies ;
```
### Table:wallets
``` sql
CREATE TABLE wallets (
        wallet_id     INT PRIMARY KEY AUTO_INCREMENT,
        user_id       INT,
        crypto_id     INT,
        balance       DECIMAL(20,5),
        FOREIGN KEY (user_id) REFERENCES users(user_id),
        FOREIGN KEY (crypto_id) REFERENCES cryptocurrencies(crypto_id)
);

SELECT * FROM wallets ;
```
### Table:transactions
``` sql
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
```
## KEY Queries 

#### 1  List all verified (KYC) users with their total portfolio value across all cryptocurrencies.
``` sql
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
```
#### 2  Find users who have traded more than 3 different cryptocurrency types.
``` sql
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
```
#### 3  Calculate the average account age (in days) of active traders vs. holders.
``` sql
SELECT 
    user_type,
    ROUND(AVG(DATEDIFF('2023-06-16', registration_date)), 2) AS average_account_age_days
    -- '2023-06-16' Reference date,You can change it with NOW() To find data according current date
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
```
#### 4 Show the daily trading volume (in USD) for each cryptocurrency over the past week
``` sql
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
```
#### 5 Identify the most active trading pairs by transaction count.
``` sql
SELECT 
    CONCAT(c.symbol,'/USD') AS pair,
    COUNT(*) AS total_transactions,
    ROUND(SUM(t.amount * t.price_per_unit), 2) AS total_volume_usd
FROM transactions t
JOIN cryptocurrencies c ON t.crypto_id = c.crypto_id
WHERE 
    t.transaction_type IN ('buy', 'sell')
    AND t.status = 'completed'
GROUP BY c.symbol
ORDER BY total_transactions DESC;
```
#### 6  Find instances where users both bought and sold the same cryptocurrency within 24 hours.
``` sql
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
```
#### 7 Calculate the percentage distribution of assets in each user's portfolio.
``` sql
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
```
#### 8 List users holding more than $10,000 worth of any single cryptocurrency.
``` sql
SELECT 
    u.username,c.symbol,w.balance,
    ROUND(w.balance * c.current_price, 2) AS value_used
FROM wallets w
JOIN users u ON w.user_id = u.user_id
JOIN cryptocurrencies c ON w.crypto_id = c.crypto_id
WHERE w.balance * c.current_price > 10000
ORDER BY value_used DESC;
```
#### 9 Compare the average portfolio size between institutional and retail users.
``` sql
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
```
#### 10 Show the price change percentage for each cryptocurrency over the last 24 hours.
``` sql
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
        AND t.timestamp >= '2023-06-16' - INTERVAL 1 DAY
    -- '2023-06-16' Reference date,You can change it with NOW() To find data according current date
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
```
#### 11 Calculate the 24-hour trading volume and price volatility for each cryptocurrency.
``` sql
SELECT 
    c.symbol,
    ROUND(SUM(t.amount * t.price_per_unit), 2) AS volume_24h,
    ROUND(MAX(t.price_per_unit) - MIN(t.price_per_unit), 6) AS price_range,
    ROUND(STDDEV_POP(t.price_per_unit), 6) AS price_volatility,
    ROUND(STDDEV(t.price_per_unit)*100.0/AVG(t.price_per_unit), 6) AS price_volatility
FROM transactions t
JOIN cryptocurrencies c ON t.crypto_id = c.crypto_id
WHERE 
    t.status = 'completed'
    AND t.transaction_type IN ('buy', 'sell')
    AND t.timestamp >= '2023-06-16' - INTERVAL 1 DAY
    -- '2023-06-16' Reference date,You can change it with NOW() To find data according current date
GROUP BY c.symbol
ORDER BY volume_24h DESC;
```
#### 12 Identify cryptocurrencies with the highest bid-ask spread based on recent trades.
``` sql
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
    AND t.timestamp >= '2023-06-16' - INTERVAL 1 DAY
    -- '2023-06-16' Reference date,You can change it with NOW() To find data according current date
    AND t.transaction_type IN ('buy', 'sell')
GROUP BY c.symbol
HAVING highest_bid IS NOT NULL AND lowest_ask IS NOT NULL
ORDER BY spread_percent DESC;
```
#### 13 Find failed transactions and analyze common characteristics (asset, user type, time).
``` sql
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
```
#### 14 Detect large transactions (>$50,000) and the users involved.
``` sql
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
```
#### 15 Calculate the average transaction size by user type (retail vs. institutional).
``` sql
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
```
#### 16 Identify unverified users making transactions above $10,000.
``` sql
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
```
## Conclusion 

The system successfully tracks and analyzes user behavior, market performance, and transactional risk. It provides deep insights into user portfolios, trading efficiency, and anomalies like large or suspicious transactions. With minor schema extensions (e.g., address-based transfers), it supports AML (anti-money laundering) and compliance reporting as well. The solution demonstrates how structured SQL analytics can power real-time financial intelligence in a crypto environment.
