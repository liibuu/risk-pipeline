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

| Group | Table | Column | Meaning |
| --- | --- | --- |--- |
| Customer profile | Data_customer | CUSTOMER_NUMBER |  |
|  |  | CLIENT_SEX |  |
|  |  | CLIENT_CREATE_DATE |  |
|  |  | DATE_OF_BIRTH |  |
|  |  | STAFF_VIB |  |
|  |  | IB_REGISTER_DATE |  |
|  |  | EB_REGISTER_CHANNEL |  |
|  |  | SMS |  |
|  |  | VERIFY_METHOD |  |
|  | Data_Deposit | MONTH |  |
|  |  | COUNT_CA_ACCT |  |
|  |  | AVG_CA_BALANCE |  |
|  |  | COUNT_TD_ACCT |  |
|  |  | AVG_TD_BALANCE |  |
|  |  | CUSTOMER_NUMBER |  |
| CIC | Data_card | MONTH |  |
|  |  | COUNT_CREDITCARD |  |
|  |  | COUNT_DEBITCARD |  |
|  |  | CUSTOMER_NUMBER |  |
|  | Data_lending | MONTH |  |
|  |  | COUNT_OF_LOAN |  |
|  |  | AVG_LOAN_AMOUNT |  |
|  |  | CUSTOMER_NUMBER |  |
| Online banking | Data_MyVIB_Activity | ACTIVITY_DATE |  |
|  |  | DAY_OF_WEEK |  |
|  |  | ACTIVITY_HOUR |  |
|  |  | ACTIVITY_NO |  |
|  |  | CUSTOMER_NUMBER |  |
|  |  | ACTIVITY_NAME |  |
|  | Data_MyVIB_Transaction | TRANS_LV1 |  |
|  |  | TRANS_LV2 |  |
|  |  | TRANS_DATE |  |
|  |  | DAY_OF_WEEK |  |
|  |  | TRANS_HOUR |  |
|  |  | TRANS_NO |  |
|  |  | TRANS_AMOUNT |  |
|  |  | CUSTOMER_NUMBER |  |

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