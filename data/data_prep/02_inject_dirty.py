"""
02_inject_dirty.py
------------------
One-time script: takes the clean exploded CSVs from 01_explode.py and
injects realistic dirty data patterns that simulate what a bank's raw
upstream data actually looks like.

Usage:
    py 02_inject_dirty.py --input_dir ./exploded --output_dir ./dirtied

Dirty patterns injected per table:
    customer    — duplicates, mixed sex formats, inconsistent DOB formats,
                  nulls on IB_REGISTER_DATE, add LEGAL_ID (~0.7% null)
    deposit     — impossible zero balance when count > 0, negative balances
    card        — inject BLOCKED (~0.5%)/EXPIRED (~2%) status orphan cards 
                  (no matching customer), mixed STATUS casing
    lending     — null LOAN_AMOUNT (~1%), future (~0.5%), DISBURSEMENT_DATE, 
                  negative LOAN_AMOUNT (~0.5%)
    activity    — null ACTIVITY_NAME (~2%), late-arriving records (date 
                  shifted back)
    transaction — non-positive TRANS_AMOUNT (~3%), mismatched TRANS_LV1/LV2
                  (~1%), null TRANS_TIMESTAMP (~0.5%)
"""

import argparse
import os
from datetime import datetime, timedelta

import numpy as np
import pandas as pd

RNG = np.random.default_rng(seed=99)


# -- helpers -------------------------------------------------------------------

def random_mask(n: int, pct: float) -> np.ndarray:
    """Return a boolean mask of length n with approximately pct fraction True."""
    return RNG.random(n) < pct


def future_date(n: int) -> list[str]:
    """Return n dates that are clearly in the future (simulate bad data)."""
    base = datetime.now() + timedelta(days=365)
    return [(base + timedelta(days=int(d))).strftime("%Y-%m-%d")
            for d in RNG.integers(1, 365, size=n)]


# -- table-specific dirty functions -------------------------------------------

