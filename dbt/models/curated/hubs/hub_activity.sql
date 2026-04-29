/*
  Business key : event_id
  Source       : base_activity (onlinebanking source)
*/

{{
  config(
    materialized = 'incremental',
    unique_key   = 'activity_hk'
  )
}}

with source as (

    select
        event_id,
        record_source,
        load_ts
    from {{ ref('base_activity') }}

    {% if is_incremental() %}
        where load_ts > (select max(load_ts) from {{ this }})
    {% endif %}

),

deduped as (

    select
        event_id,
        record_source,
        min(load_ts) as load_ts
    from source
    group by event_id, record_source

),

final as (

    select
        {{ generate_hash_key(['event_id']) }}     as activity_hk,
        event_id,
        record_source,
        load_ts
    from deduped

    {% if is_incremental() %}
        where {{ generate_hash_key(['event_id']) }} not in (
            select activity_hk from {{ this }}
        )
    {% endif %}

)

select * from final
