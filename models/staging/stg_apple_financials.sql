{{ config(
    materialized='view'
) }}

WITH base AS (
    SELECT
        submission_number,
        company_name,
        central_index_key,
        measure_tag,
        PARSE_DATE('%Y%m%d', CAST(period_end_date AS STRING)) AS period_end_date,
        CAST(value AS FLOAT64) AS value,
        UPPER(units) AS units,
        number_of_quarters,
        fiscal_year,
        fiscal_period_focus,
        -- Safe handling for date_filed
        CASE
            WHEN SAFE_CAST(date_filed AS STRING) LIKE '________' THEN PARSE_DATE('%Y%m%d', CAST(date_filed AS STRING))
            ELSE DATE(SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S%Ez', CAST(date_filed AS STRING)))
        END AS date_filed,
        -- Safe handling for date_accepted
        CASE
            WHEN SAFE_CAST(date_accepted AS STRING) LIKE '________' THEN PARSE_DATE('%Y%m%d', CAST(date_accepted AS STRING))
            ELSE DATE(SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S%Ez', CAST(date_accepted AS STRING)))
        END AS date_accepted,
        form
    FROM {{ source('apple', 'apple_financials_raw') }}
),

-- Remove rows with null critical values
cleaned AS (
    SELECT *
    FROM base
    WHERE value IS NOT NULL
      AND period_end_date IS NOT NULL
      AND form IN ('10-Q', '10-K')
),

-- Standardize form to report_type
standardized AS (
    SELECT *,
        CASE 
            WHEN form = '10-Q' THEN 'quarterly'
            WHEN form = '10-K' THEN 'annual'
            ELSE 'other'
        END AS report_type,
        EXTRACT(YEAR FROM period_end_date) AS report_year,
        EXTRACT(QUARTER FROM period_end_date) AS report_quarter
    FROM cleaned
),

-- Remove duplicates keeping latest accepted date
deduped AS (
    SELECT *
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY central_index_key, period_end_date 
                   ORDER BY date_accepted DESC
               ) AS row_num
        FROM standardized
    )
    WHERE row_num = 1
)

SELECT
    submission_number,
    company_name,
    central_index_key,
    measure_tag,
    period_end_date,
    value,
    units,
    number_of_quarters,
    fiscal_year,
    fiscal_period_focus,
    date_filed,
    date_accepted,
    form,
    report_type,
    report_year,
    report_quarter
FROM deduped
ORDER BY period_end_date DESC
