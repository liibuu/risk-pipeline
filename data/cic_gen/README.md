CREDIT_INFO/RESPONSE_INFO/LEGAL_INFO/CIC_NUMBER -> unique per LEGAL_ID
CREDIT_INFO/RESPONSE_INFO/LEGAL_INFO/LEGAL_ID -> get from list_legal_id.csv, each LEGAL_ID 1 CIC xml file
CREDIT_INFO/RESPONSE_INFO/CURR_CREDIT_HIST/LOAN_BAL 
    ->  multiple records random.choices([0, 1, 2, 3], weights=[17, 55, 22, 6]), 
        FIN_INST from list_bank.csv, 
        LOAN_COUNT (min: 1, max: 2), 
        LOAN_BAL: random with skewnorm alpha = 5, loc = 550_000_000, scale = 800_000_000, clip to [15_000_000, 17_000_000_000]
CREDIT_INFO/RESPONSE_INFO/CURR_CREDIT_HIST/CREDIT_CARD_BAL
    ->  multiple records random.choices([0, 1, 2, 3], weights=[27, 49, 21, 2]), 
        FIN_INST from list_bank.csv, 
        LOAN_COUNT (min: 1, max: 2), 
        LOAN_BAL: random with skewnorm alpha = 6, loc = 5_500_000, scale = 30_000_000, clip to [10_000_000, 1_700_000_000]
CREDIT_INFO/RESPONSE_INFO/PAST_CREDIT_HIST/OUTSTANDING_12MON 
    ->  multiple records with YEARMONTH backwards from 202603, number of records as uniform distribution min = 0, max = 12
        LOAN_OUTSTANDING and CARD_OUTSTANDING follows LOAN_BAL and CREDIT_CARD_BAL in CURR_CREDIT_HIST in the according month
        If the according month not available then: LOAN_BAL increase by 5-15% (randomly) per (descending) month; CREDIT_CARD_BAL: keep same
        TOTAL_OUSTANDING = LOAN_OUTSTANDING + CARD_OUTSTANDING
CREDIT_INFO/RESPONSE_INFO/PAST_CREDIT_HIST/DEBT_GROUP2_12MON -> 3% with a flag as yes, others blank
CREDIT_INFO/RESPONSE_INFO/PAST_CREDIT_HIST/DEBT_BAD_60MON -> 0.8% with a flag as yes, others blank
CREDIT_INFO/RESPONSE_INFO/PAST_CREDIT_HIST/REQUEST_CC_HIST_36MON -> 5% with a flag as yes, others blank
CREDIT_INFO/RESPONSE_INFO/REQUEST_HIST_12MON
    ->  multiple records follows Poisson distribution, mu = 1, x = np.arange(0, 13), pmf = poisson.pmf(x, mu)
        PRODUCT random from list ['LOAN', 'CREDIT CARD', 'COLLATERAL'] with according probability [0.36, 0.52, 0.12]
        REQUEST_DATE random within 6 months from 20260331
        FIN_INST from list_bank.csv, 
        LOAN_COUNT (min: 1, max: 2), 
        LOAN_BAL: random skewnorm alpha = 5, loc = 550_000_000, scale = 800_000_000, clip to [15_000_000, 17_000_000_000]
CREDIT_INFO/RESPONSE_INFO/CREDIT_SCORE/SCORE -> random alpha = -8, loc = 850, scale = 300
CREDIT_INFO/RESPONSE_INFO/CREDIT_SCORE/RANK -> [800, 850] = 1, [740, 799] = 2, [670, 739] = 3, [580, 669] = 4, [0, 579] = 5
CREDIT_INFO/RESPONSE_INFO/CREDIT_SCORE/SCORE_PCT -> percentile of the score
CREDIT_INFO/RESPONSE_INFO/CREDIT_SCORE/SCORE_PCT_DESC -> description: The customer' score is higher than xx% of others' scores in CIC database



Other requirements:
give me 2 lines at the beginning for paths to list_legal_id.csv and list_bank.csv