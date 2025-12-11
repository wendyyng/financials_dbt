#  Apple Inc. Financial Data Pipeline

An end-to-end data pipeline that extracts, transforms, and visualizes Apple’s SEC financial filing data using modern data stack tools.

[![dbt](https://img.shields.io/badge/dbt-FF694B?style=flat&logo=dbt&logoColor=white)](https://www.getdbt.com/)
[![BigQuery](https://img.shields.io/badge/BigQuery-4285F4?style=flat&logo=google-cloud&logoColor=white)](https://cloud.google.com/bigquery)
[![Looker](https://img.shields.io/badge/Looker-4285F4?style=flat&logo=looker&logoColor=white)](https://lookerstudio.google.com/)

---

## Overview

This project implements a production-style data pipeline to clean, model, and analyze Apple’s SEC financial data. It follows modern data engineering best practices, including a three-layer warehouse architecture, automated transformations, data quality testing, and dashboard visualization.

---

## Tech Stack

| Component          | Technology        |
|-------------------|-------------------|
| Data Warehouse     | Google BigQuery   |
| Transformation     | dbt Cloud         |
| Visualization      | Looker Studio     |
| Version Control    | Git / GitHub      |
| Testing            | dbt tests         |
| Data Source        | SEC EDGAR dataset |

---

##  Architecture
```
SEC filings (BigQuery public dataset)
    ↓
Staging Layer: cleaning & standardization
    ↓
Marts Layer: business logic & pivoting
    ↓
Analytics Layer: KPI calculations
    ↓
Looker Studio Dashboard
```

## Data Flow Summary

| Layer        | Input Rows | Output Rows | Purpose                             |
|--------------|-------------|-------------|-------------------------------------|
| Raw Data     | 254         | –           | Original SEC financial data         |
| Staging      | 254         | 160         | Cleaning, filtering, deduplication  |
| Marts        | 160         | 16          | Pivoted financial metrics           |
| Analytics    | 16          | 16 + KPIs   | KPI and ratio calculations          |

---

##  Project Structure
```
financials_dbt/
├── models/
│   ├── staging/
│   │   ├── stg_apple_financials.sql      
│   │   └── sources.yml                    
│   ├── marts/
│   │   └── facts/
│   │       ├── fct_apple_financials.sql   
│   │       └── schema.yml                 
│   └── intermediate/
│       ├── int_financial_ratios.sql       
│       └── schema.yml                    
├── dbt_project.yml                       
├── packages.yml                          
└── README.md
```

---

## Data Transformation Pipeline

### 1. Staging Layer: `stg_apple_financials`

**Purpose:**
Cleaning and standardizing the raw SEC data.

**Transformations performed:**
- Convert date formats: `20200930` (integer) → `2020-09-30` (DATE type)
- Remove NULL values and invalid records
- Filter to only include quarterly and annual SEC filings (10-Q and 10-K)
- Remove duplicated reporting periods (prioritizing 10-Q over 10-K)
- Extract fiscal year and quarter information

**Key logic:**
```sql
-- Deduplication: ensure one row per period and metric
ROW_NUMBER() OVER (
    PARTITION BY period_end_date, measure_tag
    ORDER BY 
        CASE WHEN form = '10-Q' THEN 1 ELSE 2 END,
        date_accepted DESC
)
```

**Output:** 160 clean, unique rows representing period–metric combinations.

---

### 2. Marts Layer: `fct_apple_financials`

**Purpose:**  
Transform long-format financial metrics into a wide-format table suitable for business use.

**Transformations performed:**
- Pivot metric tags into columns  
- Output one row per financial reporting period  
- Include key metrics: revenue, gross profit, net income, EPS, dividends  

**Before (long format):**
```
period_end_date | measure_tag         | value
2020-09-30      | NetIncomeLoss      | 12,673,000,000
2020-09-30      | Revenue...         | 64,698,000,000
2020-09-30      | GrossProfit        | 24,689,000,000
```

**After (wide format):**
```
period_end_date | revenue        | gross_profit   | net_income
2020-09-30      | 64,698,000,000 | 24,689,000,000 | 12,673,000,000
```

**Output:**  
16 rows (one per financial period)

---

### Analytics Layer: `int_financial_ratios`

**Purpose:**  
Compute business KPIs and growth indicators.

**Calculated Metrics:**
- **Profitability:** gross margin %, net margin %  
- **Growth rates:** sequential growth  
- **Year-over-year (YoY):** comparison with the same period 4 quarters prior  
- **Trend analysis:** 4-quarter moving averages  

**Key formulas:**
```sql
-- Gross margin percentage
gross_margin_pct = (gross_profit / revenue) * 100

-- Sequential growth rate
revenue_growth_pct = ((current_revenue - previous_revenue) / previous_revenue) * 100

-- Year-over-year growth rate
revenue_yoy_growth_pct = ((current_revenue - revenue_4q_ago) / revenue_4q_ago) * 100
```

**Output:**  
16 rows, each containing 20+ calculated financial KPIs.

---

##  Key Metrics and KPIs

### Financial Metrics
- **Revenue:** total sales per period  
- **Gross Profit:** profit after subtracting cost of goods sold  
- **Net Income:** profit after all expenses  
- **EPS (diluted):** earnings per share  
- **Dividends:** dividend declared per share  

### Ratio & Trend Metrics
- **Gross Margin %:** product-level profitability  
- **Net Margin %:** overall profitability  
- **Revenue Growth %:** sequential (period-over-period) growth  
- **Year-over-Year (YoY) Growth %:** comparison with the same period one year earlier  
- **4Q Moving Average:** smoothed quarterly trend across four periods  

---

## Dashboard Highlights

### Executive View
- **Scorecards:** latest quarter’s revenue, net income, and EPS  
- **Revenue Trend:** quarterly revenue line chart (2019–2020)  
- **Profitability Analysis:** trends in gross margin % and net margin %  

### Growth Analysis
- **Sequential Growth:** quarter-over-quarter revenue growth rates  
- **YoY Comparison:** year-over-year revenue growth  
- **Performance Table:** detailed financial metrics across all reporting periods  

**[Dashboard →](https://lookerstudio.google.com/reporting/067044c7-111f-4560-97ff-6bb1bedee721)**
---

##  Setup Instructions

### Prerequisites
- Google Cloud account with BigQuery enabled  
- dbt Cloud account (or dbt Core 1.0+)  
- Access to SEC dataset in BigQuery  

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/wendyyng/financials_dbt.git
cd financials_dbt
```

2. **Install dbt packages**
```bash
dbt deps
```

3. **Set up the BigQuery connection**
   - Configure the connection in dbt Cloud or in `profiles.yml`
   - Verify access permissions to the source dataset

4. **Run the pipeline**
```bash
# Run all models
dbt run

# Run tests
dbt test

# Generate documentation
dbt docs generate
```

---

##  Data Quality and Testing

### Implemented Tests
-  **Not Null:** Ensures required fields contain valid values
-  **Unique combinations:** Ensures reporting periods are not duplicated
-  **Referential integrity:** Validates correct lineage and model dependencies

### Test Results
```bash
$ dbt test
Done. PASS=5 WARN=0 ERROR=0 SKIP=0 TOTAL=5
```

**All tests passed **

---

##  Sample Queries

### Query 1: Latest Quarterly Performance
```sql
SELECT 
  period_end_date,
  ROUND(revenue / 1000000000, 2) as revenue_billions,
  ROUND(net_income / 1000000000, 2) as net_income_billions,
  gross_margin_pct,
  net_margin_pct
FROM `finance-pipeline-demo.dbt_wng.int_financial_ratios`
ORDER BY period_end_date DESC
LIMIT 1;
```

### Query 2: Year-over-Year Growth Rate
```sql
SELECT 
  period_end_date,
  ROUND(revenue / 1000000000, 2) as revenue_billions,
  revenue_growth_pct as sequential_growth,
  revenue_yoy_growth_pct as yoy_growth
FROM `finance-pipeline-demo.dbt_wng.int_financial_ratios`
WHERE revenue_yoy_growth_pct IS NOT NULL
ORDER BY period_end_date DESC;
```

---

##  Demonstrated Skills

### Technical Skills
- **SQL:** complex transformations, window functions, CTEs, pivoting
- **Data Modeling:** dimensional modeling, fact/dimension structures
- **BigQuery:** warehousing, query optimization, partitioning
- **dbt:** medallion architecture, testing framework, documentation, Jinja templating
- **Data Quality:** deduplication strategies, validation, integrity checks

### Business Skills
- **Financial Analysis:** understanding SEC filings and financial statements
- **KPI Development:** designing meaningful business metrics
- **Data Storytelling:** converting data into actionable insights

### Engineering Practices
- **Version Control:** Git workflows, meaningful commits, documentation
- **Testing:** comprehensive data quality checks
- **Documentation:** self-documenting code, README, inline comments

---

##  Key Learnings and Challenges

### Challenges Addressed
1. **Duplicate reporting periods:** SEC filings include historical comparisons, requiring intelligent deduplication
2. **Multiple filing formats:** variations in financial statements required structural normalization
3. **Inconsistent formats:** handling mixed date formats and NULL values
4. **Metric calculations:** implementing correct window functions for growth metrics

### Best Practices Implemented
-  Three-layer architecture (Staging → Marts → Analytics)
-  Layer-specific testing for data quality
-  Clear documentation and code comments
-  Idempotent transformation logic
-  Precomputed metrics to improve dashboard performance
  
---

##  Results and Impact

-  **16 quarters** of clean, analysis-ready financial data
-  **100% dbt test pass rate**across 5 data quality tests
-  **Zero duplicated records** after applying deduplication logic
-  **Automated lineage documentation** generated through dbt
---

##  Links

- **Dashboard:** [Looker Studio](https://lookerstudio.google.com/reporting/067044c7-111f-4560-97ff-6bb1bedee721)
- **dbt Docs:** [View Documentation](https://wendyyng.github.io/financials_dbt/#!/overview)
- **Source Data:** [SEC EDGAR Database](https://www.sec.gov/edgar)

---
