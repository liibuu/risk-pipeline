/*
  Relationship : customer - card
  Source       : base_card (contains both customer_number and card_id)
*/

{{
  config(
    materialized = 'incremental',
    unique_key   = 'lnk_customer_card_hk'
  )
}}

with source as (

    select
        customer_number,
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
        customer_number,
        card_id,
        record_source,
        min(load_ts) as load_ts
    from source
    group by customer_number, card_id, record_source

),

final as (

    select
        {{ generate_hash_key(['customer_number', 'card_id']) }}     as lnk_customer_card_hk,
        {{ generate_hash_key(['customer_number']) }}                 as customer_hk,
        {{ generate_hash_key(['card_id']) }}                        as card_hk,
        record_source,
        load_ts
    from deduped

    {% if is_incremental() %}
        where {{ generate_hash_key(['customer_number', 'card_id']) }} not in (
            select lnk_customer_card_hk from {{ this }}
        )
    {% endif %}

)

select * from final
