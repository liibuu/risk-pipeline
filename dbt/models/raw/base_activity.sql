/*
  Source : onlinebanking / base_activity.parquet
  Layer  : raw (view)

  Note: ACTIVITY_TIMESTAMP kept as varchar - format needs inspection
  before committing to a datetime cast. Cleaned in satellite.
*/

with source as (

    select * from {{ source('onlinebanking', 'base_activity') }}

),

base as (

    select
        cast(EVENT_ID        as varchar(50))        as event_id,
        cast(CUSTOMER_NUMBER as varchar(50))        as customer_number,
        cast(ACTIVITY_NAME   as varchar(100))       as activity_name,       -- nullable: dirty data has ~2% nulls
        cast(ACTIVITY_TIMESTAMP as varchar(30))     as activity_timestamp,  -- kept as string; parsed in satellite

        -- Data Vault metadata
        'ONLINEBANKING'                             as record_source,
        cast(getdate() as datetime2)                as load_ts

    from source

)

select * from base
