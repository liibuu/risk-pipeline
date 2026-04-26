import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from scipy.stats import skewnorm, poisson, nbinom


# ----------------------- Select random ~22% LEGAL_ID who have CIC information ----------------------- #
# df_legal = pd.read_csv("../data_prep/landing/Data_customer.csv", dtype={"LEGAL_ID": str})
# sample = df_legal[df_legal["LEGAL_ID"].notna()].sample(frac=0.22, random_state=42)
# sample[["CUSTOMER_NUMBER", "LEGAL_ID"]].to_csv("list_legal_id.csv", index=False)
# print(f"    + {len(sample):,} rows exported to list_legal_id.csv")

# ----------------------- List banks ----------------------- #
# df_bank = pd.read_csv("material/list_bank.csv", dtype={"FIN_INST_ID": str})
# print(df_bank)

# ----------------------- Quick check stats of lending ----------------------- #
# df = pd.read_csv("../data_prep/landing/Data_lending.csv")
# fig, axes = plt.subplots(1, 2, figsize=(14, 5))

# # raw distribution
# axes[0].hist(df["LOAN_AMOUNT"].dropna(), bins=100, color="steelblue", edgecolor="none")
# axes[0].set_title("LOAN_AMOUNT Distribution")
# axes[0].set_xlabel("LOAN_AMOUNT")
# axes[0].set_ylabel("Count")

# # log scale for skewed data
# axes[1].hist(df["LOAN_AMOUNT"].dropna(), bins=100, color="steelblue", edgecolor="none", log=True)
# axes[1].set_title("LOAN_AMOUNT Distribution (log scale)")
# axes[1].set_xlabel("LOAN_AMOUNT")
# axes[1].set_ylabel("Count (log)")

# plt.tight_layout()
# plt.show()
# print(df["LOAN_AMOUNT"].describe())

# ----------------------- Make distributions for LOAN in CIC ----------------------- #
# skewnorm: positive alpha = right skew
# alpha = 5           # right skew strength
# loc = 550_000_000   # shifts distribution left so mode lands near 600
# scale = 800_000_000 # controls fatness / spread

# # sample and clip to [15, 17000]
# samples = skewnorm.rvs(alpha, loc=loc, scale=scale, size=10000, random_state=42)
# samples = np.clip(samples, 15_000_000, 17_000_000_000)

# fig, axes = plt.subplots(1, 2, figsize=(14, 5))

# axes[0].hist(samples, bins=100, color="steelblue", edgecolor="none")
# axes[0].axvline(600_000_000, color="red", linestyle="--", label="mode=600")
# axes[0].set_title("LOAN_AMOUNT Simulated Distribution")
# axes[0].set_xlabel("LOAN_AMOUNT")
# axes[0].set_ylabel("Count")
# axes[0].legend()

# axes[1].hist(samples, bins=100, color="steelblue", edgecolor="none", log=True)
# axes[1].axvline(600_000_000, color="red", linestyle="--", label="mode=600")
# axes[1].set_title("LOAN_AMOUNT Simulated Distribution (log scale)")
# axes[1].set_xlabel("LOAN_AMOUNT")
# axes[1].set_ylabel("Count (log)")
# axes[1].legend()

# plt.tight_layout()
# plt.show()

# print(f"min:  {samples.min():.1f}")
# print(f"max:  {samples.max():.1f}")
# print(f"mean: {samples.mean():.1f}")
# print(f"mode: {pd.Series(samples).round().mode()[0]:.1f}")

# ----------------------- Make distributions for CARD in CIC ----------------------- #
# #skewnorm: positive alpha = right skew
# alpha = 6           # right skew strength
# loc = 5_500_000     # shifts distribution left so mode lands near 600
# scale = 30_000_000  # controls fatness / spread

# # sample and clip to [10, 1500]
# samples = skewnorm.rvs(alpha, loc=loc, scale=scale, size=10000, random_state=42)
# samples = np.clip(samples, 10_000_000, 1_700_000_000)
# samples = (np.round(samples / 1_000_000) * 1_000_000).astype(int)

# fig, axes = plt.subplots(1, 2, figsize=(14, 5))

# axes[0].hist(samples, bins=100, color="steelblue", edgecolor="none")
# axes[0].axvline(6_000_000, color="red", linestyle="--", label="mode=600")
# axes[0].set_title("CARD_LIMIT Simulated Distribution")
# axes[0].set_xlabel("CARD_LIMIT")
# axes[0].set_ylabel("Count")
# axes[0].legend()

# axes[1].hist(samples, bins=100, color="steelblue", edgecolor="none", log=True)
# axes[1].axvline(6_000_000, color="red", linestyle="--", label="mode=600")
# axes[1].set_title("CARD_LIMIT Simulated Distribution (log scale)")
# axes[1].set_xlabel("CARD_LIMIT")
# axes[1].set_ylabel("Count (log)")
# axes[1].legend()

# plt.tight_layout()
# plt.show()

# print(f"min:  {samples.min():.1f}")
# print(f"max:  {samples.max():.1f}")
# print(f"mean: {samples.mean():.1f}")
# print(f"mode: {pd.Series(samples).round().mode()[0]:.1f}")

# ----------------------- Make distributions for number of records in OUTSTANDING_12MON ----------------------- #
# samples = np.random.randint(0, 13, size=10000)

# x, counts = np.unique(samples, return_counts=True)

# plt.figure(figsize=(8, 5))
# plt.bar(x, counts / counts.sum(), color="steelblue", edgecolor="none")
# plt.title("Uniform Distribution (min=0, max=12)")
# plt.xlabel("Value")
# plt.ylabel("Probability")
# plt.xticks(x)
# plt.tight_layout()
# plt.show()

# print(f"min:  {samples.min()}")
# print(f"max:  {samples.max()}")
# print(f"mean: {samples.mean():.2f}")


# ----------------------- Make distributions for number of records in REQUEST_HIST_12MON ----------------------- #
# mu = 1
# x = np.arange(0, 13)
# pmf = poisson.pmf(x, mu)

# plt.figure(figsize=(8, 5))
# plt.bar(x, pmf, color="steelblue", edgecolor="none")
# plt.title("Poisson Distribution (λ=1, min=0, max=12)")
# plt.xlabel("Value")
# plt.ylabel("Probability")
# plt.xticks(x)
# plt.tight_layout()
# plt.show()

# samples = poisson.rvs(mu, size=10000, random_state=42)
# samples = np.clip(samples, 0, 12)
# print(f"min:  {samples.min()}")
# print(f"max:  {samples.max()}")
# print(f"mean: {samples.mean():.2f}")

# ----------------------- Make distributions for SCORE ----------------------- #
alpha = -8      # negative = left skew
loc = 850
scale = 300

samples = skewnorm.rvs(alpha, loc=loc, scale=scale, size=10000, random_state=42)
samples = np.clip(samples, 0, 850)

fig, axes = plt.subplots(1, 2, figsize=(14, 5))

axes[0].hist(samples, bins=100, color="steelblue", edgecolor="none")
axes[0].set_title("Simulated Distribution (left skew)")
axes[0].set_xlabel("Value")
axes[0].set_ylabel("Count")

axes[1].hist(samples, bins=100, color="steelblue", edgecolor="none", log=True)
axes[1].set_title("Simulated Distribution (left skew, log scale)")
axes[1].set_xlabel("Value")
axes[1].set_ylabel("Count (log)")

plt.tight_layout()
plt.show()

print(f"min:  {samples.min():.1f}")
print(f"max:  {samples.max():.1f}")
print(f"mean: {samples.mean():.1f}")
