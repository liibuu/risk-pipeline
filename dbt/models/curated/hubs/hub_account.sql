/*
  Business key : account_id
  Source       : base_deposit (only source containing account_id)
*/

{{
  config(
    materialized = 'incremental',
    unique_key   = 'account_hk'
  )
}}

with source as (

    select
        account_id,
        record_source,
        load_ts
    from {{ ref('base_deposit') }}

    {% if is_incremental() %}
        where load_ts > (select max(load_ts) from {{ this }})
    {% endif %}

),

deduped as (

    select
        account_id,
        record_source,
        min(load_ts) as load_ts
    from source
    group by account_id, record_source

),

final as (

    select
        {{ generate_hash_key(['account_id']) }}     as account_hk,
        account_id,
        record_source,
        load_ts
    from deduped

    {% if is_incremental() %}
        where {{ generate_hash_key(['account_id']) }} not in (
            select account_hk from {{ this }}
        )
    {% endif %}

)

select * from final
