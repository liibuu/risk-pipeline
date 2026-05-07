# Overview

![Data preparation](../docs/data_prep.png)

I only had monthly aggregates, so I reverse-engineered plausible row-level data, intentionally introduced realistic dirty data patterns I've seen in banking, then built a full cleaning and re-aggregation pipeline, and validated the mart output against the original source totals as a reconciliation check.

Script 1 — Explode: Take aggregated CSVs → generate row-level records (the COUNT_OF_LOAN = 2 → 2 rows logic)
Script 2 — Dirty: Inject the dirty data patterns (nulls, bad formats, impossible values, duplicates)
Output: A set of "raw-ish" CSV/Parquet files that simulate what would realistically arrive from upstream systems

Landing (load files as-is) 
  → Raw (dbt: parse, cast, minimal structure) 
  → Curated (dbt: clean, deduplicate, validate) 
  → Mart (dbt: aggregate, business logic)

In a production setting, landing data would be ingested from live upstream systems via ADF/Kafka/Flink. Since this is a portfolio project, data_prep/ contains one-time scripts that simulate realistic raw banking data from the provided aggregated dataset. The pipeline itself begins at the landing layer.

# Original data (from VIB Hackathon)

## Table description

| Group | Table | Count | Aggregated column(s) |
| --- | --- | --- |--- |
| Customer profile | Data_customer | 290,223 | None |
| | Data_deposit | 1,258,424 | COUNT_CA_ACCT, AVG_CA_BALANCE, COUNT_TD_ACCT, AVG_TD_BALANCE |
| CIC | Data_card | 871,589 | COUNT_CREDITCARD, COUNT_DEBITCARD |
|  | Data_lending | 576,431 | COUNT_OF_LOAN, AVG_LOAN_AMT |
| Online banking | Data_MyVIB_Activity | 16,132,675 | ACTIVITY_NO |
|  | Data_MyVIB_Transaction | 1,418,030  | TRANS_NO, TRANS_AMOUNT |

## Column description

| Group | Table | Column | Meaning | Data type |
| --- | --- | --- | --- | --- |
| Customer profile | Data_customer | CUSTOMER_NUMBER |  |  |
|  |  | CLIENT_SEX |  |  |
|  |  | CLIENT_CREATE_DATE |  |  |
|  |  | DATE_OF_BIRTH |  |  |
|  |  | STAFF_VIB |  |  |
|  |  | IB_REGISTER_DATE |  |  |
|  |  | EB_REGISTER_CHANNEL |  |  |
|  |  | SMS |  |  |
|  |  | VERIFY_METHOD |  |  |
|  | Data_Deposit | MONTH |  |  |
|  |  | COUNT_CA_ACCT |  |  |
|  |  | AVG_CA_BALANCE |  |  |
|  |  | COUNT_TD_ACCT |  |  |
|  |  | AVG_TD_BALANCE |  |  |
|  |  | CUSTOMER_NUMBER |  |  |
| CIC | Data_card | MONTH |  |  |
|  |  | COUNT_CREDITCARD |  |  |
|  |  | COUNT_DEBITCARD |  |  |
|  |  | CUSTOMER_NUMBER |  |  |
|  | Data_lending | MONTH |  |  |
|  |  | COUNT_OF_LOAN |  |  |
|  |  | AVG_LOAN_AMOUNT |  |  |
|  |  | CUSTOMER_NUMBER |  |  |
| Online banking | Data_MyVIB_Activity | ACTIVITY_DATE |  |  |
|  |  | DAY_OF_WEEK |  |  |
|  |  | ACTIVITY_HOUR |  |  |
|  |  | ACTIVITY_NO |  |  |
|  |  | CUSTOMER_NUMBER |  |  |
|  |  | ACTIVITY_NAME |  |  |
|  | Data_MyVIB_Transaction | TRANS_LV1 |  |  |
|  |  | TRANS_LV2 |  |  |
|  |  | TRANS_DATE |  |  |
|  |  | DAY_OF_WEEK |  |  |
|  |  | TRANS_HOUR |  |  |
|  |  | TRANS_NO |  |  |
|  |  | TRANS_AMOUNT |  |  |
|  |  | CUSTOMER_NUMBER |  |  |

# Simulated data

| Group | landing | raw | curated | mart |
| --- | ---| --- | --- |--- |
| Customer profile | ? | ? | ? | Data_customer |
|  | ? | ? | ? | Data_customer |
| CIC | ? | ? | ? | Data_customer |
|  | ? | ? | ? | Data_customer |
| Online banking  | ? | ? | ? | Data_customer |
|  | ? | ? | ? | Data_customer |

