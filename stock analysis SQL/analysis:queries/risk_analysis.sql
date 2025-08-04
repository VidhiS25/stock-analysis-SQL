-- Use your database
USE stocks_proj1;

-- ================================
-- QUERY 1: Basic Volatility Analysis (Standard Deviation)
-- ================================
WITH daily_returns AS (
    SELECT 
        ticker,
        date,
        price,
        LAG(price) OVER (PARTITION BY ticker ORDER BY date) as prev_price,
        ROUND(
            ((price - LAG(price) OVER (PARTITION BY ticker ORDER BY date)) 
             / LAG(price) OVER (PARTITION BY ticker ORDER BY date)) * 100, 
            4
        ) as daily_return_pct
    FROM stocks
)
SELECT 
    ticker,
    COUNT(*) - 1 as trading_days,
    ROUND(AVG(daily_return_pct), 2) as avg_daily_return,
    ROUND(STDDEV(daily_return_pct), 2) as volatility_stddev,
    ROUND(MIN(daily_return_pct), 2) as worst_day,
    ROUND(MAX(daily_return_pct), 2) as best_day,
    ROUND(MAX(daily_return_pct) - MIN(daily_return_pct), 2) as return_range,
    CASE 
        WHEN STDDEV(daily_return_pct) > 3 THEN '🌪️ HIGH RISK'
        WHEN STDDEV(daily_return_pct) > 1.5 THEN '⚠️ MODERATE RISK'
        ELSE '😴 LOW RISK'
    END as risk_category
FROM daily_returns 
WHERE daily_return_pct IS NOT NULL
GROUP BY ticker
ORDER BY volatility_stddev DESC;

-- ================================
-- QUERY 2: Risk-Adjusted Performance (Sharpe-like Ratio)
-- ================================
WITH daily_returns AS (
    SELECT 
        ticker,
        ROUND(
            ((price - LAG(price) OVER (PARTITION BY ticker ORDER BY date)) 
             / LAG(price) OVER (PARTITION BY ticker ORDER BY date)) * 100, 
            4
        ) as daily_return_pct
    FROM stocks
),
risk_metrics AS (
    SELECT 
        ticker,
        ROUND(AVG(daily_return_pct), 4) as avg_daily_return,
        ROUND(STDDEV(daily_return_pct), 4) as volatility
    FROM daily_returns 
    WHERE daily_return_pct IS NOT NULL
    GROUP BY ticker
)
SELECT 
    RANK() OVER (ORDER BY (avg_daily_return / volatility) DESC) as risk_adj_rank,
    ticker,
    CONCAT(avg_daily_return, '%') as avg_daily_return,
    CONCAT(volatility, '%') as volatility,
    ROUND(avg_daily_return / volatility, 2) as risk_adjusted_ratio,
    CASE 
        WHEN (avg_daily_return / volatility) > 0.5 THEN '⭐ EXCELLENT'
        WHEN (avg_daily_return / volatility) > 0.2 THEN '👍 GOOD'
        WHEN (avg_daily_return / volatility) > 0 THEN '👌 FAIR'
        ELSE '⚠️ POOR'
    END as risk_rating
FROM risk_metrics
WHERE volatility > 0
ORDER BY risk_adjusted_ratio DESC;

-- ================================
-- QUERY 3: Rolling Volatility (30-Day Moving Window)
-- ================================
WITH daily_returns AS (
    SELECT 
        ticker,
        date,
        ROUND(
            ((price - LAG(price) OVER (PARTITION BY ticker ORDER BY date)) 
             / LAG(price) OVER (PARTITION BY ticker ORDER BY date)) * 100, 
            4
        ) as daily_return_pct
    FROM stocks
),
rolling_volatility AS (
    SELECT 
        ticker,
        date,
        daily_return_pct,
        ROUND(
            STDDEV(daily_return_pct) OVER (
                PARTITION BY ticker 
                ORDER BY date 
                ROWS BETWEEN 9 PRECEDING AND CURRENT ROW
            ), 2
        ) as rolling_10day_volatility
    FROM daily_returns
    WHERE daily_return_pct IS NOT NULL
)
SELECT 
    ticker,
    date,
    daily_return_pct,
    rolling_10day_volatility,
    CASE 
        WHEN rolling_10day_volatility > 2 THEN '🔥 HIGH VOLATILITY PERIOD'
        WHEN rolling_10day_volatility > 1 THEN '📊 NORMAL VOLATILITY'
        ELSE '😴 CALM PERIOD'
    END as volatility_status
