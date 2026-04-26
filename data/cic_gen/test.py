import os
import csv
import random
import numpy as np
from scipy.stats import skewnorm, poisson
from datetime import datetime, timedelta
from xml.etree.ElementTree import Element, SubElement, ElementTree, indent

# --------------------------------------------- Directory --------------------------------------------- #
LIST_LEGAL_ID_PATH = "input/list_legal_id.csv"
LIST_BANK_PATH = "input/list_bank.csv"

OUTPUT_DIR = "output"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# --------------------------------------------- Load reference data --------------------------------------------- #
def load_csv_column(path, column):
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        return [row[column].strip() for row in reader]

def load_banks(path):
    """Returns list of (FIN_INST_ID, FIN_INST_NAME) tuples."""
    with open(path, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for r in reader:
            print(r)
#         return [(r["FIN_INST_ID"].strip(), r["FIN_INST_NAME"].strip()) for r in reader]

# legal_ids = load_csv_column(LIST_LEGAL_ID_PATH, "LEGAL_ID")
banks     = load_banks(LIST_BANK_PATH)
