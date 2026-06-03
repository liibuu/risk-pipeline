# Banking Data Pipeline
A project that simulates a data pipeline for a bank's department. It is built on the Azure ecosystem, from raw source ingestion through transformation, orchestration, and ML model management using real architectural patterns from the financial services industry.
The pipeline follows a Vietnamese banking context (VIB Bank), handling three source systems and delivering data to two use cases (risk modelling and risk dashboard).

![Business View](docs/business_view.png)

1. [Architecture Overview](#1-architecture-overview)
2. [Techstack](#2-techstack)
3. [Repository Structure](#3-repository-structure)
4. [Key Design Decisions](#4-key-design-decisions)

## 1. Architecture Overview

### Data Sources
Three source systems feed the pipeline, each representing a common pattern in banking infrastructure:
- **Customer profile**: internal customer data
- **Online banking**: transaction and activity events
- **Products**: lending, card, deposit

All data is from on-prem SQL Server, extracted via Azure Data Factory using a Self-hosted Integration Runtime (I made it for simple right now, so it is still open for [improvement](#potential-improvement)).

### Storage Zones (Medallion Architecture)
Data flows through four zones in Azure Data Lake Storage Gen2 (striskpipelinegwc612, container risk-data):
```
landing/  →  raw/  →  curated/  →  mart/
```
- **landing**: raw files as received (CSV, XML, Parquet), no transformation.
- **raw**: format-normalised Parquet files, renamed to consistent conventions, all columns preserved including dirty ones.
- **curated**: Data Vault layer (Hubs, Links, Satellites) built with dbt on Azure Synapse Analytics Serverless, handling multi-source integration with full auditability.
- **mart**: Kimball star schema (facts and dimensions) built with dbt, serving two use cases.

### Use cases
- **Model monitoring dashboard**: reports and dashboards via Power BI connected to the mart layer.
- **Model development**: reports and ML model development, also consuming from mart and storing models in ADLS + MLflow. (tbd, based on [ml-pipeline-airflow](https://github.com/liibuu/ml-pipeline-airflow))

![Implementation View](docs/implementation_view.png)

## 2. Techstack
| Layer | Tools |
|---|---|
| Cloud infrastructure | Azure Data Lake Storage Gen2, Azure Data Factory, Azure Synapse Analytics, Azure Key Vault, Microsoft Entra ID |
| Streaming (planned) | Apache Kafka, Apache Flink |
| Transformation | dbt-synapse, SQL |
| Orchestration | Apache Airflow (Docker Compose) |
| ML & tracking | scikit-learn, MLflow |
| Data preparation | Python 3.11, pandas, scipy.stats, sqlalchemy |
| Reporting | Power BI |
| Dev tools | SSMS, PowerShell, Git |
| Naming convention | Microsoft Cloud Adoption Framework (CAF) |
| Azure region | Germany West Central (`germanywestcentral`) |

## 3. Repository Structure
```
risk-pipeline/
├── airflow/            # Docker Compose Airflow setup
│   ├── dags/
│   ├── setup/
│   └── docker-compose.yml
├── data_prep/          # One-time synthetic data generation (not part of pipeline)
├── dbt/                # dbt project (raw → curated → mart models)
│   ├── models/
│   │   ├── raw/
│   │   ├── curated/
│   │   └── mart/
│   └── profiles.yml
├── scripts/            # Utility scripts (Azure ecosystem setup, landing → raw conversion, cleaning_adls.py, etc.)
├── docs/               # Images, graphs
└── README.md
```
 
Each subdirectory contains its own README with implementation details.

## 4. Key Design Decisions
 
- **Data Vault + Kimball hybrid**: Data Vault in the curated layer handles multi-source integration with auditability; Kimball star schema in the mart layer provides analyst-friendly access. It reflects a common pattern in financial services.
- **Synapse Serverless over dedicated pool**: Cost-appropriate for a portfolio project; requires CETAS-based materialisation and view-only raw staging due to platform constraints.
- **Service principal auth**: `ActiveDirectoryInteractive` is incompatible with university tenant restrictions; `ActiveDirectoryServicePrincipal` is the working approach.

## Potential improvement
- Data sources: instead of using only on-prem SQL source, the project can open to ingest from (1) streaming for transaction/activity data and (2) CIC parsing for external credit rating data
- landing_to_raw.py: chunked ParquetWriter approach

## Helpers
```bash
$env:PATH += ";C:\tools\trufflehog"
trufflehog git file://D:/risk-pipeline
```
