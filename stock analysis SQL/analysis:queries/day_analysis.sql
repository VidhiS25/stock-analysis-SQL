
USE stocks_proj1;

-- QUERY 1: Every Day-to-Day Move for All Stocks

SELECT 
    ticker,
    date as current_date,
    LAG(date) OVER (PARTITION BY ticker ORDER BY date) as previous_date,
    ROUND(price, 2) as current_price,
    ROUND(LAG(price) OVER (PARTITION BY ticker ORDER BY date), 2) as previous_price,
    ROUND(price - LAG(price) OVER (PARTITION BY ticker ORDER BY date), 2) as dollar_change,
    ROUND(
        ((price - LAG(price) OVER (PARTITION BY ticker ORDER BY date)) 
         / LAG(price) OVER (PARTITION BY ticker ORDER BY date)) * 100, 
        2
    ) as percent_change
FROM stocks 
ORDER BY ticker, date;

-- QUERY 2: Biggest Single-Day Dollar Moves (Winners & Losers)

WITH daily_moves AS (
    SELECT 
        ticker,
        date,
        price,
        LAG(price) OVER (PARTITION BY ticker ORDER BY date) as prev_price,
        ROUND(price - LAG(price) OVER (PARTITION BY ticker ORDER BY date), 2) as dollar_change,
        ROUND(
            ((price - LAG(price) OVER (PARTITION BY ticker ORDER BY date)) 
             / LAG(price) OVER (PARTITION BY ticker ORDER BY date)) * 100, 
            2
        ) as percent_change
    FROM stocks
)
SELECT 
    RANK() OVER (ORDER BY ABS(dollar_change) DESC) as move_rank,
    ticker,
    date,
    CONCAT('$', prev_price, ' → $', price) as price_move,
    CASE 
        WHEN dollar_change > 0 THEN CONCAT('+$', dollar_change)
        ELSE CONCAT('$', dollar_change)
    END as dollar_change,
    CASE 
        WHEN percent_change > 0 THEN CONCAT('+', percent_change, '%')
        ELSE CONCAT(percent_change, '%')
    END as percent_change,
    CASE 
        WHEN dollar_change > 0 THEN '📈 UP'
        ELSE '📉 DOWN'
    END as direction
FROM daily_moves 
WHERE dollar_change IS NOT NULL
ORDER BY ABS(dollar_change) DESC
LIMIT 15;

-- QUERY 3: Biggest Single-Day Percentage Moves

WITH daily_moves AS (
    SELECT 
        ticker,
        date,
        price,
        LAG(price) OVER (PARTITION BY ticker ORDER BY date) as prev_price,
        ROUND(price - LAG(price) OVER (PARTITION BY ticker ORDER BY date), 2) as dollar_change,
        ROUND(
            ((price - LAG(price) OVER (PARTITION BY ticker ORDER BY date)) 
             / LAG(price) OVER (PARTITION BY ticker ORDER BY date)) * 100, 
            2
        ) as percent_change
    FROM stocks
)
SELECT 
    RANK() OVER (ORDER BY ABS(percent_change) DESC) as move_rank,
    ticker,
    date,
    ROUND(prev_price, 2) as previous_price,
    ROUND(price, 2) as current_price,
    CASE 
        WHEN percent_change > 0 THEN CONCAT('+', percent_change, '%')
        ELSE CONCAT(percent_change, '%')
    END as percent_change,
    CASE 
        WHEN percent_change > 0 THEN '🚀 BIGGEST GAIN'
        ELSE '💥 BIGGEST DROP'
    END as move_type
FROM daily_moves 
WHERE percent_change IS NOT NULL
ORDER BY ABS(percent_change) DESC
LIMIT 10;


-- QUERY 4: Your Specific Example - Apple Day Analysis