def dirty_customer(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    n = len(df)

    # 1. Inject ~2% duplicate rows (re-add sampled rows)
    dup_idx = RNG.choice(n, size=int(n * 0.02), replace=False)
    duplicates = df.iloc[dup_idx].copy()
    df = pd.concat([df, duplicates], ignore_index=True)
    print(f"    + {len(dup_idx):,} duplicate customer rows injected")

    # 2. Mixed CLIENT_SEX formats
    n2 = len(df)
    sex_formats = {
        "M": ["M", "Male", "male", "1"],
        "F": ["F", "Female", "female", "2"],
    }
    sex_mask = random_mask(n2, 0.30)  # 30% get an alternate format
    for i in np.where(sex_mask)[0]:
        original = str(df.at[i, "CLIENT_SEX"])
        if original in sex_formats:
            df.at[i, "CLIENT_SEX"] = RNG.choice(sex_formats[original])

    # 3. Inconsistent DATE_OF_BIRTH formats
    dob_mask = random_mask(n2, 0.20)
    for i in np.where(dob_mask)[0]:
        val = df.at[i, "DATE_OF_BIRTH"]
        if pd.notna(val):
            try:
                d = pd.to_datetime(val)
                # Randomly pick an alternate format
                fmt = RNG.choice(["%d/%m/%Y", "%m-%d-%Y", "%d-%m-%Y", "%Y%m%d"])
                df.at[i, "DATE_OF_BIRTH"] = d.strftime(fmt)
            except Exception:
                pass

    # 4. ~1% null IB_REGISTER_DATE
    null_mask = random_mask(n2, 0.01)
    df.loc[null_mask, "IB_REGISTER_DATE"] = np.nan
    print(f"    + mixed sex formats, inconsistent DOB formats, {null_mask.sum()} null IB_REGISTER_DATE")

    # 5. Add LEGAL_ID (12-digit numeric string with leading zeros), ~0.7% null
    df["LEGAL_ID"] = pd.Series(
        RNG.integers(0, 999999999999, size=len(df))
    ).apply(lambda x: str(x).zfill(12))
    null_mask = random_mask(len(df), 0.007)
    df.loc[null_mask, "LEGAL_ID"] = np.nan
    print(f"    + {null_mask.sum()} null LEGAL_ID")

    return df


def dirty_deposit(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    n = len(df)

    # 1. ~1.5% zero balance despite ACCOUNT_TYPE suggesting active account
    zero_mask = random_mask(n, 0.015)
    df.loc[zero_mask, "BALANCE"] = 0.0
    print(f"    + {zero_mask.sum()} zero-balance records injected")

    # 2. ~0.5% negative balance (sign error from upstream)
    neg_mask = random_mask(n, 0.005)
    df.loc[neg_mask, "BALANCE"] = df.loc[neg_mask, "BALANCE"] * -1
    print(f"    + {neg_mask.sum()} negative-balance records injected")

    return df


def dirty_card(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    n = len(df)

    # 1. Inject BLOCKED (~0.5%) and EXPIRED (~2%) into the uniformly ACTIVE column
    blocked_mask = random_mask(n, 0.005)
    expired_mask = random_mask(n, 0.02) & ~blocked_mask  # avoid overlap
    df.loc[blocked_mask, "STATUS"] = "BLOCKED"
    df.loc[expired_mask, "STATUS"] = "EXPIRED"
    print(f"    + {blocked_mask.sum()} BLOCKED, {expired_mask.sum()} EXPIRED status injected") 

    # 2. Mixed STATUS casing
    status_variants = {
        "ACTIVE": ["Active", "active", "ACTIVE"],
        "BLOCKED": ["Blocked", "blocked", "BLOCKED"],
        "EXPIRED": ["Expired", "expired", "EXPIRED"],
    }
    case_mask = random_mask(n, 0.25)
    for i in np.where(case_mask)[0]:
        s = str(df.at[i, "STATUS"])
        if s in status_variants:
            df.at[i, "STATUS"] = RNG.choice(status_variants[s])

    # 3. ~0.5% orphan cards — set CUSTOMER_NUMBER to a non-existent value
    orphan_mask = random_mask(n, 0.005)
    df["CUSTOMER_NUMBER"] = df["CUSTOMER_NUMBER"].astype(object)
    df.loc[orphan_mask, "CUSTOMER_NUMBER"] = "CUST_ORPHAN_" + \
        pd.Series(RNG.integers(90000, 99999, orphan_mask.sum()).astype(str)).values
    print(f"    + mixed STATUS casing, {orphan_mask.sum()} orphan card records")

    return df


def dirty_lending(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    n = len(df)

    # 1. ~1% null LOAN_AMOUNT
    null_mask = random_mask(n, 0.01)
    df.loc[null_mask, "LOAN_AMOUNT"] = np.nan
    print(f"    + {null_mask.sum()} null LOAN_AMOUNT")

    # 2. ~0.5% future DISBURSEMENT_DATE (impossible)
    future_mask = random_mask(n, 0.005)
    future_dates = future_date(future_mask.sum())
    df.loc[future_mask, "DISBURSEMENT_DATE"] = future_dates
    print(f"    + {future_mask.sum()} future DISBURSEMENT_DATE records")

    # 3. ~0.5% negative LOAN_AMOUNT (sign error)
    neg_mask = random_mask(n, 0.005)
    df.loc[neg_mask & df["LOAN_AMOUNT"].notna(), "LOAN_AMOUNT"] = \
        df.loc[neg_mask & df["LOAN_AMOUNT"].notna(), "LOAN_AMOUNT"] * -1
    print(f"    + {neg_mask.sum()} negative LOAN_AMOUNT records")

    return df


def dirty_activity(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    n = len(df)

    # 1. ~2% null ACTIVITY_NAME
    null_mask = random_mask(n, 0.02)
    df.loc[null_mask, "ACTIVITY_NAME"] = np.nan
    print(f"    + {null_mask.sum()} null ACTIVITY_NAME")

    # 2. ~1% late-arriving events (ACTIVITY_TIMESTAMP shifted backward,
    #    simulating Kafka out-of-order delivery)
    late_mask = random_mask(n, 0.01)
    for i in np.where(late_mask)[0]:
        try:
            ts = pd.to_datetime(df.at[i, "ACTIVITY_TIMESTAMP"])
            df.at[i, "ACTIVITY_TIMESTAMP"] = (
                ts - timedelta(days=int(RNG.integers(1, 5)))
            ).strftime("%Y-%m-%d %H:%M:%S")
        except Exception:
            pass
    print(f"    + {late_mask.sum()} late-arriving activity records")

    return df


def dirty_transaction(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    n = len(df)

    # 1. ~3% non-positive TRANS_AMOUNT
    nonpos_mask = random_mask(n, 0.03)
    df.loc[nonpos_mask, "TRANS_AMOUNT"] = RNG.choice(
        [0, -1, -100, -999], size=nonpos_mask.sum()
    ).astype(float)
    print(f"    + {nonpos_mask.sum()} non-positive TRANS_AMOUNT records")

    # 2. ~1% mismatched TRANS_LV1 / TRANS_LV2 (business inconsistency)
    # e.g. LV1=Transfer but LV2=Loan Repayment — doesn't belong together
    mismatch_mask = random_mask(n, 0.01)
    wrong_lv2 = ["Loan Repayment", "Salary", "Dividend", "Unknown"]
    for i in np.where(mismatch_mask)[0]:
        df.at[i, "TRANS_LV2"] = RNG.choice(wrong_lv2)
    print(f"    + {mismatch_mask.sum()} mismatched TRANS_LV1/LV2 records")

    # 3. ~0.5% null TRANS_TIMESTAMP
    null_mask = random_mask(n, 0.005)
    df.loc[null_mask, "TRANS_TIMESTAMP"] = np.nan
    print(f"    + {null_mask.sum()} null TRANS_TIMESTAMP records")

    return df


# -- main ----------------------------------------------------------------------

TABLE_MAP = {
    "Data_customer": dirty_customer,
    "Data_deposit": dirty_deposit,
    "Data_card": dirty_card,
    "Data_lending": dirty_lending,
    "Data_MyVIB_Activity": dirty_activity,
    "Data_MyVIB_Transaction": dirty_transaction,
}


def main(input_dir: str, output_dir: str):
    os.makedirs(output_dir, exist_ok=True)

    for table_name, dirty_fn in TABLE_MAP.items():
        input_path = os.path.join(input_dir, f"{table_name}.csv")
        output_path = os.path.join(output_dir, f"{table_name}.csv")

        if not os.path.exists(input_path):
            print(f"  [SKIP] {table_name}.csv not found at {input_path}")
            continue

        print(f"\nDirtying {table_name}...")
        df = pd.read_csv(input_path)
        dirtied = dirty_fn(df)
        dirtied.to_csv(output_path, index=False)
        print(f"  → {len(dirtied):,} rows saved to {output_path}")

    print("\n✓ Dirty injection complete.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Inject dirty data patterns into exploded banking CSVs.")
    parser.add_argument("--input_dir", default="./exploded", help="Directory with exploded CSVs (output of 01_explode.py)")
    parser.add_argument("--output_dir", default="./dirtied", help="Directory with dirtied CSVs")
    args = parser.parse_args()
    main(args.input_dir, args.output_dir)
