/* =====================================================================
   SOLUTION — Module 1 & 2 : Extract (Oracle CSV extract) + staging
   ---------------------------------------------------------------------
   Clean reference solution. Read it AFTER trying yourself.
   Patterns shown: #1 GROUP BY/HAVING, #4 CTE-equivalent (inline view),
                   #5 window-equivalent (BY-group "keep latest").
   ===================================================================== */

%let DATA = /home/your-id/kyc;   /* <- the SAS OnDemand folder with the CSV files */

/* ---- 1. Import the Oracle extract (the 4 CSV = the Oracle tables) --- */
proc import datafile="&DATA/customers.csv"    out=raw_customers    dbms=csv replace; guessingrows=max; run;
proc import datafile="&DATA/accounts.csv"     out=raw_accounts     dbms=csv replace; guessingrows=max; run;
proc import datafile="&DATA/transactions.csv" out=raw_transactions dbms=csv replace; guessingrows=max; run;
proc import datafile="&DATA/kyc_reviews.csv"  out=raw_kyc_reviews  dbms=csv replace; guessingrows=max; run;

/* ---- 2. Profiling (Module 1) --------------------------------------- */
proc sql;
    /* Q1 -- PEP customers. Expected: 74 */
    select count(*) as nb_pep
    from raw_customers where pep_flag = 'Y';

    /* Q3 -- pattern #1 GROUP BY + HAVING: duplicate customer_ids. Expected: 15 */
    select count(*) as nb_duplicated_ids from (
        select customer_id
        from raw_customers
        group by customer_id
        having count(*) > 1
    );

    /* Missing country_code. Expected: 24 */
    select count(*) as nb_null_country
    from raw_customers where missing(country_code);
quit;

/* ---- 3. Cleaning -> staging (Module 2) ----------------------------
   Pattern #4 (CTE): ANSI would write `WITH cleaned AS (...) SELECT ...`.
   PROC SQL has no WITH -> we use an INLINE VIEW (subquery in FROM).            */
proc sql;
    create table stg_pre as
    select
        customer_id,
        first_name,
        last_name,
        country_code,
        customer_type,
        occupation,
        pep_flag,
        onboarding_date
    from (
        /* the "CTE": one clean pass over the raw source */
        select
            customer_id,
            propcase(strip(first_name))                                     as first_name length=60,
            propcase(strip(last_name))                                      as last_name  length=60,
            case when strip(country_code) = '' then 'XX'
                 else strip(country_code) end                               as country_code length=2,
            customer_type,
            occupation,
            pep_flag,
            onboarding_date
        from raw_customers
    ) as cleaned;
quit;

/* Pattern #5 (window): ANSI dedup =
   ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY onboarding_date DESC) = 1.
   PROC SQL has no OVER() -> SAS idiom = sort DESC + keep first per BY group.    */
proc sort data=stg_pre; by customer_id descending onboarding_date; run;

data stg_customers;
    set stg_pre;
    by customer_id descending onboarding_date;
    if first.customer_id;     /* keeps the most recent record per customer */
run;                          /* Result: 500 distinct customers */

/* ---- 4. Pattern #1 again: transaction aggregates per customer ------ */
proc sql;
    create table cust_txn_agg as
    select
        a.customer_id,
        count(t.transaction_id)             as txn_count,
        sum(t.amount)                       as txn_amount format=comma14.2
    from raw_accounts        as a
    left join raw_transactions as t
        on a.account_id = t.account_id
    group by a.customer_id;
quit;
