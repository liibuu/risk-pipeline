/*
  Business key : loan_id
  Source       : base_lending (CIC source)
*/

{{
  config(
    materialized = 'incremental',
    unique_key   = 'loan_hk'
  )
}}

with source as (

    select
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
        loan_id,
        record_source,
        min(load_ts) as load_ts
    from source
    group by loan_id, record_source

),

final as (

    select
        {{ generate_hash_key(['loan_id']) }}     as loan_hk,
        loan_id,
        record_source,
        load_ts
    from deduped

    {% if is_incremental() %}
        where {{ generate_hash_key(['loan_id']) }} not in (
            select loan_hk from {{ this }}
        )
    {% endif %}

)

select * from final
