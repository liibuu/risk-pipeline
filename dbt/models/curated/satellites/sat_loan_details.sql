/*
  Parent hub : hub_loan
  Source     : base_lending

  Cleaning applied:
    1. loan_amount     - 6,533 nulls kept as null (legitimate missing);
                         3,169 negatives nullified (impossible value)
    2. disbursement_date - 3,164 future dates (post-2025) nullified (data error)
    3. payoff_date     - null means loan not yet repaid (legitimate)
*/

{{
  config(
    materialized = 'incremental',
    unique_key   = ['loan_hk', 'load_ts']
  )
}}

with source as (

    select * from {{ ref('base_lending') }}

    {% if is_incremental() %}
        where load_ts > (select max(load_ts) from {{ this }})
    {% endif %}

),

cleaned as (

    select
        loan_id,
        customer_number,
        loan_type,
        payoff_date,

        -- nullify negative loan amounts
        case
            when loan_amount < 0 then null
            else loan_amount
        end                         as loan_amount,

        -- flag for auditing
        case
            when loan_amount is null    then 'NULL_SOURCE'
            when loan_amount < 0        then 'NEGATIVE'
            else 'VALID'
        end                         as loan_amount_flag,

        -- nullify future disbursement dates
        case
            when disbursement_date > cast(getdate() as date) then null
            else disbursement_date
        end                         as disbursement_date,

        case
            when disbursement_date > cast(getdate() as date) then 1
            else 0
        end                         as is_disbursement_date_suspect,

        record_source,
        load_ts

    from source

),

with_dv_keys as (

    select
        {{ generate_hash_key(['loan_id']) }}             as loan_hk,

        {{ generate_hash_diff([
            'loan_type',
            'loan_amount',
            'disbursement_date',
            'payoff_date'
        ]) }}                                           as hash_diff,

        loan_type,
        loan_amount,
        loan_amount_flag,
        disbursement_date,
        is_disbursement_date_suspect,
        payoff_date,
        record_source,
        load_ts

    from cleaned

),

final as (

    select * from with_dv_keys

    {% if is_incremental() %}
        where not exists (
            select 1 from {{ this }} t
            where t.loan_hk   = with_dv_keys.loan_hk
            and   t.hash_diff = with_dv_keys.hash_diff
        )
    {% endif %}

)

select * from final
