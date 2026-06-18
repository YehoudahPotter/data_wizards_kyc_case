/* =====================================================================
   SOLUTION — Module 8 : the SAS macro language
   ---------------------------------------------------------------------
   Two ideas: (a) a macro removes repetition, (b) a macro parameterizes a
   pipeline. Turn on MPRINT to SEE the generated code in the log.
   ===================================================================== */

options mprint;                 /* prints the SAS code each macro generates */
%let DATA = /home/your-id/kyc;

/* ---- (a) Remove repetition: one macro, called 4 times --------------
   `&name..csv` = the value of &name, then a literal dot, then csv.             */
%macro import_csv(name=);
    proc import datafile="&DATA/&name..csv"
        out=raw_&name dbms=csv replace;
        guessingrows=max;
    run;
%mend import_csv;

%import_csv(name=customers)
%import_csv(name=accounts)
%import_csv(name=transactions)
%import_csv(name=kyc_reviews)

/* ---- (b) Parameterize the pipeline by output folder + as-of date ---
   In real life this is what a scheduler (Control-M) calls every reporting day. */
%macro run_pipeline(out_lib=, as_of=);
    %put NOTE: Running KYC pipeline  as_of=&as_of  ->  &out_lib;

    /* ... here you would call your staging / join / star-schema steps ...
       (kept short on purpose: the point is the parameterization)               */

    proc export data=fact_kyc_review
        outfile="&out_lib/fact_kyc_review_&as_of..csv" dbms=csv replace;
    run;

    %if %sysfunc(exist(fact_kyc_review)) %then
        %put NOTE: export done for &as_of;
    %else
        %put WARNING: fact_kyc_review not found - run 03 first;
%mend run_pipeline;

%run_pipeline(out_lib=&DATA/output, as_of=2025-03-31)

/* Read the LOG: with MPRINT you see the macro "unrolling" into the real
   PROC IMPORT / PROC EXPORT code that actually executed. */
