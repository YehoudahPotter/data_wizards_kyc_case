/* =====================================================================
   Module 9 (advanced) -- Historize dim_customer with SCD type 2
   ---------------------------------------------------------------------
   SKELETON TO COMPLETE. The full solution is not provided (collapsible
   hints in CASE_KYC.md). Goal: turn dim_customer into a versioned dimension
   using a change feed. Depends on dim_customer (from m4-5_star_schema.sas).
   ===================================================================== */

/* ---- 1. Load the change feed -------------------------------------- */
proc import datafile="&DATA/customer_updates.csv"
    out=customer_updates dbms=csv replace;
    guessingrows=max;
run;

/* ---- 2. Add SCD2 columns to the current dimension -----------------
   TODO: every existing customer starts as the CURRENT version:
         valid_from = onboarding_date (a SAS date),
         valid_to   = '31DEC9999'd,
         is_current = 'Y'.                                                       */
data scd2_base;
    set dim_customer;
    /* TODO: length is_current $1; format valid_from valid_to date9.;
       valid_from = ... ; valid_to = ... ; is_current = ... ;                    */
run;

/* ---- 3. Apply the changes (the SCD2 logic) ------------------------
   The ANSI/window idea: there is no single SQL statement for this -- you must
   (a) CLOSE the old version of changed customers, and (b) OPEN a new version.

   TODO (a): for each customer present in customer_updates, set on the old row
             valid_to = change_date and is_current = 'N'.
   TODO (b): create a NEW row for them with a fresh surrogate key
             (max(customer_sk) + row number), the NEW country_code / occupation,
             valid_from = change_date, valid_to = '31DEC9999'd, is_current = 'Y'.
   TODO (c): stack old + new versions into dim_customer_scd2 and sort by
             customer_id, valid_from.                                            */

/* ---- 4. Sanity check ----------------------------------------------
   TODO: expect 505 rows, 500 distinct customer_id, exactly 500 is_current='Y'.  */
proc sql;
    /* select count(*) as n_rows, count(distinct customer_id) as n_customers,
              sum(is_current='Y') as n_current
         from dim_customer_scd2; */
quit;

/* Point-in-time join (the payoff): a review joins the version where
   valid_from <= review_date < valid_to -- i.e. the customer's profile AS OF the
   review date, on the surrogate key, not on customer_id. */
