# Data Wizards - KYC Data Pipeline Case

> ⚠️ **Educational project - 100% fictitious data.** Everything here is synthetic,
> generated locally with random fakers. It uses **no real data** and is **not
> affiliated with, nor derived from, any company, bank or institution**. The
> scenario is a generic, illustrative banking example.

A mini **tutorial** project to practice the data chain typical of the Risk /
Compliance functions of a large bank:

> **System source (Oracle) → ETL (SAS / PROC SQL) → Star schema → Power BI**

You work on **fake KYC data**. You reconcile an Oracle-style database with an
**Excel reference maintained by Compliance**, build a **star schema**, derive a
**risk score**, and present it all in a **Power BI dashboard** with a **DAX
measure**.

## Target technologies (and why)

| Tech | Role in the case | Why it matters in banking |
|---|---|---|
| **SAS** (PROC SQL + DATA step) | The whole ETL + star schema build | Heavily used in risk/compliance |
| **CSV / Excel** | System source + country risk reference (business data) | The reality on the ground |
| **Power BI** | Semantic model + dashboard + DAX | Standard reporting tool |

The pipeline is **100% SAS**, run for free in **SAS Studio** via
[SAS OnDemand for Academics](https://www.sas.com/ondemand) - no install needed.

## Quick start

1. Open **[`CASE_KYC.md`](CASE_KYC.md)** and follow **Module 0** (create a free SAS
   OnDemand account, open SAS Studio).
2. Upload the 5 data files from **`data/`** (4 CSV + the `.xlsx`) into SAS Studio.
3. Work through the modules **in order**, completing the SAS skeletons in
   `pipeline/sas/`. The case is **progressive**: you choose how far you go, and any
   milestone is a valid place to stop. Modules 0 → 3 already make a solid start,
   0 → 6 is the full core, 8 → 9 are advanced (7 is an optional bonus). See
   [How far should you go?](#how-far-should-you-go) for what each level proves.

> The fake data is **committed to the repo** (fixed, identical for everyone) - you
> don't generate anything, just use the files in `data/`.

## Layout

```text
data-wizards-kyc/
├── README.md                       # this file
├── CASE_KYC.md                     # the step-by-step tutorial (collapsible hints inside)
├── COURSE.md                       # concept course (SQL, star schema, SCD2, …) - learn/revise
├── data/                           # the fake sources (provided, ready to upload)
│   ├── customers.csv               # ┐
│   ├── accounts.csv                # │ the Oracle DB extract
│   ├── transactions.csv            # │
│   ├── kyc_reviews.csv             # ┘
│   ├── customer_updates.csv        # change feed for the SCD2 module
│   └── country_risk_reference.xlsx # Compliance reference (intentionally incomplete)
├── pipeline/
│   └── sas/                        # SAS skeletons to complete (the pipeline)
├── powerbi/
│   └── README.md                   # data model + DAX measure + dashboard
└── solutions/                      # full reference solution + explanation (spoilers)
    ├── SOLUTION.md
    └── sas/
```

## Pedagogical flow

Each module: **concept** → **task** → **questions** → **collapsible
hint**. You answer the questions **before** expanding the hint. The pipeline code
is **not given**: you complete it from the skeletons - that's the point.

> **Learn the theory in [`COURSE.md`](COURSE.md)** - a standalone concept course
> (ETL & staging, data quality, SQL, CTEs, window functions, SAS execution model,
> star schema, surrogate keys, SCD2, derived data, KYC, Power BI, SAS macros,
> indexing & partitioning). The tutorial links to it; read it to learn or revise.

| Module | Topic | Key skill | Skeleton | Time |
|---|---|---|---|---|
| 0 | Setup | Environment, KYC context | - | 20-30 min |
| 1 | Explore the source | Profiling / data quality | `m1-2_extract_clean.sas` | 30-45 min |
| 2 | Staging | Cleaning, dedup, NULL handling | `m1-2_extract_clean.sas` | 45-60 min |
| 3 | Excel join | LEFT JOIN of heterogeneous sources | `m3_join_excel.sas` | 30-45 min |
| 4 | Star schema | Fact/dimension, grain, surrogate keys | `m4-5_star_schema.sas` | 60-90 min |
| 5 | Risk score | Derived data, business logic | `m4-5_star_schema.sas` | 30-45 min |
| 6 | Power BI | Semantic model, DAX, dashboard | `powerbi/README.md` | 60-90 min |
| 7 | Watchlist (bonus) | Name screening, fuzzy matching | - | 30-45 min |
| 8 | Macro language (advanced) | Parameterized, reusable pipeline | `m8_macro.sas` | 30-45 min |
| 9 | SCD2 (advanced) | Dimension historization, point-in-time | `m9_scd2.sas` | 45-60 min |

> **Core (Modules 0→6): ≈ 4.5-6.5 h.** Full case (0→9): **≈ 7-9 h** of
> hands-on time. Add more if SAS or Power BI is new to you. Note: the SAS OnDemand
> account approval can take a few hours - request it early.

A complete reference solution with explanations lives in
**[`solutions/`](solutions/)** - spoilers, open only after attempting.

## Candidate deliverables

1. The completed **SAS pipeline** (`.sas` files).
2. The **written answers** to the questions.
3. The **`.pbix`**: model + ≥ 1 DAX measure + 1 dashboard page.
4. A **note** (~10 lines) justifying your data-quality choices.

## How far should you go?

> **Non-negotiable baseline: know *all* the concepts in [`COURSE.md`](COURSE.md).**
> Whatever amount of the case you complete, mastering the full course (SQL, CTEs,
> window functions, star schema, surrogate keys, SCD2, KYC, Power BI, SAS macros) is
> the **key** minimum. It is what every level below assumes - and what an
> interviewer will probe first.

You don't have to *do* everything - but be honest about what each level proves.
Reading the **course** teaches you to *talk* about the concepts; **finishing** the
case proves you can *do* it. The jump that matters is going from "I understand" to
"I made it run".

| Level | What you've done | What it proves |
|---|---|---|
| **Good start** (interview-credible) | [`COURSE.md`](COURSE.md) mastered + Modules 0→3 | You know the vocabulary and can reason about joins / data quality |
| **Solid** (convincing) | + Modules 4-6 **finished and executed** (the full star schema + a Power BI dashboard) | You can *build* an analytics pipeline end-to-end, not just describe it |
| **Differentiating** | + Modules 8-9 (macro, SCD2) | You grasp industrialization and historization - senior-grade concerns |

> **The rule of thumb**: *the course to understand, the finished core (0→6) to
> convince.* Talking about a `LEFT JOIN` is not the same as having debugged the 81
> orphan customers yourself - and that difference is exactly what a reviewer feels.

---
*All data is fictitious and synthetic. No real data is used.*
