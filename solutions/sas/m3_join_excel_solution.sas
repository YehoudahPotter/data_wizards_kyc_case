/* =====================================================================
   SOLUTION — Module 3 : Join with the Excel country reference
   ---------------------------------------------------------------------
   Patterns shown: #2 INNER JOIN, #3 LEFT JOIN.
   Depends on stg_customers (from m1-2_extract_clean_solution.sas).
   ===================================================================== */

/* ---- 1. Import the Compliance reference (Excel) -------------------- */
proc import datafile="&DATA/country_risk_reference.xlsx"
    out=country_ref dbms=xlsx replace;
    sheet="Country_Reference";
    getnames=yes;
run;

/* ---- 2. INNER vs LEFT comparison (patterns #2 & #3) ----------------
   The whole point: INNER silently drops the unmatched customers.               */
proc sql;
    /* INNER JOIN -> only matched customers. Expected: 419 */
    select count(*) as n_inner
    from stg_customers as c
    inner join country_ref as r on c.country_code = r.country_code;

    /* LEFT JOIN -> all customers. Expected: 500  (=> 81 orphans) */
    select count(*) as n_left
    from stg_customers as c
    left join country_ref as r on c.country_code = r.country_code;
quit;

/* ---- 3. Keep the LEFT JOIN (never lose a customer) ----------------- */
proc sql;
    create table cust_enriched as
    select
        c.*,
        r.fatf_status,
        r.risk_weight,
        r.embargo_flag
    from stg_customers as c
    left join country_ref as r
        on c.country_code = r.country_code;
quit;

/* ---- 4. Handle the orphans (precautionary principle) --------------
   Expected: 81 orphans -> XX:35, CN:26, BR:20.
   Policy: cautious DEFAULT weight (4) + a traceable data-quality flag.         */
data cust_enriched;
    set cust_enriched;
    length data_quality_flag $16;
    if missing(risk_weight) then do;
        risk_weight       = 4;                 /* high-ish default, NOT low */
        fatf_status       = 'Unmapped';
        if missing(embargo_flag) then embargo_flag = 'N';
        data_quality_flag = 'UNMAPPED_COUNTRY';
    end;
    else data_quality_flag = 'OK';
run;
