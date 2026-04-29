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
for f in sorted(Path("./raw").glob("*.parquet")):
    df = pd.read_parquet(f, engine="pyarrow")
    print(f"\n{'='*50}")
    print(f.name)
    print('='*50)
    df.info()    