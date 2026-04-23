/*
01_explode.sql
--------------
One-time script: explodes aggregated source tables into row-level records
that simulate raw upstream data.
*/

-- -- tally table (reused by all explosions below) -----------------------------
DROP TABLE IF EXISTS #tally;

SELECT TOP 3000
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
INTO #tally
FROM sys.objects a
CROSS JOIN sys.objects b;

GO

-- -- Data_deposit → exploded_deposit ------------------------------------------
/*
Explodes COUNT_CA_ACCT and COUNT_TD_ACCT into individual account rows.
Deposit accounts can be closed over time, causing cumulative counts to decrease. 
A FIFO close logic is applied to assign a CLOSE_DATE to the earliest opened accounts when a drop in count is detected.

AVG_CA_BALANCE / AVG_TD_BALANCE are carried as AVG_BALANCE for reconciliation
in the curated layer.

Individual BALANCE is approximated as AVG_BALANCE ± small deterministic offset
using the sequence number - pure SQL has no Gaussian noise, so we use a
lightweight linear spread: seq / count * 0.3 * avg as the perturbation.
*/
-- -- Data_deposit → exploded_deposit ------------------------------------------
DROP TABLE IF EXISTS #exploded_deposit;

WITH ca_delta AS (
    SELECT
        CUSTOMER_NUMBER,
        MONTH,
        COUNT_CA_ACCT,
        AVG_CA_BALANCE,
        COUNT_CA_ACCT - LAG(COUNT_CA_ACCT, 1, 0)
            OVER (PARTITION BY CUSTOMER_NUMBER ORDER BY MONTH) AS CA_DELTA
    FROM Data_deposit
),
ca_opens AS (
    SELECT
        d.CUSTOMER_NUMBER,
        d.MONTH                                         AS OPEN_MONTH,
        d.AVG_CA_BALANCE,
        ROW_NUMBER() OVER (
            PARTITION BY d.CUSTOMER_NUMBER ORDER BY d.MONTH
        )                                               AS ACCT_SEQ
    FROM ca_delta d
    JOIN #tally t ON t.n <= d.CA_DELTA
    WHERE d.CA_DELTA > 0
),
ca_closes AS (
    SELECT
        d.CUSTOMER_NUMBER,
        d.MONTH                                         AS CLOSE_MONTH,
        ROW_NUMBER() OVER (
            PARTITION BY d.CUSTOMER_NUMBER ORDER BY d.MONTH
        )                                               AS CLOSE_SEQ
    FROM ca_delta d
    JOIN #tally t ON t.n <= ABS(d.CA_DELTA)
    WHERE d.CA_DELTA < 0
),
ca AS (
    SELECT
        CONCAT('CA_',
            CONVERT(VARCHAR, HASHBYTES('MD5',
                CONCAT(o.CUSTOMER_NUMBER, '_CA_', o.ACCT_SEQ)), 2)
        )                                               AS ACCOUNT_ID,
        o.CUSTOMER_NUMBER,
        d.MONTH,
        'CURRENT'                                       AS ACCOUNT_TYPE,
        ROUND(
            d.AVG_CA_BALANCE
            * (1.0 + (o.ACCT_SEQ - (d.COUNT_CA_ACCT + 1) / 2.0)
                   / NULLIF(d.COUNT_CA_ACCT, 1) * 0.3),
            2
        )                                               AS BALANCE,
        ROUND(d.AVG_CA_BALANCE, 2)                      AS AVG_BALANCE,
        DATEADD(
            DAY,
            (o.ACCT_SEQ - 1) % DAY(EOMONTH(CONVERT(DATE, o.OPEN_MONTH))),
            DATEFROMPARTS(YEAR(o.OPEN_MONTH), MONTH(o.OPEN_MONTH), 1)
        )                                               AS OPEN_DATE,
        DATEADD(
            DAY,
            (c.CLOSE_SEQ - 1) % DAY(EOMONTH(CONVERT(DATE, c.CLOSE_MONTH))),
            DATEFROMPARTS(YEAR(c.CLOSE_MONTH), MONTH(c.CLOSE_MONTH), 1)
        )                                               AS CLOSE_DATE,
        o.ACCT_SEQ                                      AS SEQ
    FROM Data_deposit d
    JOIN ca_opens o
        ON  o.CUSTOMER_NUMBER = d.CUSTOMER_NUMBER
        AND o.ACCT_SEQ <= d.COUNT_CA_ACCT
    LEFT JOIN ca_closes c
        ON  c.CUSTOMER_NUMBER = o.CUSTOMER_NUMBER
        AND c.CLOSE_SEQ = o.ACCT_SEQ
),
td_delta AS (
    SELECT
        CUSTOMER_NUMBER,
        MONTH,
        COUNT_TD_ACCT,
        AVG_TD_BALANCE,
        COUNT_TD_ACCT - LAG(COUNT_TD_ACCT, 1, 0)
            OVER (PARTITION BY CUSTOMER_NUMBER ORDER BY MONTH) AS TD_DELTA
    FROM Data_deposit
),
td_opens AS (
    SELECT
        d.CUSTOMER_NUMBER,
        d.MONTH                                         AS OPEN_MONTH,
        d.AVG_TD_BALANCE,
        ROW_NUMBER() OVER (
            PARTITION BY d.CUSTOMER_NUMBER ORDER BY d.MONTH
        )                                               AS ACCT_SEQ
    FROM td_delta d
    JOIN #tally t ON t.n <= d.TD_DELTA
    WHERE d.TD_DELTA > 0
),
td_closes AS (
    SELECT
        d.CUSTOMER_NUMBER,
        d.MONTH                                         AS CLOSE_MONTH,
        ROW_NUMBER() OVER (
            PARTITION BY d.CUSTOMER_NUMBER ORDER BY d.MONTH
        )                                               AS CLOSE_SEQ
    FROM td_delta d
    JOIN #tally t ON t.n <= ABS(d.TD_DELTA)
    WHERE d.TD_DELTA < 0
),
td AS (
    SELECT
        CONCAT('TD_',
            CONVERT(VARCHAR, HASHBYTES('MD5',
                CONCAT(o.CUSTOMER_NUMBER, '_TD_', o.ACCT_SEQ)), 2)
        )                                               AS ACCOUNT_ID,
        o.CUSTOMER_NUMBER,
        d.MONTH,
        'TERM_DEPOSIT'                                  AS ACCOUNT_TYPE,
        ROUND(
            d.AVG_TD_BALANCE
            * (1.0 + (o.ACCT_SEQ - (d.COUNT_TD_ACCT + 1) / 2.0)
                   / NULLIF(d.COUNT_TD_ACCT, 1) * 0.3),
            2
        )                                               AS BALANCE,
        ROUND(d.AVG_TD_BALANCE, 2)                      AS AVG_BALANCE,
        DATEADD(
            DAY,
            (o.ACCT_SEQ - 1) % DAY(EOMONTH(CONVERT(DATE, o.OPEN_MONTH))),
            DATEFROMPARTS(YEAR(o.OPEN_MONTH), MONTH(o.OPEN_MONTH), 1)
        )                                               AS OPEN_DATE,
        DATEADD(
            DAY,
            (c.CLOSE_SEQ - 1) % DAY(EOMONTH(CONVERT(DATE, c.CLOSE_MONTH))),
            DATEFROMPARTS(YEAR(c.CLOSE_MONTH), MONTH(c.CLOSE_MONTH), 1)
        )                                               AS CLOSE_DATE,
        o.ACCT_SEQ                                      AS SEQ
    FROM Data_deposit d
    JOIN td_opens o
        ON  o.CUSTOMER_NUMBER = d.CUSTOMER_NUMBER
        AND o.ACCT_SEQ <= d.COUNT_TD_ACCT
    LEFT JOIN td_closes c
        ON  c.CUSTOMER_NUMBER = o.CUSTOMER_NUMBER
        AND c.CLOSE_SEQ = o.ACCT_SEQ
)
SELECT * INTO #exploded_deposit
FROM (
    SELECT ACCOUNT_ID, CUSTOMER_NUMBER, MONTH, ACCOUNT_TYPE,
           CASE WHEN BALANCE IS NULL THEN AVG_BALANCE ELSE BALANCE END AS BALANCE,
           OPEN_DATE, CLOSE_DATE
    FROM ca
    UNION ALL
    SELECT ACCOUNT_ID, CUSTOMER_NUMBER, MONTH, ACCOUNT_TYPE,
           CASE WHEN BALANCE IS NULL THEN AVG_BALANCE ELSE BALANCE END AS BALANCE,
           OPEN_DATE, CLOSE_DATE
    FROM td
) AS selected;

