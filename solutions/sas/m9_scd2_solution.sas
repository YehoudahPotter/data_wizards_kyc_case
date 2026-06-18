/* =====================================================================
   SOLUTION — Module 9 : SCD2 historization of dim_customer
   ---------------------------------------------------------------------
   Depends on dim_customer (from m4-5_star_schema_solution.sas).
   Result: dim_customer_scd2 with valid_from / valid_to / is_current.
           500 customers -> 505 rows (5 of them get a 2nd version).
   ===================================================================== */

proc import datafile="&DATA/customer_updates.csv"
    out=customer_updates dbms=csv replace;
    guessingrows=max;
run;

/* ---- 1. Add SCD2 columns to the current dimension (all = current) --
   onboarding_date is a SAS date -> use it as the version start.                */
data scd2_base;
    set dim_customer;
    length is_current $1;
    format valid_from valid_to date9.;
    valid_from = onboarding_date;
    valid_to   = '31DEC9999'd;     /* open-ended = still current */
    is_current = 'Y';
run;

/* ---- 2. Attach the change feed (who changed, when, to what) -------- */
proc sql;
    create table scd2_joined as
    select b.*,
           u.change_date,
           u.country_code as new_country_code,
           u.occupation   as new_occupation
    from scd2_base        as b
    left join customer_updates as u
        on b.customer_id = u.customer_id;
quit;

/* ---- 3a. CLOSE the old version for changed customers --------------- */
data old_versions (drop=change_date new_country_code new_occupation);
    set scd2_joined;
    if not missing(change_date) then do;
        valid_to   = change_date;   /* old version ends at the change */
        is_current = 'N';
    end;
run;

/* ---- 3b. OPEN a new current version for changed customers ----------
   New surrogate key = max(existing) + row number -> 501..505.                  */
proc sql noprint;
    select max(customer_sk) into :maxsk trimmed from dim_customer;
quit;

data new_versions (drop=change_date new_country_code new_occupation);
    set scd2_joined (where=(not missing(change_date)));
    customer_sk  = &maxsk + _n_;
    country_code = new_country_code;   /* the new attribute values */
    occupation   = new_occupation;
    valid_from   = change_date;
    valid_to     = '31DEC9999'd;
    is_current   = 'Y';
run;

/* ---- 4. Stack and sort -> the SCD2 dimension ---------------------- */
data dim_customer_scd2;
    set old_versions new_versions;
run;

proc sort data=dim_customer_scd2; by customer_id valid_from; run;

/* ---- 5. Sanity check: 505 rows, 500 distinct customers ------------ */
proc sql;
    select count(*)                    as n_rows,
           count(distinct customer_id) as n_customers,
           sum(is_current='Y')         as n_current     /* must equal 500 */
    from dim_customer_scd2;
quit;

/* ---- (Optional) point-in-time join: each review keeps the version
   that was CURRENT at its review_date -- join on the SK of that version. ------
proc sql;
    create table fact_pit as
    select k.review_id, k.review_date, v.customer_sk, v.country_code
    from raw_kyc_reviews as k
    inner join dim_customer_scd2 as v
        on k.customer_id = v.customer_id
       and k.review_date >= v.valid_from
       and k.review_date <  v.valid_to;     * valid_from <= review_date < valid_to ;
quit;
*/
