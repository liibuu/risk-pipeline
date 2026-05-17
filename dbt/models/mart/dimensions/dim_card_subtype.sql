/*
  dim_card_subtype
  -----------------
  Layer  : mart / Kimball dimension
  Grain  : one row per card subtype
  Source : sat_card_details

  Only applies to CREDIT CARD type - debit cards have null subtype.
*/

with source as (

    select distinct card_subtype
    from {{ ref('sat_card_details') }}
    where card_subtype is not null

),

final as (

    select
        {{ generate_hash_key(['card_subtype']) }}   as card_subtype_sk,
        card_subtype

    from source

)

select * from final