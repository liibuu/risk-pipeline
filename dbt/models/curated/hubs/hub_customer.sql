/*
  Business key : customer_number
  Source       : base_customer (primary - customer_profile source)

  customer_number appears in all 6 base models but we anchor the hub
  to base_customer as it is the authoritative source for this entity.
*/

{{
  config(
    materialized = 'incremental',
    unique_key   = 'customer_hk'
  )
}}

with source as (

    select
        customer_number,
        record_source,
        load_ts
    from {{ ref('base_customer') }}

    {% if is_incremental() %}
        where load_ts > (select max(load_ts) from {{ this }})
    {% endif %}

),

deduped as (

    select
        customer_number,
        record_source,
        min(load_ts) as load_ts
    from source
    group by customer_number, record_source

),

final as (

    select
        {{ generate_hash_key(['customer_number']) }}     as customer_hk,
        customer_number,
        record_source,
        load_ts
    from deduped

    {% if is_incremental() %}
        where {{ generate_hash_key(['customer_number']) }} not in (
            select customer_hk from {{ this }}
        )
    {% endif %}

)

select * from final
