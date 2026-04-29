/*
  Business key : txn_id
  Source       : base_transaction (onlinebanking source)
*/

{{
  config(
    materialized = 'incremental',
    unique_key   = 'transaction_hk'
  )
}}

with source as (

    select
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
        txn_id,
        record_source,
        min(load_ts) as load_ts
    from source
    group by txn_id, record_source

),

final as (

    select
        {{ generate_hash_key(['txn_id']) }}     as transaction_hk,
        txn_id,
        record_source,
        load_ts
    from deduped

    {% if is_incremental() %}
        where {{ generate_hash_key(['txn_id']) }} not in (
            select transaction_hk from {{ this }}
        )
    {% endif %}

)

select * from final
