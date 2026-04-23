"""
01_explode.py
-------------
One-time script: takes the aggregated source CSVs and explodes them into
row-level records that simulate the raw transactional data a bank would
actually have upstream.

This is NOT part of the pipeline. It exists only because this is a portfolio
project and we don't have access to real raw data. In production, the landing
layer would receive row-level data directly from upstream systems.

Usage:
    python 01_explode.py --input_dir ./source --output_dir ./exploded

Input files expected (CSV):
    Data_customer.csv
    Data_deposit.csv
    Data_card.csv
    Data_lending.csv
    Data_MyVIB_Activity.csv
    Data_MyVIB_Transaction.csv
"""

import argparse
import os
import hashlib
from datetime import datetime, timedelta

import numpy as np
import pandas as pd

# -- reproducibility ----------------------------------------------------------
RNG = np.random.default_rng(seed=42)


# -- helpers -------------------------------------------------------------------

def make_id(prefix: str, customer_number, month, seq: int) -> str:
    """Generate a deterministic surrogate ID."""
    raw = f"{prefix}_{customer_number}_{month}_{seq}"
    return prefix + "_" + hashlib.md5(raw.encode()).hexdigest()[:12].upper()


def random_date_within_month(month_str: str, n: int) -> list[str]:
    """
    Given a YYYY-MM-DD date string, return n random dates within that same
    calendar month as strings.
    """
    d = pd.to_datetime(month_str)
    year, month = d.year, d.month
    start = datetime(year, month, 1)
    # last day of month
    if month == 12:
        end = datetime(year + 1, 1, 1) - timedelta(days=1)
    else:
        end = datetime(year, month + 1, 1) - timedelta(days=1)
    delta_days = (end - start).days
    offsets = RNG.integers(0, delta_days + 1, size=n)
    return [(start + timedelta(days=int(d))).strftime("%Y-%m-%d") for d in offsets]


def noisy_values(mean, n: int, noise_pct: float = 0.15) -> np.ndarray:
    """
    Generate n values distributed around mean with ±noise_pct Gaussian noise.
    Ensures all values are positive.
    """
    if mean == 0 or pd.isna(mean):
        return np.zeros(n)
    std = abs(mean) * noise_pct
    vals = RNG.normal(loc=mean, scale=std, size=n)
    return np.maximum(vals, 1.0)  # no negative amounts


# -- table-specific explode functions -----------------------------------------

def explode_customer(df: pd.DataFrame) -> pd.DataFrame:
    """
    Data_customer is already row-level (one row per customer).
    Return as-is — dirtiness is injected in step 2.
    """
    print(f"  customer: {len(df):,} rows → {len(df):,} rows (no explosion needed)")
    return df.copy()


def explode_deposit(df: pd.DataFrame) -> pd.DataFrame:
    """
    Each row has COUNT_CA_ACCT, AVG_CA_BALANCE, COUNT_TD_ACCT, AVG_TD_BALANCE.
    Explode into one row per individual account.
    MONTH column is a YYYY-MM-DD date string representing the snapshot month.
 
    Output columns:
        ACCOUNT_ID, CUSTOMER_NUMBER, MONTH, ACCOUNT_TYPE,
        BALANCE, AVG_BALANCE, OPEN_DATE
 
    AVG_BALANCE carries the original monthly average from the source row so
    the curated layer can later reconcile individual balances against it.
    """
    records = []
 
    for _, row in df.iterrows():
        cust = row["CUSTOMER_NUMBER"]
        month = str(row["MONTH"])  # YYYY-MM-DD
 
        # Current accounts
        ca_count = int(row.get("COUNT_CA_ACCT", 0) or 0)
        ca_avg = float(row.get("AVG_CA_BALANCE", 0) or 0)
        balances_ca = noisy_values(ca_avg, ca_count)
        dates_ca = random_date_within_month(month, ca_count)
        for i in range(ca_count):
            records.append({
                "ACCOUNT_ID": make_id("CA", cust, month, i),
                "CUSTOMER_NUMBER": cust,
                "MONTH": month,
                "ACCOUNT_TYPE": "CURRENT",
                "BALANCE": round(float(balances_ca[i]), 2),
                "AVG_BALANCE": round(ca_avg, 2),
                "OPEN_DATE": dates_ca[i],
            })
 
        # Term deposit accounts
        td_count = int(row.get("COUNT_TD_ACCT", 0) or 0)
        td_avg = float(row.get("AVG_TD_BALANCE", 0) or 0)
        balances_td = noisy_values(td_avg, td_count)
        dates_td = random_date_within_month(month, td_count)
        for i in range(td_count):
            records.append({
                "ACCOUNT_ID": make_id("TD", cust, month, i),
                "CUSTOMER_NUMBER": cust,
                "MONTH": month,
                "ACCOUNT_TYPE": "TERM_DEPOSIT",
                "BALANCE": round(float(balances_td[i]), 2),
                "AVG_BALANCE": round(td_avg, 2),
                "OPEN_DATE": dates_td[i],
            })
 
    result = pd.DataFrame(records)
    print(f"  deposit: {len(df):,} summary rows → {len(result):,} account rows")
    return result