SELECT * FROM #exploded_deposit;

GO

-- -- Data_card → exploded_card -------------------------------------------------
/*
Explodes COUNT_CREDITCARD and COUNT_DEBITCARD into individual card rows.
STATUS is assigned as ACTIVE to be injected dirtiness in the next step.
*/
DROP TABLE IF EXISTS #exploded_card;

WITH credit_delta AS (
    SELECT
        CUSTOMER_NUMBER,
        MONTH,
        COUNT_CREDITCARD,
        COUNT_CREDITCARD - LAG(COUNT_CREDITCARD, 1, 0)
            OVER (PARTITION BY CUSTOMER_NUMBER ORDER BY MONTH) AS CR_NEW
    FROM Data_card
),
credit_opens AS (
    SELECT
        d.CUSTOMER_NUMBER,
        d.MONTH                                         AS OPEN_MONTH,
        ROW_NUMBER() OVER (
            PARTITION BY d.CUSTOMER_NUMBER ORDER BY d.MONTH
        )                                               AS CARD_SEQ
    FROM credit_delta d
    JOIN #tally t ON t.n <= d.CR_NEW
    WHERE d.CR_NEW > 0
),
credit AS (
    SELECT
        CONCAT('CR_',
            CONVERT(VARCHAR, HASHBYTES('MD5',
                CONCAT(o.CUSTOMER_NUMBER, '_CR_', o.CARD_SEQ)), 2)
        )                                               AS CARD_ID,
        o.CUSTOMER_NUMBER,
        d.MONTH,
        'CREDIT'                                        AS CARD_TYPE,
        DATEADD(
            DAY,
            (o.CARD_SEQ - 1) % DAY(EOMONTH(CONVERT(DATE, o.OPEN_MONTH))),
            DATEFROMPARTS(YEAR(o.OPEN_MONTH), MONTH(o.OPEN_MONTH), 1)
        )                                               AS ISSUE_DATE,
        o.CARD_SEQ                                      AS SEQ
    FROM Data_card d
    JOIN credit_opens o
        ON  o.CUSTOMER_NUMBER = d.CUSTOMER_NUMBER
        AND o.CARD_SEQ <= d.COUNT_CREDITCARD
),
debit_delta AS (
    SELECT
        CUSTOMER_NUMBER,
        MONTH,
        COUNT_DEBITCARD,
        COUNT_DEBITCARD - LAG(COUNT_DEBITCARD, 1, 0)
            OVER (PARTITION BY CUSTOMER_NUMBER ORDER BY MONTH) AS DE_NEW
    FROM Data_card
),
debit_opens AS (
    SELECT
        d.CUSTOMER_NUMBER,
        d.MONTH                                         AS OPEN_MONTH,
        ROW_NUMBER() OVER (
            PARTITION BY d.CUSTOMER_NUMBER ORDER BY d.MONTH
        )                                               AS CARD_SEQ
    FROM debit_delta d
    JOIN #tally t ON t.n <= d.DE_NEW
    WHERE d.DE_NEW > 0
),
debit AS (
    SELECT
        CONCAT('DE_',
            CONVERT(VARCHAR, HASHBYTES('MD5',
                CONCAT(o.CUSTOMER_NUMBER, '_DE_', o.CARD_SEQ)), 2)
        )                                               AS CARD_ID,
        o.CUSTOMER_NUMBER,
        d.MONTH,
        'DEBIT'                                         AS CARD_TYPE,
        DATEADD(
            DAY,
            (o.CARD_SEQ - 1) % DAY(EOMONTH(CONVERT(DATE, o.OPEN_MONTH))),
            DATEFROMPARTS(YEAR(o.OPEN_MONTH), MONTH(o.OPEN_MONTH), 1)
        )                                               AS ISSUE_DATE,
        o.CARD_SEQ                                      AS SEQ
    FROM Data_card d
    JOIN debit_opens o
        ON  o.CUSTOMER_NUMBER = d.CUSTOMER_NUMBER
        AND o.CARD_SEQ <= d.COUNT_DEBITCARD
)
SELECT * INTO #exploded_card 
FROM (
    SELECT CARD_ID, CUSTOMER_NUMBER, CARD_TYPE, ISSUE_DATE, 'ACTIVE' AS STATUS FROM credit
    UNION ALL
    SELECT CARD_ID, CUSTOMER_NUMBER, CARD_TYPE, ISSUE_DATE, 'ACTIVE' AS STATUS FROM debit
    ) AS selected;

