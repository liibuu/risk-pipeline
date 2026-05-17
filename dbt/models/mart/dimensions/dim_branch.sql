/*
  dim_branch
  -----------
  Layer  : mart / Kimball dimension
  Grain  : one row per branch
  Source : sat_card_details + sat_loan_details (unioned)

  Both cards and loans carry branch attributes - union gives
  the full branch population since not all branches issue both.
*/

with from_cards as (

    select distinct branch_code, branch_name
    from {{ ref('sat_card_details') }}
    where branch_code is not null

),

from_loans as (

    select distinct branch_code, branch_name
    from {{ ref('sat_loan_details') }}
    where branch_code is not null

),

unioned as (

    select branch_code, branch_name from from_cards
    union
    select branch_code, branch_name from from_loans

),

final as (

    select
        {{ generate_hash_key(['branch_code']) }}    as branch_sk,
        branch_code,
        branch_name

    from unioned

)

select * from final