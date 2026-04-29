/*
  Relationship : customer - activity event
  Source       : base_activity (contains both customer_number and event_id)
*/

{{
  config(
    materialized = 'incremental',
    unique_key   = 'lnk_customer_activity_hk'
  )
}}

with source as (

    select
        customer_number,
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
        customer_number,
        event_id,
        record_source,
        min(load_ts) as load_ts
    from source
    group by customer_number, event_id, record_source

),

final as (

    select
        {{ generate_hash_key(['customer_number', 'event_id']) }}    as lnk_customer_activity_hk,
        {{ generate_hash_key(['customer_number']) }}                 as customer_hk,
        {{ generate_hash_key(['event_id']) }}                       as activity_hk,
        record_source,
        load_ts
    from deduped

    {% if is_incremental() %}
        where {{ generate_hash_key(['customer_number', 'event_id']) }} not in (
            select lnk_customer_activity_hk from {{ this }}
        )
    {% endif %}

)

select * from final
