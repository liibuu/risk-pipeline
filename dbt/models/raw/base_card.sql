/*
  Source : cic / base_card.parquet
  Layer  : raw (view)
*/

with source as (

    select * from {{ source('cic', 'base_card') }}

),

base as (

    select
        cast(CARD_ID         as varchar(50))        as card_id,
        cast(CUSTOMER_NUMBER as varchar(50))        as customer_number,
        cast(CARD_TYPE       as varchar(20))        as card_type,
        try_cast(ISSUE_DATE  as date)               as issue_date,
        cast(STATUS          as varchar(20))        as status,              -- mixed casing cleaned in satellite

        -- Data Vault metadata
        'CIC'                                       as record_source,
        cast(getdate() as datetime2)                as load_ts

    from source

)

select * from base