SELECT * FROM #exploded_card;

GO

-- -- Data_lending → exploded_lending ------------------------------------------
/*
Explodes COUNT_OF_LOAN into individual loan rows.
Loans can be closed over time, causing cumulative counts to decrease. 
A FIFO close logic is applied to assign a CLOSE_DATE to the earliest loan when a drop in count is detected.
*/
DROP TABLE IF EXISTS #exploded_lending;

WITH lending_delta AS (
    SELECT
        CUSTOMER_NUMBER,
        MONTH,
        COUNT_OF_LOAN,
        AVG_LOAN_AMOUNT,
        COUNT_OF_LOAN - LAG(COUNT_OF_LOAN, 1, 0)
            OVER (PARTITION BY CUSTOMER_NUMBER ORDER BY MONTH) AS LOAN_DELTA
    FROM Data_lending
),
loan_opens AS (
    -- one row per new loan, tagged with the month it was disbursed
    SELECT
        d.CUSTOMER_NUMBER,
        d.MONTH                                         AS OPEN_MONTH,
        d.AVG_LOAN_AMOUNT,
        ROW_NUMBER() OVER (
            PARTITION BY d.CUSTOMER_NUMBER ORDER BY d.MONTH
        )                                               AS LOAN_SEQ
    FROM lending_delta d
    JOIN #tally t ON t.n <= d.LOAN_DELTA
    WHERE d.LOAN_DELTA > 0
),
loan_closes AS (
    -- one row per paid-off loan, tagged with the month it was closed
    -- LOAN_SEQ here represents the nth loan to be closed (FIFO)
    SELECT
        d.CUSTOMER_NUMBER,
        d.MONTH                                         AS CLOSE_MONTH,
        ROW_NUMBER() OVER (
            PARTITION BY d.CUSTOMER_NUMBER ORDER BY d.MONTH
        )                                               AS CLOSE_SEQ
    FROM lending_delta d
    JOIN #tally t ON t.n <= ABS(d.LOAN_DELTA)
    WHERE d.LOAN_DELTA < 0
),
loan AS (
SELECT
    CONCAT('LN_',
        CONVERT(VARCHAR, HASHBYTES('MD5',
            CONCAT(o.CUSTOMER_NUMBER, '_LN_', o.LOAN_SEQ)), 2)
    )                                                   AS LOAN_ID,
    o.CUSTOMER_NUMBER,
    d.MONTH,
    ROUND(
        d.AVG_LOAN_AMOUNT
        * (1.0 + (o.LOAN_SEQ - (d.COUNT_OF_LOAN + 1) / 2.0)
               / NULLIF(d.COUNT_OF_LOAN, 1) * 0.3),
        2
    )                                                   AS LOAN_AMOUNT,
    ROUND(d.AVG_LOAN_AMOUNT, 2)                         AS AVG_LOAN_AMOUNT,
    DATEADD(
        DAY,
        (o.LOAN_SEQ - 1) % DAY(EOMONTH(CONVERT(DATE, o.OPEN_MONTH))),
        DATEFROMPARTS(YEAR(o.OPEN_MONTH), MONTH(o.OPEN_MONTH), 1)
    )                                                   AS DISBURSEMENT_DATE,
    -- FIFO: the nth loan opened is the nth loan closed
    DATEADD(
        DAY,
        (c.CLOSE_SEQ - 1) % DAY(EOMONTH(CONVERT(DATE, c.CLOSE_MONTH))),
        DATEFROMPARTS(YEAR(c.CLOSE_MONTH), MONTH(c.CLOSE_MONTH), 1)
    )                                                   AS PAYOFF_DATE,
    o.LOAN_SEQ                                          AS SEQ
FROM Data_lending d
JOIN loan_opens o
    ON  o.CUSTOMER_NUMBER = d.CUSTOMER_NUMBER
    AND o.LOAN_SEQ <= d.COUNT_OF_LOAN
LEFT JOIN loan_closes c
    ON  c.CUSTOMER_NUMBER = o.CUSTOMER_NUMBER
    AND c.CLOSE_SEQ = o.LOAN_SEQ
)

