# Data Wizards Case - KYC Pipeline: from source to dashboard

> **Goal**: reproduce, in miniature, a data chain as found in the Risk /
> Compliance functions of a large (tier-1) bank:
> **system source → ETL (SAS) → star schema → Power BI**.
>
> The pipeline is built **entirely in SAS** (`PROC SQL` + `DATA step`), run for
> free in **SAS Studio** (see Module 0). SAS is the differentiating skill in
> banking - there is no other language to learn here.
>
> The fake source data is **pre-generated and provided** in the `data/` folder
> (identical for every candidate). You don't generate anything: you upload the
> files into SAS Studio and start coding.
>
> ⚠️ **The 4 CSV files ARE the Oracle database.** Think of `customers.csv`,
> `accounts.csv`, `transactions.csv`, `kyc_reviews.csv` as a raw **extract of the
> bank's Oracle system tables**. We ship them as CSV only because standing up a
> real Oracle instance is heavy - in production you would query Oracle directly;
> here you `PROC IMPORT` the CSV. Everything downstream is identical.

---

## How this tutorial works

Every module follows the same rhythm:

- **Concept** - the notion to understand (and why it matters in banking).
- **Task** - what you must produce (phrased **openly**: you investigate, we do
  not list the problems for you).
- **Questions** - to answer **in writing** before expanding the hint.
- **Hint** - a **collapsible** block (`click to reveal`). It **confirms** your
  findings and unblocks you, but does **not** give the full code.

> The rule of the game: investigate and answer **first**, expand the hint
> **after**. That is where you learn - and exactly what we assess.

> **The case is progressive - you choose how far you go.** The modules build on
> each other, so do them in order and stop at whatever milestone you reach: Modules
> 0 → 3 are already a solid start, 0 → 6 is the full core, and 8 → 9 are advanced
> (7 is an optional bonus). You don't have to finish everything for it to be worth
> it. (See "How far should you go?" in the [README](README.md).)

> **Start with the course.** Read **[`COURSE.md`](COURSE.md)** first - and treat
> **knowing *all* its concepts as the key baseline** (SQL, CTEs, window functions,
> star schema, surrogate keys, SCD2, KYC, Power BI, SAS macros). Whatever amount of
> the case you complete, that conceptual mastery is the non-negotiable minimum. The
> tutorial keeps explanations short and links back to the course for each deep dive.

---

## SQL Toolbox - the 5 patterns you must use

This case is also a SQL exam: across the modules you **must** use each of these 5
patterns at least once. Two of them (CTE, window functions) are **ANSI SQL** you
know from Postgres / Snowflake - **but classic SAS `PROC SQL` does not support
them**, so you'll learn the SAS idiom that replaces each.

