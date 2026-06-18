# Reference solution & explanation

> **SPOILER.** Open this only **after** you have genuinely attempted the case.
> The value is not the code - it is understanding **why** each choice is made.
> The clean, runnable SAS is in [`sas/`](sas/); this file explains the reasoning
> and gives the **expected results** so you can check yourself.

The scripts are named by the **module** they implement, and run in order:

| Script | Modules |
|---|---|
| [`sas/m1-2_extract_clean_solution.sas`](sas/m1-2_extract_clean_solution.sas) | 1 & 2 - explore + staging |
| [`sas/m3_join_excel_solution.sas`](sas/m3_join_excel_solution.sas) | 3 - Excel join |
| [`sas/m4-5_star_schema_solution.sas`](sas/m4-5_star_schema_solution.sas) | 4 & 5 - star schema + risk score |
| [`sas/m8_macro_solution.sas`](sas/m8_macro_solution.sas) | 8 - macro language |
| [`sas/m9_scd2_solution.sas`](sas/m9_scd2_solution.sas) | 9 - SCD2 historization |

(Module 6 = Power BI, see [`../powerbi/README.md`](../powerbi/README.md); Module 7 =
bonus watchlist, no separate script.)

---

## Module 1 - Explore the source

**What you should find (expected numbers):**

| Check | Result |
|---|---|
| Raw `customers` rows | **515** |
| Distinct `customer_id` | **500** → **15** duplicated ids |
| PEP customers (`pep_flag='Y'`) | **74** |
| Missing `country_code` | **24** |

**Why it matters.** Profiling *before* coding is the cheapest insurance in any
banking pipeline. The five anomalies (casing, whitespace, NULL country, duplicates,
and - discovered in Module 3 - countries missing from the reference) drive every
downstream decision. Pattern **#1 `GROUP BY … HAVING COUNT(*) > 1`** is the canonical
way to *prove* a uniqueness problem rather than assume it.

---

## Module 2 - Staging

**Key decisions and the "why":**

- **Dedup key = `customer_id`.** It is the stable business identifier. When two
  rows collide we keep the **most recent** (`onboarding_date DESC`) - a
  *deterministic* rule, so the pipeline is reproducible (re-running gives the same
  500 rows). Here the duplicates are exact copies, so the count lands on **500**
  either way; the rule still matters for correctness in real data.
- **Missing `country_code` → `'XX'`.** Replacing (rather than leaving NULL) keeps
  the row through the join and makes the gap **visible** as an explicit "unknown"
  category, instead of a silent hole.
- **Why a staging layer?** It isolates cleaning, leaves the raw source intact
  (auditability), and lets you replay the pipeline. You never mutate the source.

**Patterns shown.** #4 **CTE-equivalent**: SAS `PROC SQL` has no `WITH`, so we use
an **inline view** (a subquery in the `FROM`). #5 **window-equivalent**: ANSI would
dedup with `ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY onboarding_date
DESC) = 1`; SAS has no `OVER()`, so we `PROC SORT` descending and keep
`if first.customer_id;` in a `DATA step`.

---

## Module 3 - Excel join 

**Expected numbers:**

| Join | Customers kept |
|---|---|
| `INNER JOIN` | **419** |
| `LEFT JOIN` | **500** |
| → Orphans (no reference match) | **81** - `XX`:35, `CN`:26, `BR`:20 |

**Why `LEFT JOIN` is mandatory.** The reference Excel is hand-maintained by
Compliance and is **not exhaustive**. An `INNER JOIN` would *silently drop 81
customers* - including potentially high-risk ones - from the entire reporting.
**Making a risk invisible is a compliance fault.** So we keep all customers with
`LEFT JOIN` and the non-matches surface as `NULL` risk.

**Orphan policy (precautionary principle).** An unreferenced country is **not**
"risk-free". We assign a **cautious default weight (4)** *and* a traceable
`data_quality_flag = 'UNMAPPED_COUNTRY'` so these customers are both scored
prudently and routed to manual reference-data fixing. The worst choice would be a
low default weight (1) - it would *hide* risk.

Patterns shown: #2 `INNER JOIN` / #3 `LEFT JOIN` (run both, compare counts).

---

## Module 4 - Star schema

- **Grain = one KYC review** (`review_id`). A customer with 2 reviews = 2 fact
  rows. Defining the grain first is what keeps the model coherent.
- **Surrogate keys** (`customer_sk`, `country_sk`, `date_sk`): integer technical
  keys. Two reasons: **performance** (integer joins beat string joins) and
  **stability** (if a business key changes, or you historize a dimension with SCD2,
  the SK insulates the fact). Power BI relationships are built on these.
- **`dim_country`** is built from the reference **plus an explicit `XX / Unknown`
  row**, so orphan reviews still point at a real dimension member.
- **`pep_flag`** lives in `dim_customer` (a descriptive attribute); it may be
  echoed onto the fact for easy filtering.

The fact resolves the SKs with joins onto the three dimensions (see
`m4-5_star_schema_solution.sas`).

---

## Module 5 - Risk score & ranking

**Formula used** (one reasonable choice - others are fine if justified):

```text
risk_score = risk_weight*10  (+20 if PEP)  (+ alert_count*8)
if embargo: risk_score = max(risk_score, 80)   ← floor rule
risk_score = min(risk_score, 100)
```