SELECT LOAN_ID, CUSTOMER_NUMBER, CASE WHEN LOAN_AMOUNT IS NULL THEN AVG_LOAN_AMOUNT ELSE LOAN_AMOUNT END AS LOAN_AMOUNT, DISBURSEMENT_DATE, PAYOFF_DATE
INTO #exploded_lending
FROM loan;

SELECT * FROM #exploded_lending;

GO

-- -- Data_MyVIB_Activity → exploded_activity -----------------------------------
/*
Explodes ACTIVITY_NO into individual event rows.
Timestamp is built by spreading events evenly across the activity hour using seq to assign minutes.
*/
DROP TABLE IF EXISTS #exploded_activity;

SELECT
    CONCAT('EV_',
        CONVERT(VARCHAR, HASHBYTES('MD5',
            CONCAT(a.CUSTOMER_NUMBER, '_', a.ACTIVITY_DATE, '_', a.ACTIVITY_HOUR, '_', t.n)), 2)
    )                                                   AS EVENT_ID,
    a.CUSTOMER_NUMBER,
    a.ACTIVITY_DATE,
    a.DAY_OF_WEEK,
    a.ACTIVITY_HOUR,
    a.ACTIVITY_NAME,
    -- spread events across the hour using seq as minute offset
    DATEADD(
        MINUTE,
        (t.n - 1) % 60,
        DATEADD(
            HOUR,
            a.ACTIVITY_HOUR,
            CONVERT(DATETIME, a.ACTIVITY_DATE)
        )
    )                                                   AS ACTIVITY_TIMESTAMP,
    t.n                                                 AS SEQ