# Run commands
```bash

```

# data_prep/

> **This folder is not part of the pipeline.**

In a production setting, the landing layer would receive row-level data
directly from upstream systems (ADF from on-prem SQL, Kafka/Flink from
online banking, etc.).

Since this is a portfolio project without access to real banking data, these
scripts simulate what that upstream data would realistically look like:
including the dirty patterns that are common in banking source systems.

---

## Flow

```
MS SQL Server (source tables)
  ↓ 01_explode.sql  - set-based explosion, export SELECT results as CSV
exploded/           ← row-level, clean
  ↓ 02_inject_dirty.py
landing/            ← row-level, dirty  ← upload this to ADLS landing zone
```

After uploading `landing/` to ADLS, the pipeline (dbt) takes over.

![Flow](../../docs/data_prep.png)

---

## Scripts

### `01_explode.sql` - Aggregate → Row-level (run inside MS SQL Server)

The source data is monthly-aggregated (e.g. `COUNT_OF_LOAN = 2`).
This script reverses that aggregation using a tally table join - one row
generated per unit, entirely set-based for performance.

Run the script inside SSMS or `sqlcmd` against the database where the source
tables live. Each section ends with a `SELECT *` - export those results as
CSV into `./exploded/`.

| Table | Exploded on | Output table |
|---|---|---|
| Data_customer | - (no explosion, already row-level) | - |
| Data_deposit | COUNT_CA_ACCT, COUNT_TD_ACCT | #exploded_deposit |
| Data_card | COUNT_CREDITCARD, COUNT_DEBITCARD | #exploded_card |
| Data_lending | COUNT_OF_LOAN | #exploded_lending |
| Data_MyVIB_Activity | ACTIVITY_NO | #exploded_activity |
| Data_MyVIB_Transaction | TRANS_NO | #exploded_transaction |

**Notes on approximations:**
- Individual `BALANCE` / `LOAN_AMOUNT` values use a linear spread around the
  source average (±15%). `AVG_BALANCE` / `AVG_LOAN_AMOUNT` are carried as
  separate columns for reconciliation in the curated layer.
- `TRANS_AMOUNT` is split equally across `TRANS_NO` rows. The original total
  is preserved as `TOTAL_TRANS_AMOUNT` for validation.
- Dates are spread evenly across the snapshot month using the sequence number.

### `02_inject_dirty.py` - Inject realistic dirty patterns (run locally in Python)

Takes the clean exploded CSVs and injects the kind of data quality issues
that actually exist in banking upstream systems. Run once after exporting
from SQL.

```
python 02_inject_dirty.py --input_dir ./exploded --output_dir ./landing
```

| Table | Dirty patterns injected |
|---|---|
| Data_customer | ~2% duplicate rows, mixed CLIENT_SEX formats (M/Male/1), inconsistent DATE_OF_BIRTH formats, ~1% null IB_REGISTER_DATE |
| Data_deposit | ~1.5% zero balance on active accounts, ~0.5% negative balance |
| Data_card | mixed STATUS casing (Active/active/ACTIVE), ~0.5% orphan cards with no matching customer |
| Data_lending | ~1% null LOAN_AMOUNT, ~0.5% future DISBURSEMENT_DATE, ~0.5% negative LOAN_AMOUNT |
| Data_MyVIB_Activity | ~2% null ACTIVITY_NAME, ~1% invalid ACTIVITY_HOUR (e.g. 25), ~1% late-arriving records |
| Data_MyVIB_Transaction | ~3% non-positive TRANS_AMOUNT, ~1% mismatched TRANS_LV1/LV2, ~0.5% null TRANS_HOUR |

---

## Why SQL for explosion but Python for dirty injection?

The original explosion script (`01_explode.py`) used pandas `iterrows()` which
processes one row at a time (at ~1.2M source rows), this took over 15 minutes
locally for only `data_deposit`. Since the source data already lives in MS SQL Server, rewriting the
explosion as a set-based tally join runs the same logic in seconds without
moving any data.

Dirty injection stays in Python because randomness in SQL Server is limited -
no Gaussian distribution, no Dirichlet split, and seeded reproducibility is
cumbersome. Since injection runs only once on the already-exploded CSVs
(a fixed, bounded dataset), pandas performance is acceptable and the code
stays readable.