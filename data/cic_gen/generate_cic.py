import os
import csv
import random
import numpy as np
from scipy.stats import skewnorm, poisson
from datetime import datetime, timedelta
from xml.etree.ElementTree import Element, SubElement, ElementTree, indent
import xml.etree.ElementTree as ET

# ── Directory ──────────────────────────────────────────────────────────
LIST_LEGAL_ID_PATH = "input/list_legal_id.csv"
LIST_BANK_PATH     = "input/list_bank.csv"

OUTPUT_DIR = "output"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# ── Load reference data ───────────────────────────────────────────────────────
def load_legal_ids(path):
    """Read LEGAL_ID as plain string; handle scientific notation from Excel."""
    with open(path, newline="", encoding="utf-8-sig") as f:
        reader = csv.reader(f)
        header = [h.strip() for h in next(reader)]
        col_idx = header.index("LEGAL_ID")
        ids = []
        for row in reader:
            raw = row[col_idx].strip()
            # If Excel serialised a large integer as scientific notation, convert back
            try:
                ids.append(str(int(float(raw))))
            except ValueError:
                ids.append(raw)
        return ids
 
def load_banks(path):
    with open(path, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        return [(r["FIN_INST_ID"].strip(), r["FIN_INST_NAME"].strip()) for r in reader]
 
legal_ids = load_legal_ids(LIST_LEGAL_ID_PATH)
banks     = load_banks(LIST_BANK_PATH)
 
# ── XML writer: produces <tag></tag> (never self-closing), proper indentation ─
def _escape(text):
    return str(text).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
 
def _to_lines(elem, level=0):
    pad  = "    " * level
    pad1 = "    " * (level + 1)
    tag  = elem.tag
    text = elem.text or ""
    children = list(elem)
 
    if not children:
        # Leaf node — opening and closing on the same line
        return [f"{pad}<{tag}>{_escape(text)}</{tag}>"]
 
    lines = [f"{pad}<{tag}>"]
    for child in children:
        lines.extend(_to_lines(child, level + 1))
    lines.append(f"{pad}</{tag}>")
    return lines
 
def write_xml(root, path):
    lines = _to_lines(root, level=0)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
 
# ── Random helpers ────────────────────────────────────────────────────────────
def skew_sample(alpha, loc, scale, low, high):
    while True:
        v = skewnorm.rvs(alpha, loc=loc, scale=scale)
        if low <= v <= high:
            return int(round(v))
 
def loan_record_count():
    return random.choices([0, 1, 2, 3], weights=[17, 55, 22, 6])[0]
 
def cc_record_count():
    return random.choices([0, 1, 2, 3], weights=[27, 49, 21, 2])[0]
 
def pick_bank():
    return random.choice(banks)
 
def yearmonth_list(start_ym="202603", n=12):
    year, month = int(start_ym[:4]), int(start_ym[4:])
    result = []
    for _ in range(n):
        result.append(f"{year}{month:02d}")
        month -= 1
        if month == 0:
            month = 12
            year -= 1
    return result
 
def random_date_within_6months(end_date="20260331"):
    end   = datetime.strptime(end_date, "%Y%m%d")
    start = end - timedelta(days=180)
    rand_day  = start + timedelta(days=random.randint(0, (end - start).days))
    rand_time = timedelta(seconds=random.randint(0, 86399))
    return (rand_day + rand_time).strftime("%Y%m%d %H:%M:%S")
 
_score_population = np.clip(skewnorm.rvs(-8, loc=850, scale=300, size=100_000), 0, 1200)
 
def score_percentile(score):
    return int(round(np.mean(_score_population < score) * 100))
 
def score_to_rank(score):
    if score >= 800: return 1
    if score >= 740: return 2
    if score >= 670: return 3
    if score >= 580: return 4
    return 5
 
# ── XML helpers ───────────────────────────────────────────────────────────────
def txt(parent, tag, value=""):
    el = SubElement(parent, tag)
    el.text = "" if value == "" else str(value)
    return el
 
def build_loan_records(n):
    result = []
    for _ in range(n):
        fin_id, fin_name = pick_bank()
        result.append({
            "fin_id": fin_id, "fin_name": fin_name,
            "count":  random.randint(1, 2),
            "bal":    skew_sample(5, 550_000_000, 800_000_000, 15_000_000, 17_000_000_000),
        })
    return result
 
def build_cc_records(n):
    result = []
    for _ in range(n):
        fin_id, fin_name = pick_bank()
        result.append({
            "fin_id": fin_id, "fin_name": fin_name,
            "count":  random.randint(1, 2),
            "bal":    skew_sample(6, 5_500_000, 30_000_000, 10_000_000, 1_700_000_000),
        })
    return result
 
# ── Main XML builder ──────────────────────────────────────────────────────────
def generate_xml(legal_id, cic_number):
    root = Element("CREDIT_INFO")
 
    req = SubElement(root, "REQUEST_INFO")
    txt(req, "COMPANY",        "Commercial Bank ABC")
    txt(req, "ADDRESS",        "No 27 Street XXX, Hanoi")
    txt(req, "ACCOUNT",        "00001")
    txt(req, "PHONE")
    txt(req, "REQUEST_NO",     "ABC260417.0424.CC06")
    txt(req, "REQUEST_TIME",   "20260417 09:08")
    txt(req, "RESPONSE_TIME",  "20260417 09:08")
    txt(req, "RESPONSE_COUNT", "1")
 
    resp = SubElement(root, "RESPONSE_INFO")
 
    legal = SubElement(resp, "LEGAL_INFO")
    txt(legal, "CIC_NUMBER",            cic_number)
    txt(legal, "CUSTOMER_NAME")
    txt(legal, "ADDRESS")
    txt(legal, "LEGAL_ID",              legal_id)
    txt(legal, "OTHER_ID")
    txt(legal, "BUSINESS_REGISTRATION")
    txt(legal, "TAX_ID")
    txt(legal, "TGD_GD")
    txt(legal, "LEGAL_REPRESENTATIVE")
    txt(legal, "NOTE")
    txt(legal, "XTHSKH",               "1")
 
    curr = SubElement(resp, "CURR_CREDIT_HIST")
 
    loan_recs = build_loan_records(loan_record_count())
    cc_recs   = build_cc_records(cc_record_count())
 
    loan_bal_el = SubElement(curr, "LOAN_BAL")
    for rec in loan_recs:
        r = SubElement(loan_bal_el, "RECORD")
        txt(r, "DATE",          "20260408")
        txt(r, "FIN_INST_ID",   rec["fin_id"])
        txt(r, "FIN_INST_NAME", rec["fin_name"])
        txt(r, "LOAN_COUNT",    rec["count"])
        txt(r, "LOAN_BAL",      rec["bal"])
        txt(r, "OVERDUE_AMT",   "0")
        txt(r, "OVERDUE_DAY",   "0")
 
    cc_bal_el = SubElement(curr, "CREDIT_CARD_BAL")
    for rec in cc_recs:
        r = SubElement(cc_bal_el, "RECORD")
        txt(r, "DATE",              "20260408")
        txt(r, "FIN_INST_ID",       rec["fin_id"])
        txt(r, "FIN_INST_NAME",     rec["fin_name"])
        txt(r, "CREDIT_CARD_COUNT", rec["count"])
        txt(r, "CREDIT_CARD_LIMIT")
        txt(r, "CREDIT_CARD_BAL",   rec["bal"])
        txt(r, "OVERDUE_AMT",       "0")
        txt(r, "OVERDUE_DAY",       "0")
 
    txt(curr, "VAMC_OUTSTANDING")
    txt(curr, "CREDIT_CONTRACT")
 
    past = SubElement(resp, "PAST_CREDIT_HIST")
 
    total_loan_curr = sum(r["bal"] for r in loan_recs)
    total_cc_curr   = sum(r["bal"] for r in cc_recs)
 
    n_months       = random.randint(0, 12)
    ym_list        = yearmonth_list("202603", n_months)
 
    outstanding_el = SubElement(past, "OUTSTANDING_12MON")
    prev_loan = total_loan_curr
    prev_cc   = total_cc_curr
    for i, ym in enumerate(ym_list):
        r = SubElement(outstanding_el, "RECORD")
        txt(r, "YEARMONTH", ym)
        if i == 0:
            loan_out = total_loan_curr
            cc_out   = total_cc_curr
        else:
            loan_out = int(round(prev_loan * random.uniform(1.05, 1.15)))
            cc_out   = prev_cc
        txt(r, "LOAN_OUTSTANDING", loan_out if loan_recs else "")
        txt(r, "CARD_OUTSTANDING", cc_out   if cc_recs   else "")
        txt(r, "TOTAL_OUSTANDING", loan_out + cc_out)
        prev_loan = loan_out
        prev_cc   = cc_out
 
    txt(past, "DEBT_GROUP2_12MON",     "Y" if random.random() < 0.03  else "")
    txt(past, "DEBT_BAD_60MON",        "Y" if random.random() < 0.008 else "")
    txt(past, "REQUEST_CC_HIST_36MON", "Y" if random.random() < 0.05  else "")
 
    col = SubElement(resp, "COLLATERAL")
    txt(col, "FIN_INST_COUNT")
    txt(col, "COLLATERAL_COUNT")
    txt(col, "COLLATERAL_DESC", "None")
 
    x   = np.arange(0, 13)
    pmf = poisson.pmf(x, mu=1)
    pmf = pmf / pmf.sum()
    n_requests = int(np.random.choice(x, p=pmf))
 
    req_hist_el = SubElement(resp, "REQUEST_HIST_12MON")
    products   = ["LOAN", "CREDIT CARD", "COLLATERAL"]
    prod_probs = [0.36, 0.52, 0.12]
    for _ in range(n_requests):
        r = SubElement(req_hist_el, "RECORD")
        fin_id, fin_name = pick_bank()
        txt(r, "PRODUCT",       random.choices(products, weights=prod_probs)[0])
        txt(r, "REQUEST_DATE",  random_date_within_6months("20260331"))
        txt(r, "FIN_INST_ID",   fin_id)
        txt(r, "FIN_INST_NAME", fin_name)
 
    raw_score = skewnorm.rvs(-8, loc=850, scale=300)
    score     = int(np.clip(round(raw_score), 0, 1200))
    rank      = score_to_rank(score)
    pct       = score_percentile(score)
 
    cs = SubElement(resp, "CREDIT_SCORE")
    txt(cs, "SCORE",        score)
    txt(cs, "RANK",         rank)
    txt(cs, "SCORE_DATE",   "20260330")
    txt(cs, "SCORE_PCT",    pct)
    txt(cs, "SCORE_PCT_DESC",
        f"The customer' score is higher than {pct}% of others' scores in CIC database")
 
    txt(resp, "OTHER_INFO")
 
    return root
 
# ── Main loop ─────────────────────────────────────────────────────────────────
print(f"Generating {len(legal_ids)} XML files …")
for idx, legal_id in enumerate(legal_ids, start=1):
    cic_number = str(idx).zfill(10)
    root = generate_xml(legal_id, cic_number)
    out_path = os.path.join(OUTPUT_DIR, f"cic_{legal_id}.xml")
    write_xml(root, out_path)
 
print(f"Done. Files written to '{OUTPUT_DIR}/'")