/*
  Parent hub : hub_account
  Source     : base_deposit

  Cleaning applied:
    1. balance   - zero/negative balances on active accounts flagged
    2. close_date - null means account is still open (legitimate, not dirty)
    3. account_type - only two values observed (CURRENT, TERM_DEPOSIT), no cleaning needed
*/

{{
  config(
    materialized = 'incremental',
    unique_key   = ['account_hk', 'load_ts']
  )
}}

with source as (

    select * from {{ ref('base_deposit') }}

    {% if is_incremental() %}
        where load_ts > (select max(load_ts) from {{ this }})
    {% endif %}

),

cleaned as (

    select
        account_id,
        customer_number,
        snapshot_month,
        account_type,
        open_date,
        close_date,

        -- flag suspicious balances but keep them - analysts decide
        balance,
        case
            when balance <= 0 then 1
            else 0
        end                     as is_balance_suspect,

        -- derived: is the account currently open?
        case
            when close_date is null then 1
            else 0
        end                     as is_open,

        record_source,
        load_ts

    from source

),

with_dv_keys as (

    select
        {{ generate_hash_key(['account_id']) }}         as account_hk,

        {{ generate_hash_diff([
            'account_type',
            'balance',
            'open_date',
            'close_date',
            'snapshot_month'
        ]) }}                                           as hash_diff,

        balance,
        is_balance_suspect,
        account_type,
        snapshot_month,
        open_date,
        close_date,
        is_open,
        record_source,
        load_ts

    from cleaned

),

final as (

    select * from with_dv_keys

    {% if is_incremental() %}
        where not exists (
            select 1 from {{ this }} t
            where t.account_hk = with_dv_keys.account_hk
            and   t.hash_diff  = with_dv_keys.hash_diff
        )
    {% endif %}

)

select * from final
