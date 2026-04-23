# Overview

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

# Data modelling (schema)

Kimdall? Data Vault?