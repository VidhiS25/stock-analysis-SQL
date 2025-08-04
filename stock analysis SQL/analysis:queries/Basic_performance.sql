USE stocks_proj1;
-- QUERY 1: Overall Period Change (First Day vs Last Day)
SELECT 
    ticker,
    sector,
    MIN(date) as start_date,
    MAX(date) as end_date,
    ROUND(MIN(price), 2) as start_price,
    ROUND(MAX(price), 2) as end_price,
    ROUND(MAX(price) - MIN(price), 2) as dollar_change,
    ROUND(((MAX(price) - MIN(price)) / MIN(price)) * 100, 2) as percent_change
FROM stocks 
GROUP BY ticker, sector
ORDER BY percent_change DESC;
-- QUERY 2: Day-to-Day Changes (Every Single Day)
SELECT 
    ticker,
    date,
    price as current_price,
    LAG(price) OVER (PARTITION BY ticker ORDER BY date) as previous_price,
    ROUND(price - LAG(price) OVER (PARTITION BY ticker ORDER BY date), 2) as daily_dollar_change,
    ROUND(
        ((price - LAG(price) OVER (PARTITION BY ticker ORDER BY date)) 
         / LAG(price) OVER (PARTITION BY ticker ORDER BY date)) * 100, 
        2
    ) as daily_percent_change
FROM stocks 
ORDER BY ticker, date;

-- QUERY 3: Biggest Daily Movers (Top Gainers/Losers)
WITH daily_changes AS (
    SELECT 
        ticker,
        date,
        price,
        LAG(price) OVER (PARTITION BY ticker ORDER BY date) as prev_price,
        ROUND(price - LAG(price) OVER (PARTITION BY ticker ORDER BY date), 2) as daily_change,
        ROUND(
            ((price - LAG(price) OVER (PARTITION BY ticker ORDER BY date)) 
             / LAG(price) OVER (PARTITION BY ticker ORDER BY date)) * 100, 
            2
        ) as daily_percent_change
    FROM stocks
)
SELECT ticker, date, daily_change, daily_percent_change
FROM daily_changes 
WHERE daily_change IS NOT NULL
ORDER BY daily_percent_change DESC
LIMIT 10;

-- QUERY 4: Weekly Performance Summary
SELECT 
    ticker,
    WEEK(date) as week_number,
    MIN(date) as week_start,
    MAX(date) as week_end,
    ROUND(MIN(price), 2) as week_low,
    ROUND(MAX(price), 2) as week_high,
    ROUND(AVG(price), 2) as week_avg,
    ROUND(MAX(price) - MIN(price), 2) as weekly_range
FROM stocks 
GROUP BY ticker, WEEK(date)
ORDER BY ticker, week_number;

-- QUERY 5: Volatility Analysis (Standard Deviation)

SELECT 
    ticker,
    sector,
    COUNT(*) as trading_days,
    ROUND(AVG(price), 2) as avg_price,
    ROUND(STDDEV(price), 2) as price_volatility,
    ROUND(MIN(price), 2) as min_price,
    ROUND(MAX(price), 2) as max_price
FROM stocks 
GROUP BY ticker, sector
ORDER BY price_volatility DESC;

-- QUERY 6: Monthly Performance Comparison
SELECT 
    ticker,
    MONTH(date) as month,
    MONTHNAME(date) as month_name,
    ROUND(MIN(price), 2) as month_low,
    ROUND(MAX(price), 2) as month_high,
    ROUND(AVG(price), 2) as month_avg,
    COUNT(*) as trading_days_in_month
FROM stocks 
GROUP BY ticker, MONTH(date), MONTHNAME(date)
ORDER BY ticker, month;