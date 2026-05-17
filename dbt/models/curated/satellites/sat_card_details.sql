/*
  Parent hub : hub_card
  Source     : base_card

  Cleaning applied:
    1. status - 9 variants observed: ACTIVE/active/Active, EXPIRED/Expired/expired,
                BLOCKED/Blocked/blocked → normalised to upper case
*/

{{
  config(
    materialized = 'incremental',
    unique_key   = ['card_hk', 'load_ts']
  )
}}

with source as (

    select * from {{ ref('base_card') }}

    {% if is_incremental() %}
        where load_ts > (select max(load_ts) from {{ this }})
    {% endif %}

),

cleaned as (

    select
        card_id,
        customer_number,
        card_type,
        card_subtype,                   -- added dims, null for debit cards
        branch_code,                    -- added dims, null for debit cards
        branch_name,                    -- added dims, null for debit cards
        issue_date,
        upper(status)   as status,      -- ACTIVE / EXPIRED / BLOCKED
        record_source,
        load_ts

    from source

),

with_dv_keys as (

    select
        {{ generate_hash_key(['card_id']) }}             as card_hk,

        {{ generate_hash_diff([
            'card_type',
            'card_subtype',   -- add
            'branch_code',    -- add
            'issue_date',
            'status'
        ]) }}                                           as hash_diff,

        card_type,
        card_subtype,                  
        branch_code,                   
        branch_name,                
        issue_date,
        status,
        record_source,
        load_ts

    from cleaned

),

final as (

    select * from with_dv_keys

    {% if is_incremental() %}
        where not exists (
            select 1 from {{ this }} t
            where t.card_hk   = with_dv_keys.card_hk
            and   t.hash_diff = with_dv_keys.hash_diff
        )
    {% endif %}

)

select * from final
