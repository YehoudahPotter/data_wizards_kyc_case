/* =====================================================================
   Module 8 (advanced) -- Industrialize the pipeline with SAS macros
   ---------------------------------------------------------------------
   SKELETON TO COMPLETE. The full solution is not provided (collapsible
   hints in CASE_KYC.md). Goal: remove repetition and parameterize the run.
   ===================================================================== */

%let DATA = /home/your-id/kyc;   /* <- same folder as the other scripts */

options mprint;   /* prints the generated SAS code in the log -- keep it ON */

/* ---- (a) One macro instead of 4 identical PROC IMPORT --------------
   TODO: write a macro %import_csv(name=) that imports &DATA/&name..csv into
   work.raw_&name, then call it 4 times.
   Remember the double dot: "&name..csv" = value of &name + literal ".csv".     */
%macro import_csv(name=);
    /* TODO: the PROC IMPORT, using &name */
%mend import_csv;

/* TODO: call it for each table
   %import_csv(name=customers)
   %import_csv(name=accounts)
   %import_csv(name=transactions)
   %import_csv(name=kyc_reviews)                                                */

/* ---- (b) Parameterize the pipeline by output folder + as-of date ---
   TODO: write %run_pipeline(out_lib=, as_of=) that exports fact_kyc_review to
   "&out_lib/fact_kyc_review_&as_of..csv". Use %put to log &as_of, and try a
   %if ... %then ... to warn if the fact table does not exist yet.              */
%macro run_pipeline(out_lib=, as_of=);
    /* TODO */
%mend run_pipeline;

/* TODO: %run_pipeline(out_lib=&DATA/output, as_of=2025-03-31)                  */

/* Then READ THE LOG: with MPRINT you see your macros "unrolling" into the
   real PROC IMPORT / PROC EXPORT code that actually executed. */
