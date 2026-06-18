/* =====================================================================
   Module 3 -- Join STG_CUSTOMERS <-> Excel reference (country risk)
   ---------------------------------------------------------------------
   SKELETON TO COMPLETE. The heart of the case: enrich each customer with the
   country risk profile via a LEFT JOIN, and handle orphan customers.
   ===================================================================== */

%let DATA = /home/your-id/kyc;   /* <- adapt (same folder as 01) */

/* ---- 1. Import the Excel reference ---------------------------------
   Option A (PROC IMPORT):                                                    */
proc import datafile="&DATA/country_risk_reference.xlsx"
    out=country_ref dbms=xlsx replace;
    sheet="Country_Reference";
    getnames=yes;
run;

/* Option B (XLSX engine, more "prod"):
libname xl xlsx "&DATA/country_risk_reference.xlsx";
data country_ref; set xl.Country_Reference; run;
libname xl clear;
*/

/* ---- 2. JOIN on country_code (SQL patterns #2 & #3) ----------------
   ANSI: INNER JOIN keeps only matches; LEFT JOIN keeps all left rows + NULLs.
   TODO: run it BOTH ways and compare row counts -- the difference is your
   "orphan" population (customers whose country is not in the reference).       */

/* INNER JOIN version (for comparison only -- do NOT keep as final):
proc sql;
    create table cust_inner as
    select count(*) as n_inner
    from stg_customers as c
    inner join country_ref as r on c.country_code = r.country_code;
quit;
*/

proc sql;
    create table cust_enriched as
    select
        c.*,
        r.fatf_status,
        r.risk_weight,
        r.embargo_flag
    from stg_customers as c
    left join country_ref as r
        on c.country_code = r.country_code   /* TODO: check key casing/typing */
    ;
quit;

/* ---- 3. Handle the ORPHANS (Q1/Q2) ---------------------------------
   TODO (Q1): count customers with no match:                                  */
proc sql;
    /* select count(*) as nb_orphans from cust_enriched where risk_weight is null; */
quit;

/* TODO (Q2): decide a policy. Example = cautious default weight + a data
   quality traceability flag. (Justify from a risk standpoint.)               */
data cust_enriched;
    set cust_enriched;
    /* if missing(risk_weight) then do;
           risk_weight = 4;                       * cautious default ;
           data_quality_flag = 'UNMAPPED_COUNTRY';
       end; */
run;

/* WARNING: Q3 -- NEVER use an INNER JOIN here -> you would silently drop
   customers whose country is not (yet) in the reference: unacceptable in
   compliance (an at-risk customer must stay visible). */
