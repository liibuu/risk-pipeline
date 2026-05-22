# landing_to_raw.py
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from azure.storage.blob import BlobServiceClient
import io, os, gc

LANDING_ROOT = "landing"
RAW_ROOT     = "raw"

FILE_MAP = [
    ("customerprofile",  "Data_customer",         "customer_profile", "base_customer"),
    ("products",         "Data_deposit",           "products",         "base_deposit"),
    ("products",         "Data_card",              "products",         "base_card"),
    ("products",         "Data_lending",           "products",         "base_lending"),
    ("onlinebanking",    "Data_MyVIB_Activity",    "onlinebanking",    "base_activity"),
    ("onlinebanking",    "Data_MyVIB_Transaction", "onlinebanking",    "base_transaction"),
]

def convert(blob_service: BlobServiceClient, container: str):
    for land_folder, land_stem, raw_folder, raw_stem in FILE_MAP:
        src_prefix = f"{LANDING_ROOT}/{land_folder}/{land_stem}/"
        dst_path   = f"{RAW_ROOT}/{raw_folder}/{raw_stem}/{raw_stem}.parquet"

        blobs = [
            b.name for b in blob_service.get_container_client(container)
            .list_blobs(name_starts_with=src_prefix)
            if b.name.endswith(".csv")
        ]

        if not blobs:
            print(f"  [SKIP] no CSVs found under {src_prefix}")
            continue

        # stream chunks directly into ParquetWriter
        buf    = io.BytesIO()
        writer = None
        total  = 0

        for blob_path in blobs:
            blob      = blob_service.get_blob_client(container, blob_path)
            raw_bytes = blob.download_blob().readall()
            chunk     = pd.read_csv(io.BytesIO(raw_bytes), dtype=str, low_memory=False)
            chunk     = chunk.apply(lambda col: col.str.strip() if col.dtype == object else col)
            table     = pa.Table.from_pandas(chunk)
            total    += len(chunk)

            if writer is None:
                writer = pq.ParquetWriter(buf, table.schema)
            writer.write_table(table)

            del chunk, raw_bytes, table
            gc.collect()

        if writer:
            writer.close()

        buf.seek(0)
        out_blob = blob_service.get_blob_client(container, dst_path)
        out_blob.upload_blob(buf, overwrite=True)
        print(f"  {src_prefix}  →  {dst_path}  ({total:,} rows)")

        del buf
        gc.collect()

if __name__ == "__main__":
    client = BlobServiceClient.from_connection_string(os.environ["AZURE_STORAGE_CONNECTION_STRING"])
    convert(client, "risk-data")