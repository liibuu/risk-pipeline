# Risk Azure Data Pipeline - Instruction Manual

## Overview

This doc serves as an instruction manual for the risk pipeline, ingesting from an on-premises SQL Server + streaming event, transforming data by dbt.

**Architecture**
```
On-prem SQL Server → ADF → ...
```

**Azure Resources Used**
- Azure Data Lake Storage Gen2 (ADLS Gen2)
- Azure Data Factory (ADF)
- Azure Synapse Analytics

**Additionals**
- Azure Key Vault
- Microsoft Entra ID (AAD)

---

## Table of Contents

1. [Part 1: Data Ingestion](#part-1-data-ingestion)
   - [1.1 On-Premises SQL Server Setup](#11-on-premises-sql-server-setup)
   - [1.2 Azure Resources Setup](#12-azure-resources-setup)

   [Naming Conventions](#naming-conventions)

---

## Part 1: Data Ingestion

### 1.1 On-Premises SQL Server Setup

### 1.2 Azure Resources Setup

Create all resources in the same **Region** as **Resource Group**.

```bash
# Check available locations
az policy assignment list --scope "/subscriptions/xxx" --query "[0].parameters" -o json

# Resource Group
az group create --name rg-risk-pipeline --location germanywestcentral

# Create the Storage Account
az storage account create `
    --name striskpipelinegwc612 ` 
    --resource-group rg-risk-pipeline ` 
    --location germanywestcentral `
    --sku Standard_LRS `
    --kind StorageV2 `

# Create container and 4 folders
$ACCOUNT_KEY=$(az storage account keys list `
  --account-name striskpipelinegwc612 `
  --resource-group rg-risk-pipeline `
  --query "[0].value" -o tsv) `

az storage container create `
  --name risk-data `
  --account-name striskpipelinegwc612 `
  --account-key $ACCOUNT_KEY
  
foreach ($dir in @("landing", "raw", "curated", "mart")) { `
  az storage blob upload `
    --account-name striskpipelinegwc612 `
    --account-key $ACCOUNT_KEY `
    --container-name risk-data `
    --name "$dir/.keep" `
    --file "NUL" `
    --overwrite
}

# Create sub-folders in raw/
foreach ($dir in @("onlinebanking", "cic", "customerprofile")) { `
  az storage blob upload `
    --account-name striskpipelinegwc612 `
    --account-key $ACCOUNT_KEY `
    --container-name risk-data `
    --name "raw/$dir/.keep" `
    --file "NUL" `
    --overwrite
}

# Upload data to ADLS
# customerprofile source
az storage blob upload --account-name striskpipelinegwc612 --account-key $ACCOUNT_KEY --container-name risk-data --name "raw/customerprofile/base_customer.parquet" --file "./raw/base_customer.parquet"
az storage blob upload --account-name striskpipelinegwc612 --account-key $ACCOUNT_KEY --container-name risk-data --name "raw/customerprofile/base_deposit.parquet" --file "./raw/base_deposit.parquet"

# onlinebanking source
az storage blob upload --account-name striskpipelinegwc612 --account-key $ACCOUNT_KEY --container-name risk-data --name "raw/onlinebanking/base_activity.parquet" --file "./raw/base_activity.parquet"
az storage blob upload --account-name striskpipelinegwc612 --account-key $ACCOUNT_KEY --container-name risk-data --name "raw/onlinebanking/base_transaction.parquet" --file "./raw/base_transaction.parquet"

# cic source
az storage blob upload --account-name striskpipelinegwc612 --account-key $ACCOUNT_KEY --container-name risk-data --name "raw/cic/base_card.parquet" --file "./raw/base_card.parquet"
az storage blob upload --account-name striskpipelinegwc612 --account-key $ACCOUNT_KEY --container-name risk-data --name "raw/cic/base_lending.parquet" --file "./raw/base_lending.parquet"


```

For Synapse-specific setup, refer to [Synapse setup](./synapse/)

## Naming Conventions

| Prefix | Type | Example |
|---|---|---|
| `rg` | Resource sroup | `rg-risk-pipeline` |
| `st` | Storage account | `striskpipelinegwc612` |
|  | Container | `risk-data` |
| `synapse` | Synapse | `synapse-riskpipeline` |