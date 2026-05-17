# landing_to_raw.py
import pandas as pd
from pathlib import Path
from azure.storage.blob import BlobServiceClient
import io, os
from dotenv import load_dotenv
load_dotenv()  # loads .env from current directory

LANDING_ROOT = "landing"
RAW_ROOT     = "raw"

FILE_MAP = [
    # (landing subfolder, landing filename stem, raw subfolder, raw filename)
    ("customerprofile", "Data_customer",            "customerprofile",  "base_customer"),
    ("products",         "Data_deposit",            "products",         "base_deposit"),
    ("products",         "Data_card",               "products",         "base_card"),
    ("products",         "Data_lending",            "products",         "base_lending"),
    ("onlinebanking",    "Data_MyVIB_Activity",     "onlinebanking",    "base_activity"),
    ("onlinebanking",    "Data_MyVIB_Transaction",  "onlinebanking",    "base_transaction"),
]

def convert(blob_service: BlobServiceClient, container: str):
    for land_folder, land_stem, raw_folder, raw_stem in FILE_MAP:
        src_prefix = f"{LANDING_ROOT}/{land_folder}/{land_stem}/"

        # collect all CSV chunks under this prefix
        blobs = [
            b.name for b in blob_service.get_container_client(container)
            .list_blobs(name_starts_with=src_prefix)
            if b.name.endswith(".csv")
        ]

        if not blobs:
            print(f"  [SKIP] no CSVs found under {src_prefix}")
            continue

        # read and concatenate all chunks
        dfs = []
        for blob_path in blobs:
            blob = blob_service.get_blob_client(container, blob_path)
            raw_bytes = blob.download_blob().readall()
            dfs.append(pd.read_csv(io.BytesIO(raw_bytes), dtype=str, low_memory=False))

        df = pd.concat(dfs, ignore_index=True)
        df = df.apply(lambda col: col.str.strip() if col.dtype == object else col)

        # upload as single parquet
        dst_path = f"{RAW_ROOT}/{raw_folder}/{raw_stem}.parquet"
        buf = io.BytesIO()
        df.to_parquet(buf, index=False, engine="pyarrow")
        buf.seek(0)

        out_blob = blob_service.get_blob_client(container, dst_path)
        out_blob.upload_blob(buf, overwrite=True)
        print(f"  {src_prefix}  →  {dst_path}  ({len(df):,} rows)")

if __name__ == "__main__":
    client = BlobServiceClient.from_connection_string(os.environ["AZURE_STORAGE_CONNECTION_STRING"])
    convert(client, "risk-data")