FROM rolling_volatility
WHERE rolling_10day_volatility IS NOT NULL
ORDER BY ticker, date;

-- ================================
-- QUERY 4: Downside Risk Analysis (Focus on Losses)
-- ================================
WITH daily_returns AS (
    SELECT 
        ticker,
        date,
        ROUND(
            ((price - LAG(price) OVER (PARTITION BY ticker ORDER BY date)) 
             / LAG(price) OVER (PARTITION BY ticker ORDER BY date)) * 100, 
            2
        ) as daily_return_pct
    FROM stocks
),
downside_analysis AS (
    SELECT 
        ticker,
        daily_return_pct
    FROM daily_returns
    WHERE daily_return_pct < 0  -- Only negative returns
)
SELECT 
    ticker,
    COUNT(*) as down_days,
    ROUND(AVG(daily_return_pct), 2) as avg_loss_per_down_day,
    ROUND(MIN(daily_return_pct), 2) as worst_single_day,
    ROUND(STDDEV(daily_return_pct), 2) as downside_volatility,
    ROUND(
        (SELECT COUNT(*) FROM daily_returns dr WHERE dr.ticker = downside_analysis.ticker AND dr.daily_return_pct IS NOT NULL) 
        / COUNT(*) * 100, 1
    ) as down_day_frequency_pct
FROM downside_analysis
GROUP BY ticker
ORDER BY worst_single_day ASC;

-- ================================
-- QUERY 5: Value at Risk (VaR) Simulation
-- ================================
WITH daily_returns AS (
    SELECT 
        ticker,
        ROUND(
            ((price - LAG(price) OVER (PARTITION BY ticker ORDER BY date)) 
             / LAG(price) OVER (PARTITION BY ticker ORDER BY date)) * 100, 
            2
        ) as daily_return_pct
    FROM stocks
),
percentile_analysis AS (
    SELECT 
        ticker,
        daily_return_pct,
        PERCENT_RANK() OVER (PARTITION BY ticker ORDER BY daily_return_pct) as percentile_rank
    FROM daily_returns
    WHERE daily_return_pct IS NOT NULL
)
SELECT 
    ticker,
    ROUND(MIN(CASE WHEN percentile_rank >= 0.05 THEN daily_return_pct END), 2) as var_5_percent,
    ROUND(MIN(CASE WHEN percentile_rank >= 0.01 THEN daily_return_pct END), 2) as var_1_percent,
    CONCAT('95% chance daily loss will not exceed ', 
           ABS(ROUND(MIN(CASE WHEN percentile_rank >= 0.05 THEN daily_return_pct END), 2)), '%') as var_interpretation
FROM percentile_analysis
GROUP BY ticker
ORDER BY var_5_percent ASC;

