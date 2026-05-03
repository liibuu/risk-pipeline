-- 0. Create a dedicated database for the pipeline
CREATE DATABASE db_risk_pipeline;

-- 1. Create a master key (required for credentials) (remember change to the new db)
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'xxx';

-- 2. Create credential using managed identity
CREATE DATABASE SCOPED CREDENTIAL managed_identity_cred
WITH IDENTITY = 'Managed Identity';

-- 3. Create external data source pointing at your ADLS container
CREATE EXTERNAL DATA SOURCE risk_data_source
WITH (
    LOCATION = 'https://striskpipelinegwc612.blob.core.windows.net/risk-data', --container
    CREDENTIAL = managed_identity_cred
);

-- 4. Create Parquet file format
CREATE EXTERNAL FILE FORMAT parquet_format
WITH (
    FORMAT_TYPE = PARQUET,
    DATA_COMPRESSION = 'org.apache.hadoop.io.compress.SnappyCodec'
);

