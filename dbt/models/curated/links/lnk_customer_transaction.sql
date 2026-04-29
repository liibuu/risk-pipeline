/*
  Relationship : customer - transaction
  Source       : base_transaction (contains both customer_number and txn_id)
*/

{{
  config(
    materialized = 'incremental',
    unique_key   = 'lnk_customer_transaction_hk'
  )
}}

with source as (

    select
        customer_number,
        txn_id,
        record_source,
        load_ts
    from {{ ref('base_transaction') }}

    {% if is_incremental() %}
        where load_ts > (select max(load_ts) from {{ this }})
    {% endif %}

),

deduped as (

    select
        customer_number,
        txn_id,
        record_source,
        min(load_ts) as load_ts
    from source
    group by customer_number, txn_id, record_source

),

final as (

    select
        {{ generate_hash_key(['customer_number', 'txn_id']) }}      as lnk_customer_transaction_hk,
        {{ generate_hash_key(['customer_number']) }}                 as customer_hk,
        {{ generate_hash_key(['txn_id']) }}                         as transaction_hk,
        record_source,
        load_ts
    from deduped

    {% if is_incremental() %}
        where {{ generate_hash_key(['customer_number', 'txn_id']) }} not in (
            select lnk_customer_transaction_hk from {{ this }}
        )
    {% endif %}

)

select * from final