Deep dives: [SQL foundations](COURSE.md#3-sql-foundations) ·
[GROUP BY](COURSE.md#4-group-by-and-aggregation) ·
[Joins](COURSE.md#5-joins-inner-and-left) · [CTEs](COURSE.md#6-ctes-with) ·
[Window functions](COURSE.md#7-window-functions) ·
[SAS execution model](COURSE.md#8-the-sas-execution-model).

| # | ANSI SQL concept | Supported as-is in SAS `PROC SQL`? | The SAS way | Used in |
|---|---|---|---|---|
| 1 | `GROUP BY` (+ `HAVING`) | Yes | identical | Module 1 |
| 2 | `INNER JOIN` | Yes | identical | Module 3 |
| 3 | `LEFT JOIN` | Yes | identical | Module 3 |
| 4 | **CTE** (`WITH … AS`) | **No** | inline view (subquery in `FROM`) or successive `CREATE TABLE` | Module 2 |
| 5 | **Window function** (`OVER / PARTITION BY`) | **No** | `DATA step` `BY` + `first.`/`last.`/`RETAIN`, or `PROC RANK` | Modules 2, 5 |

> This ANSI-vs-SAS gap is itself a key lesson: many analysts arrive in banking
> fluent in standard SQL and are surprised that SAS `PROC SQL` has neither CTEs nor
> window functions. Knowing the **equivalent SAS idiom** is what makes you
> operational on day one.

---

## The business backdrop: what is KYC?

**KYC = Know Your Customer.** Regulation requires banks to know their customers to
fight money laundering (AML) and terrorist financing. Concretely, you collect and
verify: identity, country, activity, politically-exposed status (**PEP**), and you
assign a **risk level**.

The data landscape is *typical*:

| Source | Nature | Maintained by | In this case |
|---|---|---|---|
| **Oracle database** | System data (customers, accounts, transactions, reviews) | The applications | `data/*.csv` - **these CSVs are the Oracle DB extract** |
| Excel file | Business **reference** data (country risk matrix) | The Compliance team, **by hand** | `data/country_risk_reference.xlsx` |

This "large database + hand-maintained Excel" mix is **the reality on the
ground**. Reconciling the two cleanly is exactly what is expected from a data
profile in banking.
[The vocabulary: KYC and AML concepts](COURSE.md#13-kyc-and-aml-concepts) (PEP,
sanctions, FATF, EDD, embargo, risk scoring).

---

## Module 0 - Setup

**Task - A. Get the data**

The data is already in the **`data/`** folder of this repository (pre-generated,
identical for everyone). You will work with these 5 files:
`customers.csv`, `accounts.csv`, `transactions.csv`, `kyc_reviews.csv` and
`country_risk_reference.xlsx`. Nothing to install or run.

**Task - B. Set up SAS Studio (where you will write the pipeline)**

1. Create a **free** account on **SAS OnDemand for Academics**
   (<https://www.sas.com/ondemand>) and open **SAS Studio** (runs in your browser,
   nothing to install).

**Task - C. Upload the data**

In the left panel of SAS Studio:

1. Open **Server Files and Folders** and expand **Files (Home)** - your personal
   folder.
2. Right-click it → **New → Folder** → name it **`kyc`**.
3. Right-click `kyc` → **Upload Files** → select your **5 files**: the 4 CSV +
   `country_risk_reference.xlsx`.

**Task - D. Import the data into SAS**

Find your exact home path (no typos) by running:

```sas
%put My home folder is: /home/&sysuserid;
```

The path appears in the **Log**. Then set it and import everything:

```sas
%let DATA = /home/&sysuserid/kyc;   /* or paste your path literally */

/* The 4 CSV = the Oracle database extract */
proc import datafile="&DATA/customers.csv"    out=raw_customers    dbms=csv replace; guessingrows=max; run;
proc import datafile="&DATA/accounts.csv"     out=raw_accounts     dbms=csv replace; guessingrows=max; run;
proc import datafile="&DATA/transactions.csv" out=raw_transactions dbms=csv replace; guessingrows=max; run;
proc import datafile="&DATA/kyc_reviews.csv"  out=raw_kyc_reviews  dbms=csv replace; guessingrows=max; run;

/* The Excel reference (Compliance) */
proc import datafile="&DATA/country_risk_reference.xlsx"
    out=country_ref dbms=xlsx replace;
    sheet="Country_Reference";
    getnames=yes;
run;
```

**Check it worked** - you should see **515** customer rows and a clean Log:

```sas
proc print data=raw_customers (obs=10); run;
proc sql; select count(*) as n_customers from raw_customers; quit;   /* expect 515 */
```

> Two common pitfalls: a wrong path (`&DATA` mis-resolves → read the Log) or a
> misspelled `sheet=` for the Excel (it must be exactly `Country_Reference`).
> You now have a fully executable SAS environment - on to Module 1.

**Concept - why these tools?**
- **CSV "for" Oracle**: Oracle is a heavy proprietary DBMS. Plain CSV files let you
  work on the *logic* without the infrastructure. In a real bank you would read
  Oracle via `SAS/ACCESS to Oracle` instead of `PROC IMPORT` - **the SAS logic
  downstream is identical**.
- **SAS Studio**: it is not just an editor - it runs your SAS code on SAS's cloud
  engine for free. You write, you **run**, you read the Log and Results. Every SAS
  module (1-5, plus the advanced 8-9) is written and executed here.

---

## Module 1 - Explore the source

**Concept - extraction (the "E" in ETL)**
Before transforming, you **profile**: volume, distinct values, missing values,
duplicates. It is the step everyone neglects and that costs the most. **The rest
of the pipeline depends on what you spot here.**
Deep dives: [The data pipeline & staging](COURSE.md#1-the-data-pipeline-and-the-staging-layer)
· [Data quality and profiling](COURSE.md#2-data-quality-and-profiling)

**Task** - You already imported the 4 tables in Module 0 (`raw_customers`,
`raw_accounts`, `raw_transactions`, `raw_kyc_reviews`). Now **explore** them with
`PROC SQL` / `PROC FREQ` / `PROC PRINT`: count rows, look at samples, and **build
your own list of anomalies** - this is your starting diagnosis.

> **SQL pattern #1 - `GROUP BY` (+ `HAVING`)** - collapses rows into one per
> group for aggregates (`COUNT`, `SUM`…). `WHERE` filters rows *before* grouping;
> `HAVING` filters *groups* after. Identical in SAS `PROC SQL`.
> [Full explanation: GROUP BY and aggregation](COURSE.md#4-group-by-and-aggregation)

**Use it** - Answer Q3 with `GROUP BY … HAVING`, **and** compute, per customer,
the **number of transactions** and the **total amount** (join `accounts` →
`transactions`, then `GROUP BY customer_id`). This is the kind of per-customer
figure Compliance asks for - and a clean `GROUP BY` exercise.

**Questions**

1. How many PEP customers (`pep_flag = 'Y'`) are there?
2. List **all** the data-quality issues you identify (there are several - look
   carefully: casing, whitespace, missing values, uniqueness…).
3. Does the `customers` table respect uniqueness per customer? Prove it with a
   `GROUP BY … HAVING COUNT(*) > 1`.

<details>
<summary>Hint - click to confirm your diagnosis</summary>

- **Q1 (PEP)**: order of magnitude ~70 customers. All `occupation='Politician'`
  are PEP, plus ~5% random ones. `WHERE pep_flag = 'Y'`.
- **Q2 (anomalies to spot)** - there are **five**:
  1. inconsistent casing on names (`DUPONT`, `dupont`, `Dupont`);
  2. stray whitespace at the start/end of names;
  3. missing `country_code` (`NULL`) on part of the customers;
  4. **duplicate** customers (same `customer_id` on several rows);
  5. some `country_code` present in the database that **will not exist** in the
     Excel reference (you only really see this in Module 3 - keep an eye out).
- **Q3 (uniqueness)**: `GROUP BY customer_id HAVING COUNT(*) > 1` reveals the
  duplicates. About fifteen customers are duplicated.

</details>

---

## Module 2 - Extract & clean (staging)

**Concept - the *staging* layer**
You never transform the source directly. You build a clean intermediate layer from
the **Module 1 diagnosis**, using `PROC SQL` + a `DATA step`.
[Full explanation: the data pipeline & staging layer](COURSE.md#1-the-data-pipeline-and-the-staging-layer)

**Task** - Produce a `stg_customers` table that **fixes the anomalies YOU
identified** in Module 1. You decide *how* to handle each one (normalization,
missing values, uniqueness) - and **justify** your choices.

> **SQL pattern #4 - CTE (`WITH … AS`)** - a named temporary result set for
> readable, reusable multi-step queries. **SAS has no `WITH`** → use an *inline view*
> (subquery in the `FROM`) or successive `CREATE TABLE` steps.
> [Full explanation: CTEs](COURSE.md#6-ctes-with)

> **SQL pattern #5 - Window function (`OVER / PARTITION BY`)** - computes across
> related rows *without collapsing them* (`ROW_NUMBER`, `RANK`…). **Dedup trick**:
> keep latest per customer via `ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY
> onboarding_date DESC) = 1`. **SAS has no `OVER`** → `PROC SORT` + a `DATA step`
> with `by customer_id …; if first.customer_id;`.
> [Full explanation: Window functions](COURSE.md#7-window-functions)

**Use it** - Build your staging using a **CTE** (or its SAS equivalent: inline
view / successive tables), and deduplicate by **keeping the most recent record per
`customer_id`** - i.e. the window-function pattern, done the SAS way.

**Questions**

1. To guarantee uniqueness, which key do you use and **why**? If two rows of the
   same customer differ, **which one do you keep**?
2. For a missing `country_code`: do you replace it with a sentinel value
   (e.g. `'XX'`) or leave it `NULL`? What is the impact on the Module 3 join?
3. Why clean in *staging* rather than directly in the fact table?

<details>
<summary>Hint - click to reveal</summary>

- **Uniqueness**: the key is `customer_id` (stable business identifier). If two
  rows differ, define a **deterministic** rule (keep the most recent by
  `onboarding_date`, or the first). What matters is that it is justified and
  reproducible, not arbitrary. In SAS: `PROC SORT NODUPKEY` (or a `GROUP BY` with
  aggregates in `PROC SQL`).
- **NULL → 'XX'**: replacing avoids losing the row at join time and makes the
  problem **visible** (an "unknown country" category instead of a silent gap).
  Keeping `NULL` is defensible, but then handle it explicitly in Module 3.
- **Why staging**: you isolate the cleaning, keep the source intact (auditability)
  and can **replay** the pipeline. Never transform the source directly.

</details>

---

## Module 3 - Join with the Excel reference 

**Concept - joining heterogeneous sources**
You enrich a table coming from a **database** with a table coming from an
**Excel**. It is a join on `country_code`: you retrieve each customer's country
risk profile. **The choice of join type is a risk decision** - think it through
before coding.

> **SQL patterns #2 & #3 - `INNER JOIN` vs `LEFT JOIN`** - `INNER` keeps only
> matching rows; `LEFT` keeps **all** left rows, with `NULL`s where the right side
> has no match. The difference shows up **only on the non-matches** - which is how
> you detect missing reference data. Both native/identical in SAS `PROC SQL`.
> [Full explanation: Joins](COURSE.md#5-joins-inner-and-left)

**Task**

- Import the Excel into SAS (`PROC IMPORT` or `LIBNAME XLSX`), then join it to
  `stg_customers` with `PROC SQL`.
- Enrich each customer with: `fatf_status`, `risk_weight`, `embargo_flag`.
- **Run it both ways** - once with `INNER JOIN`, once with `LEFT JOIN` - and compare
  the row counts. The difference is your population of "orphan" customers.
- Keep the **`LEFT JOIN`** version and check the result row by row.

**Questions**

1. After the join, do **all** customers have a `risk_weight`? If not, how many do
   not, and **why**?
2. What do you decide for those customers: default weight? quarantine? data-quality
   alert? **Justify** from a *risk* standpoint.
3. What is the concrete difference between `INNER JOIN` and `LEFT JOIN` **here**,
   and why would the wrong choice be **dangerous** in a compliance context?

<details>
<summary>Hint - click to reveal (⚠️ contains the key to the exercise)</summary>

- **Q1 - the central trap**: **no**, some customers come out **without** a
  `risk_weight`. The cause: some `country_code` present in the database (`CN`,
  `BR`, and the `XX` sentinel) **do not exist** in the Excel reference - it is
  hand-maintained by Compliance and is not exhaustive. With a `LEFT JOIN` those
  customers come out with `NULL` on the risk side. **That is the whole point.**
- **Q2 - policy**: in compliance, the **precautionary principle** prevails. An
  unreferenced country is not "risk-free". Two defensible options: (a) a **high**
  default weight (4) pending the reference update, or (b)
  `data_quality_flag = 'UNMAPPED_COUNTRY'` + manual review. The **worst choice** is
  a low default weight.
- **Q3 - INNER vs LEFT**: an `INNER JOIN` would **drop** the unmatched customers →
  you would make potentially at-risk customers **disappear** from the reporting.
  Making a risk invisible is a fault in compliance. → `LEFT JOIN` mandatory, then
  explicitly handle the non-matches.

</details>

---

## Module 4 - The star schema

**Concept - fact, dimension, grain, surrogate key**
A **star schema** organizes data for analysis: a central **fact table** (the
measurable events - here, a KYC review) surrounded by **dimensions** (the context:
who? which country? when?). The **grain** = what one fact row represents (define it
first). A **surrogate key** = an integer technical key replacing the business key in
joins.
Deep dives: [Star schema & dimensional modelling](COURSE.md#9-dimensional-modelling-and-the-star-schema)
· [Surrogate keys](COURSE.md#10-surrogate-keys-vs-business-keys)

Target model:

```text
                 dim_date
                    |
  dim_customer --- fact_kyc_review --- dim_country
                    |
            (measures: risk_score, alert_count, ...)
```

**Task** - Build:

- `dim_customer` (SK + customer attributes);
- `dim_country` (SK + country attributes, **from the database + Excel merge**);
- `dim_date` (SK + year, quarter, month…);
- `fact_kyc_review`, **grain = one KYC review**, containing the dimension SKs +
  the measures (`risk_score`, `alert_count`, `document_verified`…).

**Questions**

1. What is the exact **grain** of your fact table? Justify it.
2. Why replace `customer_id` (business key) with a `customer_sk` (surrogate key) in
   the fact table? Give **two** reasons.
3. Should `pep_flag` go in the customer **dimension** or in the **fact** table? Why?

<details>
<summary>Hint - click to reveal</summary>

- **Q1 (grain)**: one row = **one KYC review** (`review_id`). A customer with 2
  reviews = 2 fact rows. Everything (measures, SKs) hangs off that grain.
- **Q2 (surrogate key)**: (1) **performance** - integer joins > string joins;
  (2) **stability/historization** - if the `customer_id` changes or if you
  historize the dimension (SCD2), the SK insulates the fact from those changes.
- **Q3 (`pep_flag`)**: a **descriptive customer attribute** → `dim_customer`. (You
  may duplicate it as a flag in the fact for easy filtering, but its natural home
  is the dimension.)

</details>

---

## Module 5 - The risk score (business logic)

**Concept - derived data**
`risk_score` exists in no source: you **compute** it in the pipeline from several
signals. This is where the data gains business value.
[Full explanation: derived data and business logic](COURSE.md#12-derived-data-and-business-logic)

**Task** - Compute a `risk_score` (0-100) per KYC review, combining at least:
the country `risk_weight`, the `pep_flag`, the `alert_count` and the
`embargo_flag`. Also derive a `risk_category` (e.g. *Low / Medium / High /
Critical*).

> **SQL pattern #5 again - ranking** - ANSI `RANK() OVER (PARTITION BY
> country_code ORDER BY risk_score DESC)` ranks rows within each country. **SAS has
> no `OVER`** → use `PROC RANK ... by country_code; var risk_score; ranks risk_rank;`
> (`ties=low` ≈ ANSI `RANK()`).
> [Full explanation: Window functions](COURSE.md#7-window-functions)

**Use it** - Add a `risk_rank` giving each review's rank **within its country**
by descending `risk_score` (the highest-risk review per country is rank 1). This is
the kind of "top-N riskiest per country" list Compliance asks for.

**Questions**

1. Propose a **weighting** formula and justify the weight of each factor.
2. Should a customer in an **embargoed** country ever be classified "Low"? How do
   you guarantee that in your logic?
3. Where do you compute this score: in staging, or at fact-table build time? What
   is the advantage of **freezing** it in the fact table?

<details>
<summary>Hint - click to reveal</summary>

- **Q1 (formula)**: no single answer. A reasonable weighting gives more weight to
  country and PEP than to the number of alerts. Make sure the score stays bounded
  0-100 (`min(score, 100)`).
- **Q2 (embargo)**: a customer under embargo must **never** be "Low". Implement a
  **floor rule**: `if embargo='Y' then score = max(score, 80)`. Safer than a plain
  additive (which could stay low).
- **Q3 (where)**: freeze the score in the **fact table**. Benefits:
  reproducibility (a review's score no longer changes afterwards), Power BI
  performance (no recompute), auditability (you know which score was assigned at
  review date).

</details>

---

## Module 6 - Power BI: data model + metric + dashboard

**Concept - the semantic model**
SAS produces **tables**; **Power BI** assembles the star: import the tables, create
**relationships** (fact ↔ dimensions via the SKs), then write **DAX measures** (the
KPIs). One dashboard line = one business question.
[Full explanation: Power BI semantic model & DAX](COURSE.md#14-power-bi-semantic-model-and-dax)

**Task**

1. Export your star schema (CSV or database) - see [`powerbi/README.md`](powerbi/README.md).
2. Import the tables into Power BI Desktop.
3. Create the **relationships**: `fact_kyc_review[customer_sk] → dim_customer[customer_sk]`,
   same for `dim_country` and `dim_date` (cardinality *many-to-one*).
4. Create **at least one DAX measure** (e.g. high-risk customer rate - template
   provided in `powerbi/README.md`).
5. Build **one** dashboard page: a KPI, a view by `fatf_status`, and a risk
   distribution by country/region.

**Questions**

1. Why are relationships created on the **surrogate keys** and not on names?
2. Difference between a **calculated column** and a **measure** in DAX? Which one
   for the "high-risk customer rate", and why?
3. Which **3 KPIs** would you put forward for a Compliance officer, and why those?

<details>
<summary>Hint - click to reveal</summary>

- **Q1 (relationships on SK)**: names are not unique (homonyms) and can change;
  SKs are unique, stable, integer → reliable and fast relationships.
- **Q2 (column vs measure)**: a **calculated column** is evaluated row by row at
  refresh and stored; a **measure** is computed on the fly according to the
  visual's context (filters). The "rate" depends on context (by country, by
  month…) → **measure**.
- **Q3 (KPIs)**: e.g. (1) % High/Critical customers, (2) number of customers in
  Blacklist/embargo countries, (3) number of reviews in `EDD`/`Pending`
  (Compliance workload). The idea: **actionable** KPIs.

</details>

---

## Module 7 (bonus) - PEP / sanctions watchlist

**Concept - name screening**
Beyond country, Compliance cross-checks customers against **people lists** (PEP,
sanctions). The matching is on the **name** → much trickier (homonyms,
transliterations, casing, typos).

**Task (advanced)** - Create a small watchlist Excel (a few names), upload it,
and match it against `dim_customer` in SAS. Start with an *exact match*
(`INNER JOIN` on the name), then a *fuzzy match* using SAS string-distance
functions: **`COMPLEV`** (Levenshtein distance), **`COMPGED`** (generalized edit
distance) or **`SOUNDEX`** (phonetic) to catch near-matches.

**Questions**

1. Why does an *exact match* on the name generate **too many false negatives**?
2. A *fuzzy match* generates **false positives**: who handles them, and what is the
   cost of a false negative vs a false positive in compliance?

<details>
<summary>Hint - click to reveal</summary>

- **Exact match**: misses variants (casing, accents, first/last-name order,
  transliterations) → **false negatives** (you let a true match through).
  Dangerous in sanctions.
- **Fuzzy match**: generates false positives to be arbitrated by an analyst. In
  compliance, a **false negative** (missing a sanctioned party) costs far more
  (fine, reputation) than a false positive (analysis time). So you calibrate
  "wide".

</details>

---

## Module 8 (advanced) - Industrialize with the SAS macro language

**Concept - what a macro *is***
The SAS **macro language** is a *code generator*: it runs **before** SAS and writes
the code that executes - it manipulates **text**, not data. **Macro variables**
(`&name`, via `%let`) are text placeholders; **macros** (`%macro … %mend;`) are
reusable **parameterized** code blocks. Banks rely on this to run the same pipeline
**every day / per entity / per as-of date** without copy-paste.
[Full explanation: SAS macro language](COURSE.md#15-sas-macro-language)

**Task** - skeleton: [`pipeline/sas/m8_macro.sas`](pipeline/sas/m8_macro.sas)

1. **Remove repetition**: the 4 `PROC IMPORT` are the same code 4 times. Write a
   macro `%import_csv(name=)` and call it 4 times (`%import_csv(name=customers)`…).
2. **Parameterize**: wrap the export step (or the whole pipeline) in a
   `%macro run_pipeline(out_lib=, as_of=);` that takes the output folder and an
   as-of date, and uses them via `&out_lib` / `&as_of`.
3. Turn on `options mprint;` and **read the generated code in the log** - that is
   the macro "unrolling" into real SAS.

**Questions**

1. What is the difference between a **macro variable** (`&x`) and a **data-step
   variable**? At what *moment* does each exist?
2. Why does `options mprint;` matter when you debug a macro?
3. Give one concrete banking reason to parameterize the pipeline by `as_of` date.

<details>
<summary>Hint - click to reveal</summary>

- A **macro variable** is resolved at **compile time** (before the step runs) and is
  always **text**; a data-step variable exists at **run time**, per observation, and
  has a type. `&x` is gone by the time data flows.
- `mprint` prints the **actual SAS code** the macro generated - without it you debug
  blind, because the error is in code you never literally wrote.
- `as_of` lets you **reproduce a past state** (regulatory reporting, audit: "what
  was this customer's risk on 2024-12-31?") and run the same code for any reporting
  date - exactly what SCD2 (Module 9) makes possible on the data side.

</details>

---

## Module 9 (advanced) - Historize the customer dimension (SCD2)

**Concept - Slowly Changing Dimension, type 2**
When a customer changes (country, PEP status…), **SCD1** overwrites the old value
(history lost), while **SCD2** keeps **every version** as a separate row tagged with
`valid_from` / `valid_to` / `is_current`. The business key repeats; a **new
surrogate key** identifies each version. It's non-negotiable in banking: you must
know a customer's profile **as of** a past review date - not today's.
[Full explanation: Slowly Changing Dimensions (SCD2)](COURSE.md#11-slowly-changing-dimensions-scd2)

A SCD2 `dim_customer` looks like:

```text
customer_sk | customer_id | country_code | ... | valid_from | valid_to   | is_current
    1       |   C00003    |     IT       | ... | 2019-04-01 | 2025-03-10 |     N
  501       |   C00003    |     RU       | ... | 2025-03-10 | 9999-12-31 |     Y
```

**Task** - skeleton: [`pipeline/sas/m9_scd2.sas`](pipeline/sas/m9_scd2.sas).
A change feed is provided: **`data/customer_updates.csv`** (5 customers who changed
country and/or occupation on a given `change_date`). Starting from your
`dim_customer`, apply SCD2:

1. For each updated customer, **close** the current version: set `valid_to =
   change_date` and `is_current = 'N'`.
2. **Insert** a new version: a fresh `customer_sk`, the new attributes,
   `valid_from = change_date`, `valid_to = 31DEC9999`, `is_current = 'Y'`.
3. Leave untouched customers as a single current version
   (`valid_from` = onboarding, `valid_to = 31DEC9999`, `is_current = 'Y'`).

**Questions**

1. After SCD2, how many rows does `dim_customer` have, and how many distinct
   `customer_id`?
2. Customer **C00003** moved `IT → RU` (Blacklist!). With SCD2, what risk profile
   does a review **dated before** the change still point to? Why is that correct?
3. Which key does the **fact** table join on so that each review keeps the version
   that was **current at review date** - and not today's version?

<details>
<summary>Hint - click to reveal</summary>

- **Q1**: 5 customers get a 2nd version → **505 rows**, still **500 distinct**
  `customer_id`. Exactly one row per `customer_id` has `is_current = 'Y'`.
- **Q2**: a review dated before `2025-03-10` joins to the **`IT` version** (the one
  whose `valid_from ≤ review_date < valid_to`). That is *correct*: the bank assessed
  the customer as Italian at that time; rewriting history to `RU` would be
  misleading and non-auditable.
- **Q3**: the fact joins on the **surrogate key** of the version valid at
  `review_date` (`valid_from ≤ review_date < valid_to`), **not** on `customer_id`.
  This is *the* reason surrogate keys exist (Module 4, Q2).

</details>

---

## Expected candidate deliverables

1. The pipeline **code** in SAS (`.sas`), completed from the skeletons in `pipeline/sas/`.
   Your SQL must demonstrate the **5 patterns** of the toolbox: `GROUP BY`,
   `INNER JOIN`, `LEFT JOIN`, a **CTE** (or its SAS equivalent), and a **window
   function** (or its SAS equivalent).
2. The **written answers** to the questions of each module.
3. The Power BI file (`.pbix`) with the model, **at least one DAX measure**, and one dashboard page.
4. A short **note** (10 lines) explaining your data-quality choices.
5. *(Advanced)* A **macro-parameterized** version of the pipeline (Module 8) and a
   **SCD2** `dim_customer` (Module 9).

Good luck - and think "risk" with every decision. 
