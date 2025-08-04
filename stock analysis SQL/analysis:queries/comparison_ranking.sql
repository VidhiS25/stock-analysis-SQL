USE stocks_proj1;

-- QUERY 1: Simple Performance Ranking (ORDER BY)

SELECT 
    ticker,
    sector,
    ROUND(MIN(price), 2) as start_price,
    ROUND(MAX(price), 2) as end_price,
    ROUND(MAX(price) - MIN(price), 2) as dollar_change,
    ROUND(((MAX(price) - MIN(price)) / MIN(price)) * 100, 2) as percent_change
FROM stocks 
GROUP BY ticker, sector
ORDER BY percent_change DESC;


-- QUERY 2: Performance Ranking with RANK() Function

WITH performance_data AS (
    SELECT 
        ticker,
        sector,
        ROUND(MIN(price), 2) as start_price,
        ROUND(MAX(price), 2) as end_price,
        ROUND(MAX(price) - MIN(price), 2) as dollar_change,
        ROUND(((MAX(price) - MIN(price)) / MIN(price)) * 100, 2) as percent_change
    FROM stocks 
    GROUP BY ticker, sector
)
SELECT 
    RANK() OVER (ORDER BY percent_change DESC) as performance_rank,
    ticker,
    sector,
    start_price,
    end_price,
    dollar_change,
    CONCAT(percent_change, '%') as percent_change
FROM performance_data
ORDER BY performance_rank;


-- QUERY 3: Sector-Based Rankings

WITH performance_data AS (
    SELECT 
        ticker,
        sector,
        ROUND(MIN(price), 2) as start_price,
        ROUND(MAX(price), 2) as end_price,
        ROUND(((MAX(price) - MIN(price)) / MIN(price)) * 100, 2) as percent_change
    FROM stocks 
    GROUP BY ticker, sector
)
SELECT 
    sector,
    RANK() OVER (PARTITION BY sector ORDER BY percent_change DESC) as sector_rank,
    RANK() OVER (ORDER BY percent_change DESC) as overall_rank,
    ticker,
    CONCAT(percent_change, '%') as percent_change
FROM performance_data
ORDER BY sector, sector_rank;


-- QUERY 4: Top 3 and Bottom 3 Performers

(
    SELECT 
        'TOP PERFORMERS' as category,
        RANK() OVER (ORDER BY ((MAX(price) - MIN(price)) / MIN(price)) * 100 DESC) as rank_position,
        ticker,
        ROUND(((MAX(price) - MIN(price)) / MIN(price)) * 100, 2) as percent_change
    FROM stocks 
    GROUP BY ticker
    ORDER BY percent_change DESC
    LIMIT 3
)
UNION ALL
(
    SELECT 
        'BOTTOM PERFORMERS' as category,
        RANK() OVER (ORDER BY ((MAX(price) - MIN(price)) / MIN(price)) * 100 ASC) as rank_position,
        ticker,
        ROUND(((MAX(price) - MIN(price)) / MIN(price)) * 100, 2) as percent_change
    FROM stocks 
    GROUP BY ticker
    ORDER BY percent_change ASC
    LIMIT 3
);


-- QUERY 5: Daily Winners and Losers

WITH daily_changes AS (
    SELECT 
        date,
        ticker,
        price,
        LAG(price) OVER (PARTITION BY ticker ORDER BY date) as prev_price,
        ROUND(
            ((price - LAG(price) OVER (PARTITION BY ticker ORDER BY date)) 
             / LAG(price) OVER (PARTITION BY ticker ORDER BY date)) * 100, 
            2
        ) as daily_percent_change
    FROM stocks
),
ranked_daily AS (
    SELECT 
        date,
        ticker,
        daily_percent_change,
        RANK() OVER (PARTITION BY date ORDER BY daily_percent_change DESC) as daily_rank
    FROM daily_changes
    WHERE daily_percent_change IS NOT NULL
)
SELECT 
    date,
    ticker,
    CONCAT(daily_percent_change, '%') as daily_change,
    CASE 
        WHEN daily_rank = 1 THEN '🏆 WINNER'
        WHEN daily_rank = 2 THEN '🥈 2nd Place'
        WHEN daily_rank = 3 THEN '🥉 3rd Place'
        ELSE CONCAT('#', daily_rank)
    END as performance_rank
FROM ranked_daily
WHERE daily_rank <= 3
ORDER BY date, daily_rank;


-- QUERY 6: Performance Tiers (Group Rankings)

WITH performance_data AS (
    SELECT 
        ticker,
        ROUND(((MAX(price) - MIN(price)) / MIN(price)) * 100, 2) as percent_change
    FROM stocks 
    GROUP BY ticker
)
SELECT 
    ticker,
    percent_change,
    CASE 
        WHEN percent_change >= 50 THEN 'HIGH PERFORMERS (50%+)'
        WHEN percent_change >= 30 THEN 'MEDIUM PERFORMERS (30-50%)'
        WHEN percent_change >= 10 THEN 'LOW PERFORMERS (10-30%)'
        ELSE 'UNDERPERFORMERS (<10%)'
    END as performance_tier,
    RANK() OVER (ORDER BY percent_change DESC) as overall_rank
FROM performance_data
ORDER BY percent_change DESC;


-- QUERY 7: Head-to-Head Comparison

SELECT 
    a.ticker as stock_a,
    b.ticker as stock_b,
    ROUND(
        ((a.max_price - a.min_price) / a.min_price) * 100 - 
        ((b.max_price - b.min_price) / b.min_price) * 100, 
        2
    ) as performance_difference
FROM (
    SELECT ticker, MIN(price) as min_price, MAX(price) as max_price
    FROM stocks GROUP BY ticker
) a
CROSS JOIN (
    SELECT ticker, MIN(price) as min_price, MAX(price) as max_price
    FROM stocks GROUP BY ticker
) b
WHERE a.ticker < b.ticker  -- Avoid duplicates
ORDER BY performance_difference DESC;