def explode_card(df: pd.DataFrame) -> pd.DataFrame:
    """
    Each row has COUNT_CREDITCARD and COUNT_DEBITCARD.
    Explode into one row per individual card.

    Output columns:
        CARD_ID, CUSTOMER_NUMBER, MONTH, CARD_TYPE,
        ISSUE_DATE, STATUS
    """
    statuses = ["ACTIVE"] * 95 + ["BLOCKED"] * 3 + ["EXPIRED"] * 2  # realistic dist
    records = []

    for _, row in df.iterrows():
        cust = row["CUSTOMER_NUMBER"]
        month = row["MONTH"]

        for card_type, col in [("CREDIT", "COUNT_CREDITCARD"), ("DEBIT", "COUNT_DEBITCARD")]:
            count = int(row.get(col, 0) or 0)
            dates = random_date_within_month(month, count)
            for i in range(count):
                records.append({
                    "CARD_ID": make_id(card_type[:2], cust, month, i),
                    "CUSTOMER_NUMBER": cust,
                    "MONTH": month,
                    "CARD_TYPE": card_type,
                    "ISSUE_DATE": dates[i],
                    "STATUS": RNG.choice(statuses),
                })

    result = pd.DataFrame(records)
    print(f"  card: {len(df):,} summary rows → {len(result):,} card rows")
    return result


def explode_lending(df: pd.DataFrame) -> pd.DataFrame:
    """
    Each row has COUNT_OF_LOAN and AVG_LOAN_AMOUNT.
    Explode into one row per individual loan.

    Output columns:
        LOAN_ID, CUSTOMER_NUMBER, MONTH, LOAN_TYPE,
        LOAN_AMOUNT, DISBURSEMENT_DATE
    """
    loan_types = ["PERSONAL"] * 45 + ["MORTGAGE"] * 30 + ["AUTO"] * 15 + ["BUSINESS"] * 10
    records = []

    for _, row in df.iterrows():
        cust = row["CUSTOMER_NUMBER"]
        month = row["MONTH"]
        count = int(row.get("COUNT_OF_LOAN", 0) or 0)
        avg_amt = float(row.get("AVG_LOAN_AMOUNT", 0) or 0)

        amounts = noisy_values(avg_amt, count)
        dates = random_date_within_month(month, count)

        for i in range(count):
            records.append({
                "LOAN_ID": make_id("LN", cust, month, i),
                "CUSTOMER_NUMBER": cust,
                "MONTH": month,
                "LOAN_TYPE": RNG.choice(loan_types),
                "LOAN_AMOUNT": round(float(amounts[i]), 2),
                "DISBURSEMENT_DATE": dates[i],
            })

    result = pd.DataFrame(records)
    print(f"  lending: {len(df):,} summary rows → {len(result):,} loan rows")
    return result


