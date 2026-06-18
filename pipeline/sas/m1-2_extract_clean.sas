/* =====================================================================
   Module 1 & 2 -- Extract (the "Oracle" source) + cleaning (staging) in SAS
   ---------------------------------------------------------------------
   SKELETON TO COMPLETE. The full solution is not provided (collapsible hints
   in CASE_KYC.md). In a real bank prod setup, the source would be Oracle via
   SAS/ACCESS:
        LIBNAME ora ORACLE user=... pw=... path=...;
   Here the source is provided as CSV files (customers / accounts / transactions /
   kyc_reviews). Upload them into your SAS OnDemand home folder, then PROC IMPORT.
   ===================================================================== */

/* ---- 0. Point to the data ------------------------------------------
   TODO: set this to the SAS OnDemand folder where you uploaded the CSV files,
   e.g. /home/<your-id>/kyc                                                    */
%let DATA = /home/your-id/kyc;   /* <- adapt */

proc import datafile="&DATA/customers.csv" out=raw_customers dbms=csv replace;
    guessingrows=max;
run;

/* ---- 1. Profiling (Module 1) ---------------------------------------
   TODO (Q1): count the PEP customers                                         */
proc sql;
    /* select count(*) as nb_pep from raw_customers where pep_flag = 'Y'; */
quit;

/* TODO (Q2/Q3): spot inconsistent casing, whitespace, NULL, duplicates.
   Duplicates hint -- SQL pattern #1 GROUP BY + HAVING:                        */
proc sql;
    /* select customer_id, count(*) as n
         from raw_customers group by customer_id having n > 1; */
quit;

/* TODO (GROUP BY aggregation): per customer, number of transactions and total
   amount. Join accounts -> transactions, then GROUP BY customer_id.
   proc sql;
       create table cust_txn_agg as
       select a.customer_id,
              count(t.transaction_id) as txn_count,
              sum(t.amount)           as txn_amount
       from raw_accounts as a
       left join raw_transactions as t on a.account_id = t.account_id
       group by a.customer_id;
   quit; */

/* ---- 2. Cleaning -> STG_CUSTOMERS (Module 2) -----------------------
   SQL pattern #4 (CTE): ANSI would be `WITH cleaned AS (...) SELECT ... FROM cleaned`.
   PROC SQL has NO `WITH`. Use an INLINE VIEW (subquery in FROM) instead, e.g.:
       create table stg_customers as
       select * from (
           select customer_id,
                  propcase(strip(first_name)) as first_name,
                  coalesce(nullif(strip(country_code),''),'XX') as country_code,
                  ...
           from raw_customers
       ) as cleaned;
   ...or successive CREATE TABLE steps (the most common SAS style).            */
proc sql;
    create table stg_customers as
    select
        customer_id,
        /* TODO: normalize case + strip whitespace: propcase(strip(first_name)) */
        first_name,
        last_name,
        /* TODO: replace missing country_code with 'XX' */
        country_code,
        customer_type,
        occupation,
        pep_flag,
        onboarding_date
    from raw_customers
    ;
quit;

/* ---- Dedup: SQL pattern #5 (window function), the SAS way ----------
   ANSI: ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY onboarding_date DESC),
         then keep rn = 1.
   PROC SQL has NO OVER(). SAS idiom = sort DESC + keep first per BY group:     */
proc sort data=stg_customers; by customer_id descending onboarding_date; run;
data stg_customers;
    set stg_customers;
    by customer_id;
    if first.customer_id;   /* keeps the most recent record per customer */
run;
