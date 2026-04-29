/*
  Relationship : customer - deposit account
  Source       : base_deposit (contains both customer_number and account_id)
*/

{{
  config(
    materialized = 'incremental',
    unique_key   = 'lnk_customer_account_hk'
  )
}}

with source as (

    select
        customer_number,
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
        customer_number,
        account_id,
        record_source,
        min(load_ts) as load_ts
    from source
    group by customer_number, account_id, record_source

),

final as (

    select
        {{ generate_hash_key(['customer_number', 'account_id']) }}  as lnk_customer_account_hk,
        {{ generate_hash_key(['customer_number']) }}                 as customer_hk,
        {{ generate_hash_key(['account_id']) }}                     as account_hk,
        record_source,
        load_ts
    from deduped

    {% if is_incremental() %}
        where {{ generate_hash_key(['customer_number', 'account_id']) }} not in (
            select lnk_customer_account_hk from {{ this }}
        )
    {% endif %}

)

select * from final
