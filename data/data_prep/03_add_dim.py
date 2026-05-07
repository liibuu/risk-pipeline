"""
03_add_dim.py

Usage:
    py 03_add_dim.py

Adds dimensional columns to dirtied datasets:
  - Data_MyVIB_Transaction: currency, FIN_INST_ID/FIN_INST_NAME
  - Data_lending:           LOAN_TYPE, BRANCH_CODE/BRANCH_NAME
  - Data_card:              CARD_SUBTYPE, BRANCH_CODE/BRANCH_NAME
"""

import pandas as pd
import numpy as np

# -- Paths ----------------------------------------------------
INPUT_DIR  = "dirtied"   # folder containing dirtied CSVs
OUTPUT_DIR = "landing"   # write back to same folder (overwrites), or change
LIST_DIR   = "input"    # folder containing list_bank.csv, list_branch.csv

TXN_FILE     = "Data_MyVIB_Transaction.csv"
LENDING_FILE = "Data_lending.csv"
CARD_FILE    = "Data_card.csv"
BANK_FILE    = "list_bank.csv"
BRANCH_FILE  = "list_branch.csv"

RANDOM_SEED = 42

# -- FX rates (VND per 1 unit of foreign currency) ---------------
FX_RATES = {
    "USD": 25_450,
    "EUR": 27_600,
    "GBP": 32_100,
}
# Distribution of foreign currencies among the 15% FX transactions
FX_CURRENCY_WEIGHTS = {
    "USD": 0.65,
    "EUR": 0.25,
    "GBP": 0.10,
}

rng = np.random.default_rng(RANDOM_SEED)


# -- Helpers -----------------------------------------------------------------

def load_csv(directory, filename, **kwargs):
    path = f"{directory}\\{filename}"
    df = pd.read_csv(path, **kwargs)
    print(f"  Loaded {filename}: {len(df):,} rows")
    return df


def save_csv(df, directory, filename):
    path = f"{directory}\\{filename}"
    df.to_csv(path, index=False)
    print(f"  Saved  {filename}: {len(df):,} rows → {path}")


def weighted_sample(values, weights, size, rng):
    """Draw `size` samples from `values` with `weights` (lists or arrays)."""
    weights = np.array(weights, dtype=float)
    weights /= weights.sum()
    return rng.choice(values, size=size, p=weights)


# -- 1. Data_MyVIB_Transaction ------------------------------------------------

def process_transaction(txn_df, bank_df):
    n = len(txn_df)

    # 1a. Currency column - default VND
    txn_df["currency"] = "VND"

    # Mark 15% of rows as foreign-currency
    fx_mask = rng.random(n) < 0.15
    fx_currencies = weighted_sample(
        list(FX_CURRENCY_WEIGHTS.keys()),
        list(FX_CURRENCY_WEIGHTS.values()),
        size=fx_mask.sum(),
        rng=rng,
    )
    txn_df.loc[fx_mask, "currency"] = fx_currencies

    # Convert AMOUNT: original VND amount ÷ FX rate → foreign-currency amount
    # (assumes AMOUNT column holds VND values pre-dirty)
    for ccy, rate in FX_RATES.items():
        ccy_mask = txn_df["currency"] == ccy
        txn_df.loc[ccy_mask, "TRANS_AMOUNT"] = (
            txn_df.loc[ccy_mask, "TRANS_AMOUNT"] / rate
        ).round(2)

    # 1b. FIN_INST_ID / FIN_INST_NAME for Outside_VIB transactions
    outside_mask = txn_df["TRANS_LV2"] == "Outside_VIB"
    n_outside = outside_mask.sum()

    bank_ids   = bank_df["FIN_INST_ID"].tolist()
    bank_names = bank_df["FIN_INST_NAME"].tolist()
    bank_probs = bank_df["probability"].tolist()

    sampled_idx = weighted_sample(
        range(len(bank_df)), bank_probs, size=n_outside, rng=rng
    )

    txn_df.loc[outside_mask, "FIN_INST_ID"]   = [bank_ids[i]   for i in sampled_idx]
    txn_df.loc[outside_mask, "FIN_INST_NAME"] = [bank_names[i] for i in sampled_idx]

    # Non-Outside_VIB rows get null
    txn_df["FIN_INST_ID"]   = txn_df.get("FIN_INST_ID",   pd.Series(dtype="object"))
    txn_df["FIN_INST_NAME"] = txn_df.get("FIN_INST_NAME", pd.Series(dtype="object"))

    print(f"  FX rows: {fx_mask.sum():,} ({fx_mask.mean()*100:.1f}%)")
    print(f"  Outside_VIB rows: {n_outside:,}")
    return txn_df


# -- 2. Data_lending ----------------------------------------------------------

