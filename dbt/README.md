## dbt structure
models/
├── sources.yml                      ← declares all Synapse external tables
│
├── raw/                             ← materialised as views
│   ├── stg_customer_profile.sql     ← cast + rename only
│   ├── stg_cic.sql
│   └── stg_transactions.sql
│
├── curated/                         ← materialised as incremental tables
│   ├── hubs/
│   │   ├── hub_customer.sql
│   │   ├── hub_account.sql
│   │   └── hub_transaction.sql
│   ├── links/
│   │   ├── lnk_customer_account.sql
│   │   └── lnk_account_transaction.sql
│   ├── satellites/
│   │   ├── sat_customer_profile.sql   ← cleaning: sex codes, DOB, dedup
│   │   ├── sat_customer_credit.sql    ← cleaning: score range, future dates
│   │   └── sat_account_balance.sql
│   └── schema.yml                     ← data tests for all curated models
│
├── mart/                            ← materialised as tables
│   ├── dimensions/
│   │   ├── dim_customer.sql           ← SCD Type 2 from DV satellites
│   │   ├── dim_date.sql               ← generated date spine
│   │   └── dim_account.sql
│   ├── facts/
│   │   └── fact_transactions.sql
│   └── schema.yml
│
└── macros/
    └── generate_hash_key.sql          ← MD5 hash key + hash diff macros

## High-level goals
- The system should be intuitive for business users, not just developers.
- Data from various sources must be presented with consistent labels and definitions.
- The system should adapt to needs and changes.
- It must safeguard sensitive information.
- The data warehouse team and business users should agree on delivery timelines, mainly when time limits restrict data cleaning or validation.
- It must have the right data to support decision-making.
- The business users must accept the DW/BI system; you thought you built an excellent data warehousing system, but nobody used it; your solutions were not that great.

## Knowleadge revisit

### About Data Vault
- 3 components: Hubs, Links, and Satellites
    - Hubs: contains only identifiers -> minimal structure -> remain stable even as business rules and descriptive attributes change over time. This immutability makes Hubs the perfect foundation for building an enterprise-wide integration layer. Examples: a customer Hub might store customer numbers, a product Hub contains product codes, and a location Hub holds store identifiers
    - Links: capture the relationships between business entities by connecting two or more Hubs together. Like Hubs, Links contain no descriptive attributes; they purely represent that a relationship exists -> extraordinary modeling flexibility compared to traditional foreign key relationships
    - Satellites: store all the descriptive attributes about Hubs and Links, providing context and detail about business entities and their relationships. M->1 Satellite -> Hub/Link. Feature: historization capability -> enables several critical capabilities for modern data management

## Reference
[Data Vault Architecture: Everything You Need to Know Before You Build](https://www.montecarlodata.com/blog-data-vault-architecture-data-quality/)