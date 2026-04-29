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
   - [1.3 Security & Access Configuration](#13-security--access-configuration)
   - [1.4 Microsoft Integration Runtime](#14-microsoft-integration-runtime)
   - [1.5 ADF Linked Services](#15-adf-linked-services)
   - [1.6 ADF Copy Pipeline](#16-adf-copy-pipeline)
2. [Part 2: Data Transformation](#part-2-data-transformation)

3. [Part 3: Data Reporting](#part-4-data-reporting)


---

## Part 1: Data Ingestion

### 1.1 On-Premises SQL Server Setup

#### Install SQL Server 2025 Developer Edition
- Download **Enterprise Developer Edition** from Microsoft's SQL Server download page (free for non-production use)
- Install SQL Server Management Studio (SSMS) 22

#### Connect SSMS to SQL Server
1. Open SSMS
2. In the connection dialog:
   - **Server name** → `LAPTOP-UD1GU8CS` or `localhost`
   - **Authentication** → Windows Authentication
   - **Trust Server Certificate** → ✅ checked (required for SQL Server 2025)
3. Click **Connect**

#### Restore .bak File
1. In SSMS Object Explorer, right-click **Databases** → **Restore Database**
2. Select **Device** → click `...` → **Add** → navigate to your `.bak` file
3. Click **OK** to restore
4. Database will appear as `vib-data`

#### Create ADF SQL User
Run this in SSMS connected as Windows Authentication:
```sql
-- Drop existing user and login if they exist
USE [vib-data];
IF EXISTS (SELECT name FROM sys.database_principals WHERE name = 'adf_user')
    DROP USER adf_user;

USE [master];
IF EXISTS (SELECT name FROM sys.server_principals WHERE name = 'adf_user')
    DROP LOGIN adf_user;

-- Create server login
CREATE LOGIN adf_user 
WITH PASSWORD = 'YourPassword123!',
CHECK_POLICY = OFF,
CHECK_EXPIRATION = OFF;

-- Enable the login
ALTER LOGIN adf_user ENABLE;

-- Create user in vib-data database
USE [vib-data];
CREATE USER adf_user FOR LOGIN adf_user;

-- Grant permissions
ALTER ROLE db_datareader ADD MEMBER adf_user;
ALTER ROLE db_datawriter ADD MEMBER adf_user;
```

#### Enable SQL Authentication Mode
1. In SSMS, right-click server → **Properties** → **Security**
2. Select **"SQL Server and Windows Authentication mode"**
3. Open **SQL Server Configuration Manager**
4. Click **SQL Server Services** → right-click **SQL Server (MSSQLSERVER)** → **Restart**
5. Also enable **TCP/IP** and **Named Pipes** under **SQL Server Network Configuration** → **Protocols for MSSQLSERVER**

---

### 1.2 Azure Resources Setup

Create all resources in the same **Region** (e.g. West Europe) and **Resource Group**.

> ⚠️ **Note for student accounts:** Some resource providers need manual registration. If you get a `NotRegistered` error, go to **Subscriptions → Resource providers** and register: `Microsoft.Synapse`, `Microsoft.Sql`, `Microsoft.SqlVirtualMachine`, `Microsoft.Storage`, `Microsoft.Compute`, `Microsoft.Network`

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
```

#### ADLS Gen2 (Storage Account)
1. Search **"Storage accounts"** → **+ Create**
2. **Name** → `striskpipeline`
3. **Redundancy** → LRS
4. **Advanced tab** → enable **Hierarchical namespace** ← makes it Gen2
5. After creation, create a container called `risk-data` with 4 directories:
   - `landing`
   - `raw`
   - `curated`
   - `mart`

#### Azure Data Factory
1. Search **"Data factories"** → **+ Create**
2. **Name** → `adf-data-pipeline`
3. **Version** → V2

#### Azure Databricks
1. Search **"Azure Databricks"** → **+ Create**
2. **Name** → `adb-data-pipeline`
3. **Pricing tier** → Premium

#### Azure Synapse Analytics
1. Search **"Azure Synapse Analytics"** → **+ Create**
2. **Name** → `synapse-credit-risk`
3. **Data Lake Storage Gen2** → select `creditrisk`
4. **File system name** → type `synapse`

#### Azure Key Vault
1. Search **"Key vaults"** → **+ Create**
2. **Name** → `kv-data-pipeline` (must be globally unique - add numbers if taken)
3. **Pricing tier** → Standard

---

### 1.3 Security & Access Configuration

#### Create Service Principal in Microsoft Entra ID
1. Search **"Microsoft Entra ID"** → **App registrations** → **+ New registration**
2. **Name** → `sp-credit-risk`
3. Click **Register**
4. Note down from **Overview** page:
   - **Application (client) ID**
   - **Directory (tenant) ID**
5. Go to **Certificates & secrets** → **+ New client secret**
   - **Description** → `secret-data-pipeline`
   - **Expires** → 6 months
6. ⚠️ **Copy the secret Value immediately** - it won't be shown again after leaving the page

#### Assign SP Roles on ADLS Gen2
1. Go to `creditrisk` storage account → **Access Control (IAM)** → **+ Add role assignment**
2. Role → **Storage Blob Data Contributor**
3. Member → `sp-credit-risk`

#### Assign SP Roles on Key Vault
1. Go to Key Vault → **Access Control (IAM)** → **+ Add role assignment**
2. Role → **Key Vault Secrets Officer**
3. Member → your own account (to manage secrets)
4. Repeat and add **Key Vault Secrets User** for `sp-credit-risk`

#### Store Secrets in Key Vault
Go to Key Vault → **Secrets** → **+ Generate/Import** and create:

| Name | Value |
|---|---|
| `sp-client-secret` | Client Secret value |
| `sp-client-id` | Application (client) ID |
| `sp-tenant-id` | Directory (tenant) ID |
| `sql-adf-password` | `adf_user` password |
| `synapse-sql-password` | `sqladminuser` password |

#### Save Credentials Locally
Create a `.env` file in your project folder:
```
TENANT_ID=your-tenant-id
CLIENT_ID=your-client-id
CLIENT_SECRET=your-client-secret
```
Add to `.gitignore`:
```
.env
*.ipynb
```
> ⚠️ **Never commit credentials to GitHub.** If accidentally pushed, immediately revoke and regenerate the secret in Entra ID, then update it everywhere it's used.

---

### 1.4 Microsoft Integration Runtime

Integration Runtime (IR) is the bridge between Azure Data Factory and your on-premises SQL Server.

1. In ADF Studio → **Manage** → **Integration runtimes** → **+ New**
2. Select **Self-Hosted** → **Continue**
3. **Name** → `ir-onprem-sqlserver`
4. Click **Create**
5. Click **"Download and install integration runtime"**
6. Install on your laptop
7. During setup, paste **Key 1** from ADF → click **Register** → **Finish**
8. IR should show as **Running** in ADF Studio ✅

---

### 1.5 ADF Linked Services

#### Linked Service 1: On-prem SQL Server
1. ADF Studio → **Manage** → **Linked Services** → **+ New**
2. Search **"SQL Server"** → select it
3. Fill in:
   - **Name** → `ls-onprem-sqlserver`
   - **Integration runtime** → `ir-onprem-sqlserver`
   - **Server name** → `LAPTOP-UD1GU8CS`
   - **Database name** → `vib-data`
   - **Authentication** → SQL Authentication
   - **Username** → `adf_user`
   - **Password** → your adf_user password
   - **Trust Server Certificate** → ✅ checked
4. **Test connection** → **Create**

#### Linked Service 2: ADLS Gen2
1. **+ New** → search **"Azure Data Lake Storage Gen2"**
2. Fill in:
   - **Name** → `ls-adls-creditrisk`
   - **Authentication** → Service Principal
   - **Storage account** → `creditrisk`
   - **Tenant ID** → your tenant ID
   - **Service Principal ID** → your client ID
   - **Service Principal key** → your client secret
3. **Test connection** → **Create**

---

### 1.6 ADF Copy Pipeline

#### Dynamic Pipeline (All Tables)
1. ADF Studio → **Author** → **+** → **Pipeline**
2. **Name** → `pl-copy-all-tables-to-bronze`

**Lookup Activity:**
- **Name** → `lookup-all-tables`
- **Dataset** → `ds_sqlserver_vib_data` (SQL Server dataset)
- **Use query** → Query:
```sql
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_TYPE = 'BASE TABLE'
```
- **First row only** → unchecked

**ForEach Activity:**
- **Name** → `foreach-tables`
- **Items** → `@activity('lookup-all-tables').output.value`

**Inside ForEach - Copy Activity:**
- **Name** → `copy-table-to-bronze`
- **Source** → SQL Server dataset with query:
```
@concat('SELECT * FROM ', item().TABLE_NAME)
```
- **Sink** → ADLS Gen2 dataset (`ds_adls_bronze`):
  - **File system** → `creditrisk-data`
  - **Directory** → `@concat('bronze/', dataset().tableName)`
  - **File name** → `@concat(dataset().tableName, '.parquet')`
  - **Compression** → **Snappy**

> ⚠️ Always set Parquet compression to **Snappy** - leaving it as "No compression" causes a null codec error.


---

## Naming Conventions

| Prefix | Type | Example |
|---|---|---|
| `rg-` | Resource Group | `rg-risk-pipeline` |
| `ls-` | Linked Service | `ls-onprem-sqlserver` |
| `ds-` | Dataset | `ds_sqlserver_vib_data` |
| `pl-` | Pipeline | `pl-copy-all-tables-to-bronze` |
| `ir-` | Integration Runtime | `ir-onprem-sqlserver` |
| `sp-` | Service Principal | `sp-credit-risk` |
| `kv-` | Key Vault | `kv-data-pipeline` |
| `adf-` | Data Factory | `adf-data-pipeline` |
| `adb-` | Databricks | `adb-data-pipeline` |