INTO #exploded_activity
FROM Data_MyVIB_Activity a
JOIN #tally t ON t.n <= a.ACTIVITY_NO
WHERE a.ACTIVITY_NO > 0;

SELECT EVENT_ID, CUSTOMER_NUMBER, ACTIVITY_NAME, ACTIVITY_TIMESTAMP FROM #exploded_activity;

GO

-- -- Data_MyVIB_Transaction → exploded_transaction ----------------------------
/*
Explodes TRANS_NO into individual transaction rows.
TRANS_AMOUNT is split evenly across the exploded rows (equal split,
since SQL has no Dirichlet distribution). The curated layer can validate
that SUM(TRANS_AMOUNT) per group ≈ original total.
*/
DROP TABLE IF EXISTS #exploded_transaction;

SELECT
    CONCAT('TX_',
        CONVERT(VARCHAR, HASHBYTES('MD5',
            CONCAT(t2.CUSTOMER_NUMBER, '_', t2.TRANS_DATE, '_', t2.TRANS_HOUR, '_', t.n)), 2)
    )                                                   AS TXN_ID,
    t2.CUSTOMER_NUMBER,
    t2.TRANS_DATE,
    t2.DAY_OF_WEEK,
    t2.TRANS_HOUR,
    t2.TRANS_LV1,
    t2.TRANS_LV2,
    ROUND(t2.TRANS_AMOUNT / t2.TRANS_NO, 2)            AS TRANS_AMOUNT,
    t2.TRANS_AMOUNT                                     AS TOTAL_TRANS_AMOUNT,
    DATEADD(
        MINUTE,
        (t.n - 1) % 60,
        DATEADD(
            HOUR,
            t2.TRANS_HOUR,
            CONVERT(DATETIME, t2.TRANS_DATE)
        )
    )                                                   AS TRANS_TIMESTAMP,
    t.n                                                 AS SEQ
INTO #exploded_transaction
FROM Data_MyVIB_Transaction t2
JOIN #tally t ON t.n <= t2.TRANS_NO
WHERE t2.TRANS_NO > 0;

SELECT TXN_ID, CUSTOMER_NUMBER, TRANS_LV1, TRANS_LV2, TRANS_AMOUNT, TRANS_TIMESTAMP FROM #exploded_transaction;

GO
