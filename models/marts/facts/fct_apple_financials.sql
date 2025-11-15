WITH metrics AS (
    SELECT
        submission_number,
        company_name,
        central_index_key,
        period_end_date,
        fiscal_year,
        fiscal_period_focus,
        measure_tag,
        value,
        units,
        form,
        date_filed,
        date_accepted
    FROM {{ ref('stg_apple_financials') }}
),

pivoted AS (
    SELECT
        submission_number,
        company_name,
        central_index_key,
        period_end_date,
        fiscal_year,
        fiscal_period_focus,
        date_filed,
        date_accepted,
        form,
        MAX(CASE WHEN measure_tag IN ('RevenueFromContractWithCustomerExcludingAssessedTax','SalesRevenueNet') THEN value END) AS revenue,
        MAX(CASE WHEN measure_tag = 'GrossProfit' THEN value END) AS gross_profit,
        MAX(CASE WHEN measure_tag = 'NetIncomeLoss' THEN value END) AS net_income,
        MAX(CASE WHEN measure_tag = 'EarningsPerShareBasic' THEN value END) AS eps_basic,
        MAX(CASE WHEN measure_tag = 'EarningsPerShareDiluted' THEN value END) AS eps_diluted,
        MAX(CASE WHEN measure_tag = 'CommonStockDividendsPerShareDeclared' THEN value END) AS dividends_per_share
    FROM metrics
    GROUP BY
        submission_number,
        company_name,
        central_index_key,
        period_end_date,
        fiscal_year,
        fiscal_period_focus,
        date_filed,
        date_accepted,
        form
)

SELECT * FROM pivoted