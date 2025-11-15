{{ config(
    materialized='table'
) }}

WITH financials AS (
    SELECT * FROM {{ ref('fct_apple_financials') }}
),

with_calculations AS (
    SELECT
        *,
        -- Profitability Ratios
        ROUND(SAFE_DIVIDE(gross_profit, revenue) * 100, 2) AS gross_margin_pct,
        ROUND(SAFE_DIVIDE(net_income, revenue) * 100, 2) AS net_margin_pct,
        
        -- Period-over-period comparisons
        LAG(revenue) OVER (ORDER BY period_end_date) AS prev_period_revenue,
        LAG(net_income) OVER (ORDER BY period_end_date) AS prev_period_net_income,
        LAG(eps_diluted) OVER (ORDER BY period_end_date) AS prev_period_eps,
        
        -- Growth rates (period-over-period)
        ROUND(SAFE_DIVIDE(
            revenue - LAG(revenue) OVER (ORDER BY period_end_date),
            LAG(revenue) OVER (ORDER BY period_end_date)
        ) * 100, 2) AS revenue_growth_pct,
        
        ROUND(SAFE_DIVIDE(
            net_income - LAG(net_income) OVER (ORDER BY period_end_date),
            LAG(net_income) OVER (ORDER BY period_end_date)
        ) * 100, 2) AS net_income_growth_pct,
        
        ROUND(SAFE_DIVIDE(
            eps_diluted - LAG(eps_diluted) OVER (ORDER BY period_end_date),
            LAG(eps_diluted) OVER (ORDER BY period_end_date)
        ) * 100, 2) AS eps_growth_pct,
        
        -- 4-quarter trailing averages
        ROUND(AVG(revenue) OVER (
            ORDER BY period_end_date 
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        ), 2) AS revenue_4q_avg,
        
        ROUND(AVG(net_income) OVER (
            ORDER BY period_end_date 
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        ), 2) AS net_income_4q_avg,
        
        -- Year-over-year comparison (4 periods back for quarterly data)
        LAG(revenue, 4) OVER (ORDER BY period_end_date) AS revenue_yoy_prev,
        ROUND(SAFE_DIVIDE(
            revenue - LAG(revenue, 4) OVER (ORDER BY period_end_date),
            LAG(revenue, 4) OVER (ORDER BY period_end_date)
        ) * 100, 2) AS revenue_yoy_growth_pct
        
    FROM financials
)

SELECT * FROM with_calculations
ORDER BY period_end_date DESC