/* =====================================================================
   Module 4 & 5 -- Star schema + risk score in SAS
   ---------------------------------------------------------------------
   SKELETON TO COMPLETE. Produce dim_customer, dim_country, dim_date and
   fact_kyc_review (grain = one KYC review), with surrogate keys.
   ===================================================================== */

/* ---- DIM_CUSTOMER: surrogate key via _N_ in a DATA step ------------ */
data dim_customer;
    set cust_enriched;
    customer_sk = _N_;            /* technical surrogate key 1..N */
    /* TODO: keep customer_id (business key) + attributes + customer_sk */
run;

/* ---- DIM_COUNTRY: from the reference (+ an Unknown row) ------------- */
data dim_country;
    set country_ref end=last;
    country_sk = _N_;
    output;
    /* TODO: add an "XX / Unknown" row for orphan countries
       if last then do; country_code='XX'; country_name='Unknown'; ... output; end; */
run;

/* ---- DIM_DATE ------------------------------------------------------
   TODO: from the distinct review dates, derive year/quarter/month.
   Hint: PROC SQL select distinct review_date, then a DATA step with
   year(), qtr(), month(), put(date, monname3.) + date_sk = _N_.              */

/* ---- FACT_KYC_REVIEW: grain = one KYC review ----------------------- */
proc sql;
    create table fact_stage as
    select
        k.review_id,
        k.review_date,
        k.review_status,
        k.document_verified,
        k.alert_count,
        c.customer_sk,
        c.risk_weight,
        c.pep_flag,
        c.embargo_flag
        /* TODO: attach country_sk and date_sk via joins on the dimensions */
    from kyc_reviews as k
    left join dim_customer as c
        on k.customer_id = c.customer_id
    ;
quit;

/* ---- Risk score (Module 5) ----------------------------------------- */
data fact_kyc_review;
    set fact_stage;
    /* TODO: define your weighting. Example structure:
       risk_score = 0;
       risk_score + (risk_weight * 10);
       if pep_flag='Y'        then risk_score + 20;
       risk_score + (alert_count * 8);
       if embargo_flag='Y'    then risk_score = max(risk_score, 80);  * floor ;
       risk_score = min(risk_score, 100);

       length risk_category $8;
       if      risk_score >= 80 then risk_category='Critical';
       else if risk_score >= 60 then risk_category='High';
       else if risk_score >= 30 then risk_category='Medium';
       else                          risk_category='Low';
    */
    /* TODO: keep only SKs + measures (drop the working columns) */
run;

/* ---- risk_rank: SQL pattern #5 (window function), the SAS way ------
   ANSI: RANK() OVER (PARTITION BY country_code ORDER BY risk_score DESC).
   PROC SQL has NO OVER(). SAS idiom = PROC RANK with a BY group:               */
proc sort data=fact_kyc_review; by country_code; run;   /* needs the country on the fact */
proc rank data=fact_kyc_review out=fact_kyc_review descending;
    by country_code;
    var risk_score;
    ranks risk_rank;       /* 1 = highest-risk customer within the country */
run;

/* ---- Export for Power BI ------------------------------------------- */
%let OUT = /home/your-id/kyc/output;   /* <- adapt */
proc export data=dim_customer    outfile="&OUT/dim_customer.csv"    dbms=csv replace; run;
proc export data=dim_country     outfile="&OUT/dim_country.csv"     dbms=csv replace; run;
/* proc export data=dim_date ... ; */
proc export data=fact_kyc_review outfile="&OUT/fact_kyc_review.csv" dbms=csv replace; run;
