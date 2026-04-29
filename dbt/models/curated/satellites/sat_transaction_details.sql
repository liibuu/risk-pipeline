/*
  Parent hub : hub_transaction
  Source     : base_transaction

  Cleaning applied:
    1. trans_amount   - 50,381 non-positive values nullified (impossible for a valid txn)
    2. trans_timestamp - ~0.5% nulls kept as null; format is consistent
                         '2019-11-15 15:00:00.000' → cast to datetime2
    3. trans_lv1/lv2  - known mismatch pattern flagged for analysts:
                         TRANSFER + LOAN_REPAYMENT is a legitimate combination,
                         but catches cross-category errors too
*/

{{
  config(
    materialized = 'incremental',
    unique_key   = ['transaction_hk', 'load_ts']
  )
}}

with source as (

    select * from {{ ref('base_transaction') }}

    {% if is_incremental() %}
        where load_ts > (select max(load_ts) from {{ this }})
    {% endif %}

),

cleaned as (

    select
        txn_id,
        customer_number,
        upper(trans_lv1)    as trans_lv1,
        upper(trans_lv2)    as trans_lv2,

        -- nullify non-positive amounts
        case
            when trans_amount <= 0 then null
            else trans_amount
        end                 as trans_amount,

        case
            when trans_amount <= 0 then 1
            else 0
        end                 as is_amount_suspect,

        -- timestamp format is consistent: '2019-11-15 15:00:00.000'
        try_cast(trans_timestamp as datetime2)  as trans_timestamp,

        -- flag null timestamps
        case
            when trans_timestamp is null then 1
            else 0
        end                 as is_timestamp_null,

        record_source,
        load_ts

    from source

),

lv_flagged as (

    select
        *,
        -- flag when lv1 category does not match lv2 subcategory
        case
            when trans_lv1 = 'PAYMENT'   and trans_lv2 like 'TRANSFER%'      then 1
            when trans_lv1 = 'TRANSFER'  and trans_lv2 like 'PAYMENT%'       then 1
            when trans_lv1 = 'WITHDRAWAL'and trans_lv2 like 'DEPOSIT%'       then 1
            else 0
        end                 as is_lv_mismatch

    from cleaned

),

with_dv_keys as (

    select
        {{ generate_hash_key(['txn_id']) }}              as transaction_hk,

        {{ generate_hash_diff([
            'trans_lv1',
            'trans_lv2',
            'trans_amount',
            'trans_timestamp'
        ]) }}                                           as hash_diff,

        trans_lv1,
        trans_lv2,
        trans_amount,
        is_amount_suspect,
        trans_timestamp,
        is_timestamp_null,
        is_lv_mismatch,
        record_source,
        load_ts

    from lv_flagged

),

final as (

    select * from with_dv_keys

    {% if is_incremental() %}
        where not exists (
            select 1 from {{ this }} t
            where t.transaction_hk = with_dv_keys.transaction_hk
            and   t.hash_diff      = with_dv_keys.hash_diff
        )
    {% endif %}

)

select * from final
