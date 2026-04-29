/*
  Relationship : customer - loan
  Source       : base_lending (contains both customer_number and loan_id)
*/

{{
  config(
    materialized = 'incremental',
    unique_key   = 'lnk_customer_loan_hk'
  )
}}

with source as (

    select
        customer_number,
        loan_id,
        record_source,
        load_ts
    from {{ ref('base_lending') }}

    {% if is_incremental() %}
        where load_ts > (select max(load_ts) from {{ this }})
    {% endif %}

),

deduped as (

    select
        customer_number,
        loan_id,
        record_source,
        min(load_ts) as load_ts
    from source
    group by customer_number, loan_id, record_source

),

final as (

    select
        {{ generate_hash_key(['customer_number', 'loan_id']) }}     as lnk_customer_loan_hk,
        {{ generate_hash_key(['customer_number']) }}                 as customer_hk,
        {{ generate_hash_key(['loan_id']) }}                        as loan_hk,
        record_source,
        load_ts
    from deduped

    {% if is_incremental() %}
        where {{ generate_hash_key(['customer_number', 'loan_id']) }} not in (
            select lnk_customer_loan_hk from {{ this }}
        )
    {% endif %}

)

select * from final