def explode_activity(df: pd.DataFrame) -> pd.DataFrame:
    """
    Each row has ACTIVITY_NO (count of events in that group).
    Explode into one row per individual activity event.

    Output columns:
        EVENT_ID, CUSTOMER_NUMBER, ACTIVITY_DATE, DAY_OF_WEEK,
        ACTIVITY_HOUR, ACTIVITY_NAME, ACTIVITY_TIMESTAMP
    """
    records = []

    for _, row in df.iterrows():
        cust = row["CUSTOMER_NUMBER"]
        act_date = row["ACTIVITY_DATE"]
        dow = row["DAY_OF_WEEK"]
        hour = row["ACTIVITY_HOUR"]
        act_name = row["ACTIVITY_NAME"]
        count = int(row.get("ACTIVITY_NO", 1) or 1)

        for i in range(count):
            minute = RNG.integers(0, 60)
            second = RNG.integers(0, 60)
            records.append({
                "EVENT_ID": make_id("EV", cust, str(act_date), i),
                "CUSTOMER_NUMBER": cust,
                "ACTIVITY_DATE": act_date,
                "DAY_OF_WEEK": dow,
                "ACTIVITY_HOUR": hour,
                "ACTIVITY_NAME": act_name,
                "ACTIVITY_TIMESTAMP": f"{act_date} {int(hour):02d}:{int(minute):02d}:{int(second):02d}",
            })

    result = pd.DataFrame(records)
    print(f"  activity: {len(df):,} group rows → {len(result):,} event rows")
    return result


def explode_transaction(df: pd.DataFrame) -> pd.DataFrame:
    """
    Each row has TRANS_NO (count) and TRANS_AMOUNT (total).
    Explode into one row per individual transaction by splitting TRANS_AMOUNT.

    Output columns:
        TXN_ID, CUSTOMER_NUMBER, TRANS_DATE, DAY_OF_WEEK,
        TRANS_HOUR, TRANS_LV1, TRANS_LV2,
        TRANS_AMOUNT, TRANS_TIMESTAMP
    """
    records = []

    for _, row in df.iterrows():
        cust = row["CUSTOMER_NUMBER"]
        trans_date = row["TRANS_DATE"]
        dow = row["DAY_OF_WEEK"]
        hour = row["TRANS_HOUR"]
        lv1 = row["TRANS_LV1"]
        lv2 = row["TRANS_LV2"]
        count = int(row.get("TRANS_NO", 1) or 1)
        total_amount = float(row.get("TRANS_AMOUNT", 0) or 0)

        # Distribute total amount across transactions using Dirichlet split
        if count == 1:
            amounts = [total_amount]
        else:
            splits = RNG.dirichlet(np.ones(count))
            amounts = [round(float(total_amount * s), 2) for s in splits]

        for i in range(count):
            minute = RNG.integers(0, 60)
            second = RNG.integers(0, 60)
            records.append({
                "TXN_ID": make_id("TX", cust, str(trans_date), i),
                "CUSTOMER_NUMBER": cust,
                "TRANS_DATE": trans_date,
                "DAY_OF_WEEK": dow,
                "TRANS_HOUR": hour,
                "TRANS_LV1": lv1,
                "TRANS_LV2": lv2,
                "TRANS_AMOUNT": amounts[i],
                "TRANS_TIMESTAMP": f"{trans_date} {int(hour):02d}:{int(minute):02d}:{int(second):02d}",
            })

    result = pd.DataFrame(records)
    print(f"  transaction: {len(df):,} group rows → {len(result):,} txn rows")
    return result


# -- main ----------------------------------------------------------------------

TABLE_MAP = {
    "Data_customer": explode_customer,
    "Data_deposit": explode_deposit,
    "Data_card": explode_card,
    "Data_lending": explode_lending,
    "Data_MyVIB_Activity": explode_activity,
    "Data_MyVIB_Transaction": explode_transaction,
}


def main(input_dir: str, output_dir: str):
    os.makedirs(output_dir, exist_ok=True)

    for table_name, explode_fn in TABLE_MAP.items():
        input_path = os.path.join(input_dir, f"{table_name}.csv")
        output_path = os.path.join(output_dir, f"{table_name}.csv")

        if not os.path.exists(input_path):
            print(f"  [SKIP] {table_name}.csv not found at {input_path}")
            continue

        print(f"\nProcessing {table_name}...")
        df = pd.read_csv(input_path)
        exploded = explode_fn(df)
        exploded.to_csv(output_path, index=False)
        print(f"  → saved to {output_path}")

    print("\n✓ Explosion complete. Run 02_inject_dirty.py next.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Explode aggregated banking CSVs to row-level records.")
    parser.add_argument("--input_dir", default="./source", help="Directory containing source CSVs")
    parser.add_argument("--output_dir", default="./exploded", help="Directory to write exploded CSVs")
    args = parser.parse_args()
    main(args.input_dir, args.output_dir)
