# solutions/ - spoilers inside

> **Do not open until you have genuinely attempted the case.** The point of the
> case is the *thinking*; reading the answer first wastes it. Use the collapsible
> hints in [`../CASE_KYC.md`](../CASE_KYC.md) while you work - come here only to
> compare a **clean reference** afterwards and understand the **why**.

## What's here

- **[`SOLUTION.md`](SOLUTION.md)** - the narrative: rationale for every decision,
  expected results (with exact numbers), answers to all questions, Power BI /
  DAX, and the common mistakes we look for.
- **[`sas/`](sas/)** - the complete, runnable SAS pipeline (named by module):
  - `m1-2_extract_clean_solution.sas` - Modules 1 & 2: extract + staging (GROUP BY, CTE-equivalent, keep-latest)
  - `m3_join_excel_solution.sas` - Module 3: INNER vs LEFT join + orphan policy
  - `m4-5_star_schema_solution.sas` - Modules 4 & 5: dimensions, fact, risk score, ranking
  - `m8_macro_solution.sas` - Module 8: macro language
  - `m9_scd2_solution.sas` - Module 9: SCD2 historization

Run them in order in SAS Studio (they share the same session / WORK tables).

> **For the assessor:** these are also your grading key - expected row counts and
> the decisions that separate a strong submission from a weak one are all in
> `SOLUTION.md`.
