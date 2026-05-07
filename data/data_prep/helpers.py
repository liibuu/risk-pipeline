# IMPORTANT: pip install pyarrow
import pandas as pd
from pathlib import Path

input_dir  = Path("./landing")
output_dir = Path("./raw")
output_dir.mkdir(exist_ok=True)

# csv_to_parquet.py
# for csv_file in input_dir.glob("*.csv"):
#     suffix = csv_file.stem.split("_")[-1].lower()
#     out = output_dir / f"base_{suffix}.parquet"
#     df = pd.read_csv(csv_file, low_memory=False)
#     df.to_parquet(out, index=False, engine="pyarrow")
#     print(f"  {csv_file.name}  →  {out.name}  ({len(df):,} rows)")

# quick check columns
# for f in sorted(Path("./raw").glob("*.parquet")):
#     df = pd.read_parquet(f, engine="pyarrow")
#     print(f"\n{'='*50}")
#     print(f.name)
#     print('='*50)
#     df.info()    

# check timestamp formats in activity and transaction
# act = pd.read_parquet("./raw/base_activity.parquet")
# txn = pd.read_parquet("./raw/base_transaction.parquet")
# cust = pd.read_parquet("./raw/base_customer.parquet")

# print("=== ACTIVITY_TIMESTAMP samples ===")
# print(act["ACTIVITY_TIMESTAMP"].dropna().head(10).tolist())

# print("\n=== TRANS_TIMESTAMP samples ===")
# print(txn["TRANS_TIMESTAMP"].dropna().head(10).tolist())

# print("\n=== DATE_OF_BIRTH samples (all unique formats) ===")
# print(cust["DATE_OF_BIRTH"].dropna().head(20).tolist())

# print("\n=== CLIENT_SEX unique values ===")
# print(cust["CLIENT_SEX"].value_counts().to_dict())

# print("\n=== ACCOUNT_TYPE unique values ===")
# dep = pd.read_parquet("./raw/base_deposit.parquet")
# print(dep["ACCOUNT_TYPE"].value_counts().to_dict())

# print("\n=== CARD STATUS unique values ===")
# card = pd.read_parquet("./raw/base_card.parquet")
# print(card["STATUS"].value_counts().to_dict())

# print("\n=== LOAN_TYPE unique values ===")
# loan = pd.read_parquet("./raw/base_lending.parquet")
# print(loan["LOAN_TYPE"].value_counts().to_dict())

# print("\n=== LOAN_AMOUNT negatives/nulls ===")
# print("nulls:", loan["LOAN_AMOUNT"].isna().sum())
# print("negatives:", (loan["LOAN_AMOUNT"] < 0).sum())

# print("\n=== TRANS_AMOUNT negatives/zeros ===")
# print("<=0:", (txn["TRANS_AMOUNT"] <= 0).sum())

# print("\n=== DISBURSEMENT_DATE future samples ===")
# import datetime
# loan["DISBURSEMENT_DATE_parsed"] = pd.to_datetime(loan["DISBURSEMENT_DATE"], errors="coerce")
# future = loan[loan["DISBURSEMENT_DATE_parsed"] > datetime.datetime.now()]
# print("future dates count:", len(future))
# print("samples:", future["DISBURSEMENT_DATE"].head(5).tolist())