LOAN_TYPES   = ["PERSONAL", "MORTGAGE", "AUTO", "BUSINESS"]
LOAN_WEIGHTS = [0.15,       0.55,       0.10,   0.20      ]
ONLINE_BRANCH = {"BRANCH_CODE": "ONLINE", "BRANCH_NAME": "Online channel"}
LENDING_ONLINE_PROB = 0.04


def add_branch(df, branch_df, online_prob, rng):
    n = len(df)
    online_mask = rng.random(n) < online_prob

    branch_codes = branch_df["BRANCH_CODE"].tolist()
    branch_names = branch_df["BRANCH_NAME"].tolist()
    branch_probs = branch_df["probability"].tolist()

    n_non_online = (~online_mask).sum()
    sampled_idx  = weighted_sample(
        range(len(branch_df)), branch_probs, size=n_non_online, rng=rng
    )

    df["BRANCH_CODE"] = ""
    df["BRANCH_NAME"] = ""

    df.loc[online_mask,  "BRANCH_CODE"] = ONLINE_BRANCH["BRANCH_CODE"]
    df.loc[online_mask,  "BRANCH_NAME"] = ONLINE_BRANCH["BRANCH_NAME"]
    df["BRANCH_CODE"] = df["BRANCH_CODE"].astype(object)
    df["BRANCH_NAME"] = df["BRANCH_NAME"].astype(object)
    df.loc[~online_mask, "BRANCH_CODE"] = [branch_codes[i] for i in sampled_idx]
    df.loc[~online_mask, "BRANCH_NAME"] = [branch_names[i] for i in sampled_idx]

    print(f"  Online channel rows: {online_mask.sum():,} ({online_mask.mean()*100:.1f}%)")
    return df


def process_lending(lending_df, branch_df):
    n = len(lending_df)

    # LOAN_TYPE
    lending_df["LOAN_TYPE"] = weighted_sample(
        LOAN_TYPES, LOAN_WEIGHTS, size=n, rng=rng
    )

    # BRANCH_CODE / BRANCH_NAME
    lending_df = add_branch(lending_df, branch_df, LENDING_ONLINE_PROB, rng)

    return lending_df


# -- 3. Data_card -------------------------------------------------------------

CARD_SUBTYPES   = ["Platinum", "Diamond World Lady", "StepUp"]
CARD_WEIGHTS = [0.07,       0.25,                  0.68    ]
CARD_ONLINE_PROB = 0.82


def process_card(card_df, branch_df):
    credit_mask = card_df["CARD_TYPE"] == "CREDIT"
    credit_df = card_df[credit_mask].copy()
    non_credit_df = card_df[~credit_mask].copy()

    n = len(credit_df)

    credit_df["CARD_SUBTYPE"] = weighted_sample(
        CARD_SUBTYPES, CARD_WEIGHTS, size=n, rng=rng
    )
    credit_df = add_branch(credit_df, branch_df, CARD_ONLINE_PROB, rng)

    # Non-credit rows get nulls for the new columns
    non_credit_df["CARD_SUBTYPE"] = None
    non_credit_df["BRANCH_CODE"]  = None
    non_credit_df["BRANCH_NAME"]  = None

    return pd.concat([credit_df, non_credit_df]).sort_index()


# -- Main ---------------------------------------------------------------------

def main():
    print("Loading reference data...")
    bank_df   = load_csv(LIST_DIR, BANK_FILE)
    branch_df = load_csv(LIST_DIR, BRANCH_FILE)

    # Validate required columns
    assert {"FIN_INST_ID", "FIN_INST_NAME", "probability"}.issubset(bank_df.columns), \
        "list_bank.csv must have: FIN_INST_ID, FIN_INST_NAME, probability"
    assert {"BRANCH_CODE", "BRANCH_NAME", "probability"}.issubset(branch_df.columns), \
        "list_branch.csv must have: BRANCH_CODE, BRANCH_NAME, probability"

    print("\nProcessing Data_MyVIB_Transaction...")
    txn_df = load_csv(INPUT_DIR, TXN_FILE)
    txn_df = process_transaction(txn_df, bank_df)
    save_csv(txn_df, OUTPUT_DIR, TXN_FILE)

    print("\nProcessing Data_lending...")
    lending_df = load_csv(INPUT_DIR, LENDING_FILE)
    lending_df = process_lending(lending_df, branch_df)
    save_csv(lending_df, OUTPUT_DIR, LENDING_FILE)

    print("\nProcessing Data_card...")
    card_df = load_csv(INPUT_DIR, CARD_FILE)
    card_df = process_card(card_df, branch_df)
    save_csv(card_df, OUTPUT_DIR, CARD_FILE)

    print("\nDone.")


if __name__ == "__main__":
    main()