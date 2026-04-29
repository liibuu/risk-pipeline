/*
  Parent hub : hub_activity
  Source     : base_activity

  Cleaning applied:
    1. activity_name  - ~2% nulls kept as null, flagged for analysts
    2. activity_timestamp - format consistent with transactions:
                            '2019-11-15 15:00:00.000' → cast to datetime2
*/

{{
  config(
    materialized = 'incremental',
    unique_key   = ['activity_hk', 'load_ts']
  )
}}

with source as (

    select * from {{ ref('base_activity') }}

    {% if is_incremental() %}
        where load_ts > (select max(load_ts) from {{ this }})
    {% endif %}

),

cleaned as (

    select
        event_id,
        customer_number,

        activity_name,
        case
            when activity_name is null then 1
            else 0
        end                     as is_activity_name_null,

        -- timestamp format consistent: '2019-11-15 15:00:00.000'
        try_cast(activity_timestamp as datetime2)   as activity_timestamp,

        case
            when activity_timestamp is null then 1
            else 0
        end                     as is_timestamp_null,

        record_source,
        load_ts

    from source

),

with_dv_keys as (

    select
        {{ generate_hash_key(['event_id']) }}            as activity_hk,

        {{ generate_hash_diff([
            'activity_name',
            'activity_timestamp'
        ]) }}                                           as hash_diff,

        activity_name,
        is_activity_name_null,
        activity_timestamp,
        is_timestamp_null,
        record_source,
        load_ts

    from cleaned

),

final as (

    select * from with_dv_keys

    {% if is_incremental() %}
        where not exists (
            select 1 from {{ this }} t
            where t.activity_hk = with_dv_keys.activity_hk
            and   t.hash_diff   = with_dv_keys.hash_diff
        )
    {% endif %}

)

select * from final
