# Course - the key concepts behind the case

This is the **learning companion** to [`CASE_KYC.md`](CASE_KYC.md). The tutorial is
*hands-on* (do the tasks); this course is *reference* (understand the concepts and
revise them). Each tutorial concept box links back here for the deep dive.

Read it top-to-bottom once, then come back to any section as needed.

**Contents**

1. [The data pipeline and the staging layer](#1-the-data-pipeline-and-the-staging-layer)
2. [Data quality and profiling](#2-data-quality-and-profiling)
3. [SQL foundations](#3-sql-foundations)
4. [GROUP BY and aggregation](#4-group-by-and-aggregation)
5. [Joins: INNER and LEFT](#5-joins-inner-and-left)
6. [CTEs (WITH)](#6-ctes-with)
7. [Window functions](#7-window-functions)
8. [The SAS execution model](#8-the-sas-execution-model)
9. [Dimensional modelling and the star schema](#9-dimensional-modelling-and-the-star-schema)
10. [Surrogate keys vs business keys](#10-surrogate-keys-vs-business-keys)
11. [Slowly Changing Dimensions (SCD2)](#11-slowly-changing-dimensions-scd2)
12. [Derived data and business logic](#12-derived-data-and-business-logic)
13. [KYC and AML concepts](#13-kyc-and-aml-concepts)
14. [Power BI semantic model and DAX](#14-power-bi-semantic-model-and-dax)
15. [SAS macro language](#15-sas-macro-language)
16. [Indexing and partitioning (performance)](#16-indexing-and-partitioning-performance)

> **Recurring theme**: SAS `PROC SQL` is *ANSI-like* but **lacks CTEs and window
> functions**. For those two, this course gives the ANSI concept **and** the SAS
> idiom that replaces it.

---

## 1. The data pipeline and the staging layer

A data pipeline moves data from raw sources to something an analyst can use. The
classic flow is **ETL** (Extract → Transform → Load) - or **ELT** when you load
first and transform in the warehouse. In layers:

```text
Source (Oracle CSVs)  →  Staging  →  Transform / Model (star schema)  →  Serve (Power BI)
   raw, untouched        cleaned        facts + dimensions               dashboard
```

- **Source / raw layer** - the system extract exactly as received (`raw_customers`…).
  **You never modify it.** It is your audit reference and your replay point.
- **Staging layer** - a **cleaned, conformed copy** of the source (`stg_customers`):
  standardized casing, trimmed whitespace, `NULL`s handled, duplicates removed.
- **Model layer** - the analytics shape: a **star schema** ([§9](#9-dimensional-modelling-and-the-star-schema)), with derived
  measures ([§12](#12-derived-data-and-business-logic)).
- **Serve layer** - the consumption tool (Power BI, [§14](#14-power-bi-semantic-model-and-dax)).

(If you've heard of **bronze / silver / gold** "medallion" layers, that's the same
idea: raw → cleaned → business-ready.)

**Why a staging layer is non-negotiable:**

1. **Source integrity / auditability** - the raw layer stays pristine; you can
   always prove what arrived.
2. **Replayability / idempotence** - you can rerun the whole pipeline from raw and
   get the same result.
3. **Separation of concerns** - cleaning logic lives in one place, not scattered
   across the model.
4. **Decoupling** - if the source changes, only staging adapts; the model is shielded.

The golden rule: **never transform the source directly** - always go raw → staging
→ model.

**Used in**: Modules 1-2.

---

## 2. Data quality and profiling

**Profiling** = inspecting the data *before* transforming it: volumetrics, distinct
values, missing values, duplicates, value distributions. It is the cheapest
insurance in a pipeline and the most often skipped - **everything downstream
depends on what you catch here**.

Typical issues and how you treat them:

| Issue | Symptom | Treatment |
|---|---|---|
| Inconsistent casing | `DUPONT` / `dupont` / `Dupont` | normalize (`UPPER`/`propcase`) |
| Stray whitespace | `" Smith "` | `TRIM` / `strip()` |
| Missing values | `NULL` country | sentinel (`'XX'`) **or** explicit handling |
| Duplicates | same key twice | **deterministic** dedup rule ([§7](#7-window-functions)) |
| Referential gaps | key not in the reference | the "orphans" - default + flag ([§5](#5-joins-inner-and-left)) |

Two principles worth internalizing:

- **Deterministic, justified, reproducible** beats "arbitrary". If you keep the
  latest row per customer, *say so* - re-running must give the same answer.
- **Make problems visible, not silent.** Replacing a `NULL` country with `'XX'`
  surfaces an "unknown" bucket; dropping the row would hide it.

**Used in**: Module 1 (profiling) and Module 2 (cleaning).

---

## 3. SQL foundations

The building blocks, all identical in SAS `PROC SQL`.

- **`SELECT cols FROM t`** - choose columns. `SELECT *` = all columns. `col AS alias`
  renames a column in the output.
- **`WHERE condition`** - keep only the **rows** matching the condition. Applied
  **before** any grouping.
- **`ORDER BY col [ASC|DESC]`** - sort the result set (does not change the data,
  only the output order).
- **`SELECT DISTINCT …`** - remove duplicate rows from the **result**.
- **Subquery** - a `SELECT` nested inside another query. Two common spots:
  - in the `FROM` (an *inline view*): `… FROM (SELECT … FROM t) AS x`
  - in the `WHERE`: `… WHERE id IN (SELECT id FROM other)`

**Why it matters**: 90% of a data pipeline is `SELECT … WHERE … GROUP BY … JOIN`.
Mastering the order of operations (`FROM → WHERE → GROUP BY → HAVING → SELECT →
ORDER BY`) explains *why* you can't filter an aggregate in `WHERE` (see [§4](#4-group-by-and-aggregation)).

---

## 4. GROUP BY and aggregation

**Concept**: `GROUP BY` collapses rows that share the same key into **one row per
group**, and you apply **aggregate functions** to each group: `COUNT`, `SUM`,
`AVG`, `MIN`, `MAX`.

```sql
SELECT customer_id, COUNT(*) AS n_reviews, AVG(risk_score) AS avg_risk
FROM kyc_reviews
GROUP BY customer_id;
```

**`WHERE` vs `HAVING`** - the classic confusion:

- **`WHERE`** filters **rows**, *before* grouping.
- **`HAVING`** filters **groups**, *after* aggregation (so it can use `COUNT(*)`,
  `SUM(...)`, etc.).

```sql
-- duplicated customers: groups whose row count is > 1
SELECT customer_id, COUNT(*) AS n
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;
```

**SAS**: identical in `PROC SQL`. ⚠️ SAS has a non-standard convenience: it lets you
select a detail column that is *not* in the `GROUP BY` - it then "**re-merges**" the
aggregate back onto every row and writes a NOTE in the log. Handy, but prefer
explicit standard `GROUP BY` so your SQL stays portable.

**Used in**: Module 1 (duplicate detection, per-customer transaction totals).

---

## 5. Joins: INNER and LEFT

A join combines rows from two tables on a condition (usually a key equality).

- **`INNER JOIN`** - keeps **only** rows that match in **both** tables.
- **`LEFT JOIN`** (= `LEFT OUTER JOIN`) - keeps **all** rows of the **left** table;
  where the right table has no match, its columns come back `NULL`.

```sql
SELECT c.customer_id, r.risk_weight
FROM   customers       AS c          -- left table: every customer kept
LEFT JOIN country_ref  AS r          -- right table: matched when possible
       ON c.country_code = r.country_code;
```

**The difference is visible only on the non-matching rows.** `INNER` silently drops
them; `LEFT` keeps them with `NULL`s - which is precisely how you **detect and
handle** missing reference data (the "orphans" of [§2](#2-data-quality-and-profiling)).

**Why it matters in banking (the risk angle)**: if a customer's country is missing
from the (hand-maintained) reference, an `INNER JOIN` would make that customer
**disappear from the report**. Hiding a potentially high-risk customer is a
compliance fault. → Use `LEFT JOIN`, then deal with the `NULL`s explicitly
(default weight, quarantine, data-quality flag).

**SAS**: both native and identical in `PROC SQL`.

**Used in**: Module 3 (customer ↔ country-risk reference).

---

## 6. CTEs (WITH)

**Concept**: a **Common Table Expression** is a *named, temporary* result set that
lives only for the duration of one query. It does **not** create a stored table.

```sql
WITH cleaned AS (
    SELECT customer_id, UPPER(name) AS name, country_code
    FROM   customers
)
SELECT country_code, COUNT(*) AS n
FROM   cleaned
GROUP BY country_code;
```

**Why use it**: readability (logic reads top-to-bottom instead of deeply nested
subqueries) and reuse (reference the same CTE several times). You can chain several
CTEs: `WITH a AS (...), b AS (... FROM a ...) SELECT ... FROM b`.

**SAS - ⚠️ no `WITH`.** Classic `PROC SQL` does **not** support CTEs. Two idiomatic
equivalents:

1. **Inline view** - put the subquery directly in the `FROM`:
   ```sas
   create table result as
   select country_code, count(*) as n
   from (select customer_id, upcase(name) as name, country_code
         from customers) as cleaned
   group by country_code;
   ```
2. **Successive `CREATE TABLE` steps** - `create table cleaned as …;` then query
   `cleaned`. This is the most common SAS style and is fully auditable (each
   intermediate table is inspectable).

**Used in**: Module 2 (structuring the staging query).

---

## 7. Window functions

**Concept**: a window function computes a value **across a set of rows related to
the current row, without collapsing them** (the key difference from `GROUP BY`,
which collapses). Every input row stays, and gets an extra computed column.

```sql
func() OVER (PARTITION BY <group> ORDER BY <sort>)
```

Common functions:

- **`ROW_NUMBER()`** - 1, 2, 3… within each partition; **breaks ties arbitrarily**.
- **`RANK()`** - same rank for ties, then **gaps** (1, 1, 3…).
- **`DENSE_RANK()`** - same rank for ties, **no gaps** (1, 1, 2…).
- **`SUM() OVER (…)`** - running totals / group totals kept on every row.

**Two canonical uses in this case:**

```sql
-- (a) keep the latest row per customer (dedup)
SELECT * FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id
                                 ORDER BY onboarding_date DESC) AS rn
    FROM customers
) WHERE rn = 1;

-- (b) rank reviews by risk within each country
SELECT *, RANK() OVER (PARTITION BY country_code
                       ORDER BY risk_score DESC) AS risk_rank
FROM fact_kyc_review;
```

**SAS - ⚠️ no `OVER()`.** Classic `PROC SQL` has no window functions. The idiomatic
replacements:

- **"Keep one row per group"** → `PROC SORT` + a `DATA step` with **BY-group
  processing**:
  ```sas
  proc sort data=customers; by customer_id descending onboarding_date; run;
  data latest;
      set customers;
      by customer_id descending onboarding_date;
      if first.customer_id;      /* the latest row per customer */
  run;
  ```
- **Ranking** → `PROC RANK` with a `BY` group:
  ```sas
  proc rank data=fact out=fact_ranked descending ties=low;
      by country_code; var risk_score; ranks risk_rank;
  run;
  ```
  (`ties=low` reproduces ANSI `RANK()`.)

> Note: the `PARTITION BY` of a window function has nothing to do with **table
> partitioning** (a physical, performance concept). See [§16](#16-indexing-and-partitioning-performance).

**Used in**: Module 2 (keep-latest dedup) and Module 5 (risk ranking).

---

## 8. The SAS execution model

SAS code is a sequence of **steps**, of exactly two kinds:

- **`PROC` steps** - ready-made procedures you *call*: `PROC SQL`, `PROC IMPORT`/
  `EXPORT`, `PROC SORT`, `PROC RANK`, `PROC FREQ`, `PROC PRINT`. End with `run;`
  (or `quit;` for `PROC SQL`).
- **`DATA` steps** - SAS's own **row-by-row** engine: `data out; set in; … run;`.
  Used for what SQL can't express cleanly (BY-group logic, building keys, SCD2).

Essentials:

- **Datasets & libraries**: tables are "datasets", stored in libraries. **`WORK`**
  is the temporary library (cleared at session end); `work.customers` ≡ `customers`.
- **Read the LOG**: SAS rarely stops - it writes **NOTE / WARNING / ERROR** and
  keeps going. A clean log is part of the deliverable.
- **DATA-step idioms**:
  - `set ds;` reads a dataset row by row.
  - `by key;` + `if first.key;` / `if last.key;` - process **groups** (needs a prior
    `PROC SORT`). SAS's way of "one row per group".
  - `retain x;` and the **sum statement** `x + expr;` carry a value **across rows**
    (running totals). ⚠️ **Trap**: `x + expr;` is *not* a per-row assignment; if you
    mean per-row, write `x = x + expr;`.
  - functions: `strip()`, `propcase()`, `missing()`, `coalesce()`/`coalescec()`,
    `input()`/`put()` (text ↔ date/number).
- **Comments**: `/* ... */` or `* ... ;`.

---

## 9. Dimensional modelling and the star schema

**The problem it solves**: operational (OLTP) tables are normalized for *writing*
fast and avoiding redundancy. They are painful to *analyze* (many joins, no clear
"what do I measure?"). Dimensional modelling reshapes data for *reading/analytics*.

**The two building blocks:**

- **Fact table** - the *measurable events*, at a chosen **grain** (one row =
  one event). Holds **measures** (numbers you aggregate: `risk_score`,
  `alert_count`) and **foreign keys** to dimensions.
- **Dimension tables** - the *context* of those events: who (`dim_customer`),
  where (`dim_country`), when (`dim_date`). Holds descriptive **attributes** you
  slice and filter by.

**Grain** = what one fact row represents. **Define it first**; everything else
follows. Here: *one KYC review*. A customer with two reviews → two fact rows.

A **star schema** = one fact table in the centre, dimensions around it, each joined
by a single key - the diagram looks like a star.

```text
                 dim_date
                    |
  dim_customer --- fact_kyc_review --- dim_country
```

**Advantages of the star schema:**

1. **Simplicity** - analysts and BI tools understand fact-and-dimensions instantly.
2. **Performance** - few, simple joins (fact → dimension on one key); BI engines are
   optimized for exactly this shape.
3. **Consistency** - a measure (e.g. risk rate) is defined once on the fact and
   reused everywhere.
4. **Slice-and-dice** - filtering by any dimension attribute "just works" in Power
   BI (by country, by month, by risk category…).

**Star vs snowflake**: a *snowflake* further normalizes dimensions into sub-tables
(more joins, less redundancy). The **star denormalizes** dimensions on purpose -
fewer joins, faster, simpler. For BI you almost always want a **star**.

**Used in**: Module 4.

---

## 10. Surrogate keys vs business keys

- **Business key (natural key)** - the identifier that comes from the source/business
  (e.g. `customer_id = 'C00123'`). Meaningful, but can change, can be reused, can
  differ across systems.
- **Surrogate key (SK)** - a meaningless **integer** (1, 2, 3…) generated by the
  warehouse, used to link fact ↔ dimension.

**Why surrogate keys:**

1. **Performance** - integer joins are faster and lighter than string joins.
2. **Stability** - if a business key changes (or two systems use different ones), the
   SK shields the fact table from the churn.
3. **Historization** - this is the decisive one: with **SCD2** ([§11](#11-slowly-changing-dimensions-scd2)) the *same*
   `customer_id` has **several versions over time**, each needing its own identity.
   The SK gives each version a unique key, so a fact row can point to the *exact
   version that was valid at the time*.

So: dimensions carry **both** - the business key (to look the entity up) and the SK
(to be referenced by facts).

**Used in**: Module 4 (built) and Module 9 (the payoff).

---

## 11. Slowly Changing Dimensions (SCD2)

Entities change over time: a customer moves country, becomes a PEP, changes job.
How a dimension **absorbs change** is described by its **SCD type**:

- **SCD0** - never change (e.g. a birth date).
- **SCD1 (overwrite)** - replace the old value. Simple, but you **lose history**: you
  can no longer tell what the value *used to be*.
- **SCD2 (historize)** - keep **every version** as a separate row, tagged with a
  validity window and a current flag.

**SCD2 columns:**

| Column | Meaning |
|---|---|
| `customer_sk` | a **new** surrogate key **per version** |
| `customer_id` | the business key, **repeated** across versions |
| `valid_from` / `valid_to` | the period during which this version was true |
| `is_current` | `Y` for the active version, `N` for closed ones |

```text
customer_sk | customer_id | country_code | valid_from | valid_to   | is_current
    3        |   C00003    |     IT       | 2019-04-01 | 2025-03-10 |     N
  503        |   C00003    |     RU       | 2025-03-10 | 9999-12-31 |     Y
```

**How you apply a change**: (a) **close** the old version (`valid_to = change_date`,
`is_current = 'N'`), and (b) **insert** a new version (fresh SK, new attributes,
`valid_from = change_date`, `valid_to = 31DEC9999`, `is_current = 'Y'`).

**The point-in-time join (why it all matters)**: a fact (a KYC review) must reflect
the customer **as of the review date**, not as of today. So the fact joins the
**version valid at that date**:

```sql
... ON review_date >= valid_from AND review_date < valid_to
```

A review dated before the move sees `IT`; one after sees `RU`. Rewriting history
(what SCD1 does) would make a past review look like it used today's data - a
regulatory and audit problem. This is exactly **why surrogate keys exist** ([§10](#10-surrogate-keys-vs-business-keys)).

**Used in**: Module 9.

---

## 12. Derived data and business logic

**Concept**: a **derived field** exists in **no source** - you *compute* it inside
the pipeline from other signals. The `risk_score` is the example: it is built from
country `risk_weight` + `pep_flag` + `alert_count` + `embargo_flag`. This is where
raw data turns into **business value**.

Key questions for any derived field:

- **Where to compute it?** Prefer **freezing it in the fact table** rather than
  recomputing it in the BI tool. Benefits: **reproducibility** (a past review's
  score never silently changes), **performance** (no recompute on every dashboard
  refresh), **auditability** (you know the score assigned *as of* the review date).
- **How to encode business rules cleanly?**
  - **Weighting** - decide what each signal is worth, and justify it.
  - **Bounding** - keep the score in range (`min(score, 100)`).
  - **Floor / hard rules** - some constraints are non-negotiable: a customer under
    **embargo** must *never* be "Low" → a floor `risk_score = max(risk_score, 80)`
    guarantees it, where a plain additive could fail.
- **Categorize** - turning a continuous score into bands (`Low / Medium / High /
  Critical`) makes it actionable for Compliance.

**Used in**: Module 5.

---

## 13. KYC and AML concepts

The business vocabulary you are modelling.

- **KYC (Know Your Customer)** - the obligation to identify and understand customers.
- **AML (Anti-Money-Laundering)** / **CFT** (counter-financing of terrorism) - the
  goal the regulation serves.
- **PEP (Politically Exposed Person)** - someone in a prominent public function
  (higher corruption/bribery risk) → enhanced scrutiny.
- **Sanctions / watchlists** - lists of persons/entities you must not deal with
  (e.g. OFAC, EU). Screening is usually by **name** (hard: homonyms, transliteration).
- **FATF / GAFI** - the international body; classifies jurisdictions
  (Compliant / Greylist / Blacklist) by AML risk - the basis of our country matrix.
- **Embargo** - a country you cannot transact with at all (strongest restriction).
- **EDD (Enhanced Due Diligence)** - the deeper review applied to higher-risk
  customers.
- **Risk scoring** - combining signals (country risk, PEP, alerts, embargo) into a
  single score/category to prioritize Compliance work (see [§12](#12-derived-data-and-business-logic)).

**Used in**: throughout (it's the *why* behind every decision).

---

## 14. Power BI semantic model and DAX

SAS produces **tables**; **Power BI** turns them into a **semantic model** and a
dashboard.

- **Relationships** - you connect the fact to each dimension on the **surrogate
  key**, cardinality **many-to-one** (many fact rows → one dimension row), filter
  direction single (dimension filters fact). This *is* the star schema, expressed in
  Power BI. Relate on **SKs, not names** (names aren't unique and can change).
- **Calculated column vs measure** - the crucial DAX distinction:
  - a **calculated column** is computed **row by row at refresh** and **stored**;
  - a **measure** is computed **on the fly**, according to the **filter context** of
    the visual (the current country, month, slicer…).
  A KPI like "% high-risk customers" must react to filters → it's a **measure**.

```dax
High Risk Customer Rate =
DIVIDE (
    CALCULATE ( DISTINCTCOUNT ( fact_kyc_review[customer_sk] ),
                fact_kyc_review[risk_category] IN { "High", "Critical" } ),
    DISTINCTCOUNT ( fact_kyc_review[customer_sk] )
)
```

- **`CALCULATE`** changes the filter context; **`DIVIDE`** is safe division (handles
  divide-by-zero). Good measures answer a **business question** and are
  **actionable**.

**Used in**: Module 6.

---

## 15. SAS macro language

The **macro language** is a **code generator**: it runs **before** SAS and writes the
SAS code that actually executes. It manipulates **text**, not data.

- **Macro variables** (`&name`) - text placeholders. `%let DATA = /home/...;` then
  `&DATA` is replaced by that text at **compile time**.
- **Macros** (`%macro name(params); … %mend;`) - reusable, **parameterized** blocks
  of SAS code, called `%name(...)`. Inside you can branch (`%if … %then …`) or loop
  (`%do i = 1 %to n …`).

**Macro variable vs data-step variable** - different worlds:

| | Macro variable `&x` | Data-step variable |
|---|---|---|
| Exists at | **compile time** (before the step runs) | **run time** (per observation) |
| Holds | always **text** | a typed value |
| Purpose | *writes* the code | *processes* the data |

**Why banks rely on it**: the same pipeline must run **every reporting day**, **per
entity**, **per as-of date**. A parameterized `%run_pipeline(as_of=2025-03-31)` is
scheduled and audited instead of being copy-pasted. Turn on `options mprint;` to see
the **generated** code in the log (essential for debugging).

**Used in**: Module 8.

---

## 16. Indexing and partitioning (performance)

The two classic "make big-table queries fast" concepts. They matter a lot in
banking, where tables hold millions to billions of rows. The data in this case is
tiny, so this section is conceptual (interview-oriented) rather than something you
would feel on 500 rows.

### Indexes

An index is an auxiliary structure (typically a B-tree) that lets the engine find
rows by a column's value without scanning the whole table, like the index at the
back of a book.

- Speeds up: lookups (`WHERE col = x`), joins on the indexed key, and sometimes
  `ORDER BY` / `GROUP BY`.
- Costs: extra storage, and slower writes (every insert/update must maintain the
  index). So you index the columns you filter or join on, not every column.
- In SQL / Oracle: `CREATE INDEX idx_cust ON customers(customer_id);`
- In SAS: `PROC SQL` (`create index ...`) or `PROC DATASETS ... INDEX CREATE`. SAS
  uses the index to speed up `WHERE` and `BY` processing.
- Rule of thumb: index high-selectivity columns used in joins/filters
  (e.g. `customer_id`, `account_id`).

### Partitioning

Partitioning physically splits one large table into smaller segments by a key, so a
query only scans the relevant segments ("partition pruning").

- Common schemes: **range** (e.g. by month of `txn_date`), **list** (by
  country/region), **hash** (even spread).
- Banking example: a `transactions` table partitioned by month, so a query on "last
  month" reads a single partition, and old partitions can be archived or dropped
  cheaply.
- Benefits: query performance (pruning), manageability (load/drop per partition),
  and parallelism.
- This is mainly a database (Oracle) feature; in SAS you approximate it with
  separate datasets or views, or you rely on the source database's partitioning.

### `PARTITION BY` vs table partitioning - don't confuse them

Same word, two different things:

- A window function's `PARTITION BY` ([§7](#7-window-functions)) defines groups for a
  per-row calculation. It is a query construct, with no physical storage effect.
- Table partitioning is a physical storage and performance choice on the table
  itself.

**Used in**: conceptual / interview (the case data is too small to benefit).

---

*Back to the hands-on: [`CASE_KYC.md`](CASE_KYC.md).*
