-- base_customer
CREATE VIEW raw_ext.base_customer AS
SELECT * FROM OPENROWSET(
    BULK 'raw/customerprofile/base_customer.parquet',
    DATA_SOURCE = 'risk_data_source',
    FORMAT = 'PARQUET'
) AS r;

-- base_deposit
CREATE VIEW raw_ext.base_deposit AS
SELECT * FROM OPENROWSET(
    BULK 'raw/customerprofile/base_deposit.parquet',
    DATA_SOURCE = 'risk_data_source',
    FORMAT = 'PARQUET'
) AS r;

-- base_activity
CREATE VIEW raw_ext.base_activity AS
SELECT * FROM OPENROWSET(
    BULK 'raw/onlinebanking/base_activity.parquet',
    DATA_SOURCE = 'risk_data_source',
    FORMAT = 'PARQUET'
) AS r;

-- base_transaction
CREATE VIEW raw_ext.base_transaction AS
SELECT * FROM OPENROWSET(
    BULK 'raw/onlinebanking/base_transaction.parquet',
    DATA_SOURCE = 'risk_data_source',
    FORMAT = 'PARQUET'
) AS r;

-- base_card
CREATE VIEW raw_ext.base_card AS
SELECT * FROM OPENROWSET(
    BULK 'raw/cic/base_card.parquet',
    DATA_SOURCE = 'risk_data_source',
    FORMAT = 'PARQUET'
) AS r;

-- base_lending
CREATE VIEW raw_ext.base_lending AS
SELECT * FROM OPENROWSET(
    BULK 'raw/cic/base_lending.parquet',
    DATA_SOURCE = 'risk_data_source',
    FORMAT = 'PARQUET'
) AS r;

-- testing
SELECT TOP 5 * FROM raw_ext.base_customer;