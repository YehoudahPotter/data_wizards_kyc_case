# Module 6 - Power BI: data model, metric, dashboard

This step turns your tables (pipeline outputs) into an exploitable **semantic
model**, then into a **mini dashboard**. This is exactly the reporting deliverable
expected in Risk/Compliance functions.

## Prerequisites

- **Power BI Desktop** (free, Windows).
- The 4 CSV files produced by your SAS pipeline (Module 5 `PROC EXPORT`):
  `dim_customer.csv`, `dim_country.csv`, `dim_date.csv`, `fact_kyc_review.csv`.

> **Get them out of SAS first.** `PROC EXPORT` writes these to your SAS OnDemand
> folder (`&DATA/output`), which lives in the **cloud**. Power BI runs on your
> **local** machine, so download them: in SAS Studio → **Server Files and Folders**
> → open your `output` folder → right-click each CSV → **Download**.

> No Power BI at hand? You can do the equivalent in Excel (Power Pivot) or describe
> the model + the DAX measure in your note. What matters is **understanding** the
> semantic model and the measure logic.

## Step 1 - Import the tables

`Home > Get Data > Text/CSV` → import the 4 files. Check the column **types**
(the SKs must be **whole numbers**, the dates **Date**).

## Step 2 - Build the star (the relationships)

Go to the **Model** view and create the relationships (drag a fact SK onto the
dimension SK):

| From the fact (many) | To the dimension (one) |
|---|---|
| `fact_kyc_review[customer_sk]` | `dim_customer[customer_sk]` |
| `fact_kyc_review[country_sk]` | `dim_country[country_sk]` |
| `fact_kyc_review[date_sk]` | `dim_date[date_sk]` |

Cardinality **many-to-one** (`*` → `1`), filter direction **single** (from the
dimension to the fact). You get a visual **star**.

## Step 3 - Create a DAX measure (the KPI)

`Modeling > New measure`. Main requested measure - **high-risk customer rate**:

```dax
High Risk Customer Rate =
DIVIDE (
    CALCULATE (
        DISTINCTCOUNT ( fact_kyc_review[customer_sk] ),
        fact_kyc_review[risk_category] IN { "High", "Critical" }
    ),
    DISTINCTCOUNT ( fact_kyc_review[customer_sk] )
)
```

Format it as a **percentage**. A few useful complementary measures:

```dax
Review Count    = COUNTROWS ( fact_kyc_review )
PEP Customers   = CALCULATE ( DISTINCTCOUNT ( fact_kyc_review[customer_sk] ),
                              dim_customer[pep_flag] = "Y" )
Avg Risk Score  = AVERAGE ( fact_kyc_review[risk_score] )
```

> **Measure vs calculated column**: here you want a value that **reacts to the
> dashboard filters** (by country, by month…) → it is a **measure**, not a column.
> (See the question of Module 6.)

## Step 4 - The dashboard page

Compose a simple, readable page:

1. **Card (KPI)**: `High Risk Customer Rate`.
2. **Bar chart**: `Avg Risk Score` by `dim_country[region]` or `fatf_status`.
3. **Pie / stacked bar**: distribution of reviews by `risk_category`.
4. **Slicer**: on `dim_date[year]` and/or `dim_country[fatf_status]`.
5. **Table**: top customers by `risk_score` (with `pep_flag`, country).

Check that clicking a country/slicer **filters all visuals** - this proves your
star schema and relationships are correct.

## What is assessed

- The **relationships** are on the surrogate keys, in the right direction.
- **At least one** correct and formatted DAX measure.
- The dashboard answers **business questions** (not just "pretty").
- Interactivity (slicers / cross-filtering) works.
