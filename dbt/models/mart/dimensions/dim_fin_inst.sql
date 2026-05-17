/*
  dim_fin_inst
  --------------------------
  Layer  : mart / Kimball dimension
  Grain  : one row per financial institution
  Source : sat_transaction_details
*/

with source as (

    select distinct
        fin_inst_id,
        fin_inst_name

    from {{ ref('sat_transaction_details') }}
    where fin_inst_id is not null

),

final as (

    select
        {{ generate_hash_key(['fin_inst_id']) }}    as fin_inst_sk,
        fin_inst_id,
        fin_inst_name

    from source

)

select * from final