/* =====================================================================
   SOLUTION — Module 4 & 5 : Star schema + risk score (+ ranking)
   ---------------------------------------------------------------------
   Pattern shown: #5 again, window-equivalent ranking via PROC RANK.
   Produces dim_customer, dim_country, dim_date, fact_kyc_review (grain =
   one KYC review) and exports them to CSV for Power BI.
   ===================================================================== */

/* ---- DIM_CUSTOMER (surrogate key via _N_) -------------------------- */
data dim_customer;
    set cust_enriched;
    customer_sk = _n_;
run;

/* ---- DIM_COUNTRY (reference + an "Unknown" row for orphans) -------- */
data dim_country;
    set country_ref;
    country_sk = _n_;
run;

proc sql;
    insert into dim_country
        set country_sk   = (select max(country_sk) + 1 from dim_country),
            country_code = 'XX',
            country_name = 'Unknown',
            region       = 'Unknown',
            fatf_status  = 'Unmapped',
            risk_weight  = 4,
            embargo_flag = 'N';
quit;

/* ---- DIM_DATE -----------------------------------------------------
   NB: PROC IMPORT reads the ISO dates (YYYY-MM-DD) as SAS dates (numeric).     */
proc sql;
    create table review_dates as
    select distinct review_date from raw_kyc_reviews;
quit;

data dim_date;
    set review_dates;
    date_sk    = _n_;
    year       = year(review_date);
    quarter    = qtr(review_date);
    month      = month(review_date);
    month_name = put(review_date, monname3.);
    format review_date date9.;
run;

/* ---- FACT_KYC_REVIEW : grain = one KYC review ----------------------
   Resolve the surrogate keys by joining onto the dimensions.                   */
proc sql;
    create table fact_stage as
    select
        k.review_id,
        k.review_date,
        k.review_status,
        k.document_verified,
        k.alert_count,
        c.customer_sk,
        c.country_code,
        c.pep_flag,
        c.risk_weight,
        c.embargo_flag,
        dc.country_sk,
        dd.date_sk
    from raw_kyc_reviews as k
    inner join dim_customer as c on k.customer_id  = c.customer_id
    left  join dim_country  as dc on c.country_code = dc.country_code
    left  join dim_date     as dd on k.review_date  = dd.review_date;
quit;

/* ---- Risk score (Module 5) ----------------------------------------
   IMPORTANT: use ASSIGNMENT (=), NOT the SAS sum statement `var + expr;`
   which would ACCUMULATE across rows (a classic bug).                          */
data fact_kyc_review;
    set fact_stage;
    risk_score = risk_weight * 10;                       /* country weight */
    if pep_flag = 'Y'      then risk_score = risk_score + 20;
    risk_score = risk_score + alert_count * 8;
    if embargo_flag = 'Y'  then risk_score = max(risk_score, 80);  /* floor rule */
    risk_score = min(risk_score, 100);                   /* bound 0..100 */

    length risk_category $8;
    if      risk_score >= 80 then risk_category = 'Critical';
    else if risk_score >= 60 then risk_category = 'High';
    else if risk_score >= 30 then risk_category = 'Medium';
    else                          risk_category = 'Low';

    keep review_id customer_sk country_sk date_sk country_code
         review_status document_verified alert_count risk_score risk_category;
run;

/* ---- risk_rank : pattern #5 (window-equivalent) via PROC RANK ------
   ANSI: RANK() OVER (PARTITION BY country_code ORDER BY risk_score DESC).
   ties=low reproduces ANSI RANK() (same rank on ties, gaps after).             */
proc sort data=fact_kyc_review; by country_code; run;

proc rank data=fact_kyc_review out=fact_kyc_review descending ties=low;
    by country_code;
    var risk_score;
    ranks risk_rank;            /* 1 = highest-risk review within the country */
run;

/* ---- Export for Power BI ------------------------------------------ */
%let OUT = &DATA/output;     /* create this folder in SAS OnDemand first */
proc export data=dim_customer    outfile="&OUT/dim_customer.csv"    dbms=csv replace; run;
proc export data=dim_country     outfile="&OUT/dim_country.csv"     dbms=csv replace; run;
proc export data=dim_date        outfile="&OUT/dim_date.csv"        dbms=csv replace; run;
proc export data=fact_kyc_review outfile="&OUT/fact_kyc_review.csv" dbms=csv replace; run;