-- ================================
-- QUERY 6: Comprehensive Risk Dashboard
-- ================================
WITH daily_returns AS (
    SELECT 
        ticker,
        date,
        price,
        ROUND(
            ((price - LAG(price) OVER (PARTITION BY ticker ORDER BY date)) 
             / LAG(price) OVER (PARTITION BY ticker ORDER BY date)) * 100, 
            4
        ) as daily_return_pct
    FROM stocks
),
risk_metrics AS (
    SELECT 
        ticker,
        COUNT(*) - 1 as trading_days,
        ROUND(AVG(daily_return_pct), 2) as avg_return,
        ROUND(STDDEV(daily_return_pct), 2) as volatility,
        ROUND(MIN(daily_return_pct), 2) as max_drawdown,
        ROUND(MAX(daily_return_pct), 2) as max_gain,
        SUM(CASE WHEN daily_return_pct < 0 THEN 1 ELSE 0 END) as down_days,
        ROUND(AVG(CASE WHEN daily_return_pct < 0 THEN daily_return_pct END), 2) as avg_loss
    FROM daily_returns 
    WHERE daily_return_pct IS NOT NULL
    GROUP BY ticker
)
SELECT 
    RANK() OVER (ORDER BY volatility DESC) as risk_rank,
    ticker,
    CONCAT(avg_return, '%') as avg_daily_return,
    CONCAT(volatility, '%') as volatility,
    ROUND(avg_return / volatility, 2) as sharpe_ratio,
    CONCAT(max_drawdown, '%') as worst_day,
    CONCAT(max_gain, '%') as best_day,
    ROUND((down_days::float / trading_days) * 100, 1) as down_day_percentage,
    CASE 
        WHEN volatility > 3 THEN '🔴 VERY HIGH RISK'
        WHEN volatility > 2 THEN '🟡 HIGH RISK'
        WHEN volatility > 1 THEN '🟢 MODERATE RISK'
        ELSE '🔵 LOW RISK'
    END as risk_classification
FROM risk_metrics
ORDER BY volatility DESC;

-- ================================
-- QUERY 7: Correlation Risk Analysis (How Stocks Move Together)
-- ================================
WITH daily_returns AS (
    SELECT 
        date,
        ticker,
        ROUND(
            ((price - LAG(price) OVER (PARTITION BY ticker ORDER BY date)) 
             / LAG(price) OVER (PARTITION BY ticker ORDER BY date)) * 100, 
            4
        ) as daily_return_pct
    FROM stocks
),
return_pairs AS (
    SELECT 
        a.date,
        a.ticker as stock_a,
        b.ticker as stock_b,
        a.daily_return_pct as return_a,
        b.daily_return_pct as return_b
    FROM daily_returns a
    JOIN daily_returns b ON a.date = b.date AND a.ticker < b.ticker
    WHERE a.daily_return_pct IS NOT NULL AND b.daily_return_pct IS NOT NULL
)
SELECT 
    stock_a,
    stock_b,
    COUNT(*) as shared_trading_days,
    ROUND(
        (COUNT(*) * SUM(return_a * return_b) - SUM(return_a) * SUM(return_b)) /
        SQRT(
            (COUNT(*) * SUM(return_a * return_a) - SUM(return_a) * SUM(return_a)) *
            (COUNT(*) * SUM(return_b * return_b) - SUM(return_b) * SUM(return_b))
        ), 3
    ) as correlation,
    CASE 
        WHEN (COUNT(*) * SUM(return_a * return_b) - SUM(return_a) * SUM(return_b)) /
        SQRT(
            (COUNT(*) * SUM(return_a * return_a) - SUM(return_a) * SUM(return_a)) *
            (COUNT(*) * SUM(return_b * return_b) - SUM(return_b) * SUM(return_b))
        ) > 0.7 THEN '🔗 HIGHLY CORRELATED'
        WHEN (COUNT(*) * SUM(return_a * return_b) - SUM(return_a) * SUM(return_b)) /
        SQRT(
            (COUNT(*) * SUM(return_a * return_a) - SUM(return_a) * SUM(return_a)) *
            (COUNT(*) * SUM(return_b * return_b) - SUM(return_b) * SUM(return_b))
        ) > 0.3 THEN '📊 MODERATELY CORRELATED'
        ELSE '🔀 LOW CORRELATION'
    END as correlation_strength
FROM return_pairs
GROUP BY stock_a, stock_b
ORDER BY correlation DESC;