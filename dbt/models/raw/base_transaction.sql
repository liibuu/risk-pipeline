/*
  Source : onlinebanking / base_transaction.parquet
  Layer  : raw (view)
*/

with source as (

    select * from {{ source('onlinebanking', 'base_transaction') }}

),

base as (

    select
        cast(TXN_ID          as varchar(50))        as txn_id,
        cast(CUSTOMER_NUMBER as varchar(50))        as customer_number,
        cast(TRANS_LV1       as varchar(100))       as trans_lv1,
        cast(TRANS_LV2       as varchar(100))       as trans_lv2,
        try_cast(TRANS_AMOUNT as decimal(18,2))     as trans_amount,
        cast(TRANS_TIMESTAMP as varchar(30))        as trans_timestamp,     -- nullable: ~0.5% nulls; parsed in satellite

        -- Data Vault metadata
        'ONLINEBANKING'                             as record_source,
        cast(getdate() as datetime2)                as load_ts

    from source

)

select * from base
