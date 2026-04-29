/*
  Source : customerprofile / base_deposit.parquet
  Layer  : raw (view)
*/

with source as (

    select * from {{ source('customerprofile', 'base_deposit') }}

),

base as (

    select
        cast(ACCOUNT_ID      as varchar(50))        as account_id,
        cast(CUSTOMER_NUMBER as varchar(50))        as customer_number,
        try_cast(MONTH       as date)               as snapshot_month,
        cast(ACCOUNT_TYPE    as varchar(10))        as account_type,        -- CA or TD
        try_cast(BALANCE     as decimal(18,2))      as balance,
        try_cast(OPEN_DATE   as date)               as open_date,
        try_cast(CLOSE_DATE  as date)               as close_date,          -- nullable: open accounts have no close date

        -- Data Vault metadata
        'customerprofile'                          as record_source,
        cast(getdate() as datetime2)                as load_ts

    from source

)

select * from base