/*
  Source : cic / base_lending.parquet
  Layer  : raw (view)
*/

with source as (

    select * from {{ source('cic', 'base_lending') }}

),

base as (

    select
        cast(LOAN_ID         as varchar(50))        as loan_id,
        cast(CUSTOMER_NUMBER as varchar(50))        as customer_number,
        try_cast(LOAN_AMOUNT as decimal(18,2))      as loan_amount,         -- nullable: ~1% nulls from dirty injection
        try_cast(DISBURSEMENT_DATE as date)         as disbursement_date,   -- ~0.5% future dates caught in satellite
        try_cast(PAYOFF_DATE       as date)         as payoff_date,         -- nullable: unpaid loans have no payoff date
        cast(LOAN_TYPE       as varchar(50))        as loan_type,

        -- Data Vault metadata
        'CIC'                                       as record_source,
        cast(getdate() as datetime2)                as load_ts

    from source

)

select * from base