- **Weighting rationale.** Country and PEP status are stronger structural signals
  than the raw alert count, so they weigh more. The score is **bounded 0-100**.
- **Embargo floor.** A customer in an embargoed country must **never** be "Low".
  A simple additive could leave them low; a `max(score, 80)` **floor** guarantees
  at least "Critical-adjacent". This is a *rule*, not a tweak.
- **Freeze the score in the fact table** (not in staging, not in Power BI):
  reproducibility (the score of a review never silently changes later), Power BI
  performance (no recompute), and auditability (you know the score assigned *as of*
  the review date).
- **`risk_rank`** (pattern #5 again): ANSI `RANK() OVER (PARTITION BY country_code
  ORDER BY risk_score DESC)`; SAS does it with `PROC RANK … BY country_code …
  ties=low`. This gives the "top-N riskiest customers per country" list Compliance
  actually asks for.

> ⚠️ **Classic SAS bug to avoid.** `risk_score + (risk_weight*10);` is the SAS
> **sum statement** - it *accumulates across rows* (implicit `RETAIN`). Use
> **assignment** `risk_score = risk_score + risk_weight*10;` for per-row logic.

---

## Module 6 - Power BI

**Relationships** (many-to-one, single filter direction), built on the surrogate
keys:

- `fact_kyc_review[customer_sk] → dim_customer[customer_sk]`
- `fact_kyc_review[country_sk]  → dim_country[country_sk]`
- `fact_kyc_review[date_sk]     → dim_date[date_sk]`

We relate on **SKs, not names**, because names are not unique (homonyms) and can
change; SKs are unique, stable and integer.

**Main DAX measure** - high-risk customer rate (it is a **measure**, not a
calculated column, because it must react to the visual's filter context):

```dax
High Risk Customer Rate =
DIVIDE (
    CALCULATE (
        DISTINCTCOUNT ( fact_kyc_review[customer_sk] ),
        fact_kyc_review[risk_category] IN { "High", "Critical" }
    ),
    DISTINCTCOUNT ( fact_kyc_review[customer_sk] )
)
```

**Three KPIs for a Compliance officer**: (1) % High/Critical customers,
(2) customers in Blacklist/embargo countries, (3) reviews in `EDD`/`Pending`
(workload). All **actionable**, not decorative.

---

## Module 8 - Macro language

See [`sas/m8_macro_solution.sas`](sas/m8_macro_solution.sas).

- **Macro variable vs data-step variable.** `&DATA`, `&name`, `&as_of` are **text**,
  resolved at **compile time** (before any step runs). A data-step variable lives at
  **run time**, one value per observation, with a type. By the time data flows
  through a `DATA step`, the macro variables are already gone - they were just used
  to *write* the code.
- **`%import_csv(name=)`** turns 4 identical `PROC IMPORT` blocks into one macro
  called 4×. `&name..csv` = the value of `&name`, then a literal `.`, then `csv`
  (the first dot terminates the macro reference).
- **`%run_pipeline(out_lib=, as_of=)`** parameterizes the run. A scheduler calls it
  every reporting day; the `as_of` date flows into the output file name and (in a
  full build) into the data filters.
- **`options mprint;`** prints the *generated* SAS code in the log - essential when
  debugging, because the error is in code you never literally typed.

---

## Module 9 - SCD2 historization

See [`sas/m9_scd2_solution.sas`](sas/m9_scd2_solution.sas).

**Expected result:** **505 rows**, **500 distinct** `customer_id`, exactly **500**
rows with `is_current='Y'` (one current version per customer; 5 customers also keep
one historical version).

- **The mechanism.** Every customer starts as one current version
  (`valid_from`=onboarding, `valid_to`=`31DEC9999`, `is_current='Y'`). For the 5
  changed customers we **close** the old version (`valid_to = change_date`,
  `is_current='N'`) and **insert** a new version with a *fresh surrogate key*
  (501-505), the new attributes, and `valid_from = change_date`.
- **Why it is correct (C00003: IT → RU).** A review dated **before** 2025-03-10
  joins to the **`IT`** version (the one where `valid_from ≤ review_date < valid_to`).
  The bank really did assess this customer as Italian then; rewriting history to
  `RU` (which SCD1 would do) would be misleading and fail audit.
- **The fact join.** Point-in-time: the fact joins on the **surrogate key of the
  version valid at `review_date`**, not on `customer_id`. This is *the* concrete
  payoff of surrogate keys (Module 4): the same customer has several SKs over time,
  and each review keeps the one that was true when it happened.

---

## The 5 SQL patterns - where each one is demonstrated

| # | Pattern | Where (solution file) |
|---|---|---|
| 1 | `GROUP BY` / `HAVING` | `01` - duplicate detection + transaction aggregates |
| 2 | `INNER JOIN` | `02` - count comparison |
| 3 | `LEFT JOIN` | `02` - the enrichment (kept version) |
| 4 | CTE → inline view | `01` - the cleaning subquery in `FROM` |
| 5 | Window → `BY`-group / `PROC RANK` | `01` (keep-latest) + `03` (risk rank) |

---

## Common mistakes we look for

- `INNER JOIN` on the reference → **81 customers vanish** (the trap).
- Low default weight for orphans → **hides risk**.
- The SAS **sum-statement** accumulation bug on `risk_score`.
- Relating Power BI tables on **names** instead of surrogate keys.
- Computing the risk score as a Power BI calculated column instead of **freezing it
  in the fact** (loses auditability).
