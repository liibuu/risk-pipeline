/*
  Business key : card_id
  Source       : base_card (CIC source)
*/

{{
  config(
    materialized = 'incremental',
    unique_key   = 'card_hk'
  )
}}

with source as (

    select
        card_id,
        record_source,
        load_ts
    from {{ ref('base_card') }}

    {% if is_incremental() %}
        where load_ts > (select max(load_ts) from {{ this }})
    {% endif %}

),

deduped as (

    select
        card_id,
        record_source,
        min(load_ts) as load_ts
    from source
    group by card_id, record_source

),

final as (

    select
        {{ generate_hash_key(['card_id']) }}     as card_hk,
        card_id,
        record_source,
        load_ts
    from deduped

    {% if is_incremental() %}
        where {{ generate_hash_key(['card_id']) }} not in (
            select card_hk from {{ this }}
        )
    {% endif %}

)

select * from final