WITH apple_daily AS (
    SELECT 
        date,
        price,
        LAG(date) OVER (ORDER BY date) as prev_date,
        LAG(price) OVER (ORDER BY date) as prev_price,
        ROUND(price - LAG(price) OVER (ORDER BY date), 2) as dollar_change,
        ROUND(
            ((price - LAG(price) OVER (ORDER BY date)) 
             / LAG(price) OVER (ORDER BY date)) * 100, 
            2
        ) as percent_change
    FROM stocks 
    WHERE ticker = 'AAPL'
    ORDER BY date
)
SELECT 
    CONCAT(prev_date, ' → ', date) as day_transition,
    CONCAT('$', prev_price, ' → $', price) as price_move,
    CASE 
        WHEN dollar_change > 0 THEN CONCAT('+$', dollar_change)
        ELSE CONCAT('$', dollar_change)
    END as dollar_change,
    CASE 
        WHEN percent_change > 0 THEN CONCAT('+', percent_change, '%')
        ELSE CONCAT(percent_change, '%')
    END as percent_change
FROM apple_daily
WHERE dollar_change IS NOT NULL
ORDER BY ABS(percent_change) DESC;


-- QUERY 5: Daily Movement Champions by Stock

WITH daily_moves AS (
    SELECT 
        ticker,
        date,
        price,
        LAG(price) OVER (PARTITION BY ticker ORDER BY date) as prev_price,
        ROUND(
            ((price - LAG(price) OVER (PARTITION BY ticker ORDER BY date)) 
             / LAG(price) OVER (PARTITION BY ticker ORDER BY date)) * 100, 
            2
        ) as percent_change
    FROM stocks
),
biggest_moves AS (
    SELECT 
        ticker,
        date,
        percent_change,
        RANK() OVER (PARTITION BY ticker ORDER BY ABS(percent_change) DESC) as move_rank
    FROM daily_moves 
    WHERE percent_change IS NOT NULL
)
SELECT 
    ticker,
    date as biggest_move_date,
    CASE 
        WHEN percent_change > 0 THEN CONCAT('+', percent_change, '%')
        ELSE CONCAT(percent_change, '%')
    END as biggest_single_day_move,
    CASE 
        WHEN percent_change > 0 THEN 'BEST DAY'
        ELSE 'WORST DAY'
    END as move_type
FROM biggest_moves
WHERE move_rank = 1
ORDER BY ABS(percent_change) DESC;


-- QUERY 6: Volatility Kings (Most Day-to-Day Movement)

WITH daily_moves AS (
    SELECT 
        ticker,
        ABS(ROUND(
            ((price - LAG(price) OVER (PARTITION BY ticker ORDER BY date)) 
             / LAG(price) OVER (PARTITION BY ticker ORDER BY date)) * 100, 
            2
        )) as abs_percent_change
    FROM stocks
)
SELECT 
    ticker,
    ROUND(AVG(abs_percent_change), 2) as avg_daily_volatility,
    ROUND(MAX(abs_percent_change), 2) as max_single_day_move,
    COUNT(*) as trading_days,
    CASE 
        WHEN AVG(abs_percent_change) > 2 THEN '🌪️ HIGHLY VOLATILE'
        WHEN AVG(abs_percent_change) > 1 THEN '📊 MODERATE VOLATILITY'
        ELSE '😴 LOW VOLATILITY'
    END as volatility_rating
FROM daily_moves 
WHERE abs_percent_change IS NOT NULL
GROUP BY ticker
ORDER BY avg_daily_volatility DESC;


-- QUERY 7: Weekly Movement Patterns

WITH daily_moves AS (
    SELECT 
        ticker,
        date,
        DAYNAME(date) as day_of_week,
        ROUND(
            ((price - LAG(price) OVER (PARTITION BY ticker ORDER BY date)) 
             / LAG(price) OVER (PARTITION BY ticker ORDER BY date)) * 100, 
            2
        ) as percent_change
    FROM stocks
)
SELECT 
    day_of_week,
    COUNT(*) as total_moves,
    ROUND(AVG(percent_change), 2) as avg_daily_change,
    ROUND(MAX(percent_change), 2) as biggest_gain,
    ROUND(MIN(percent_change), 2) as biggest_loss
FROM daily_moves 
WHERE percent_change IS NOT NULL
GROUP BY day_of_week
ORDER BY FIELD(day_of_week, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday');