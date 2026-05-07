/*
  fact_account_snapshot
  ----------------------
  Layer  : mart / Kimball fact (periodic snapshot)
  Grain  : one row per account per snapshot month
  Source : hub_account + sat_account_details + lnk_customer_account

  This is a periodic snapshot fact - balance is a semi-additive measure:
    - Can be averaged across time (avg monthly balance)
    - Can be summed across accounts within a month
    - Should NOT be summed across months (double counting)
*/

with hub as (

    select account_hk, account_id
    from {{ ref('hub_account') }}

),

sat as (

    select
        account_hk,
        account_type,
        balance,
        is_balance_suspect,
        open_date,
        close_date,
        is_open,
        snapshot_month
    from {{ ref('sat_account_details') }}

),

lnk as (

    select account_hk, customer_hk
    from {{ ref('lnk_customer_account') }}

),

hub_cust as (

    select customer_hk, customer_number
    from {{ ref('hub_customer') }}

),

dim_cust as (

    select dim_customer_sk, customer_id
    from {{ ref('dim_customer') }}
    where current_flag = 1

),

final as (

    select
        {{ generate_hash_key(['h.account_id', 's.snapshot_month']) }}  as fact_account_snapshot_sk,

        h.account_id,
        hc.customer_number                                              as customer_id,
        dc.dim_customer_sk                                              as customer_sk,
        cast(format(s.snapshot_month, 'yyyyMMdd') as int)              as date_id,
        s.snapshot_month,

        -- account attributes (degenerate dimensions)
        s.account_type,
        s.open_date,
        s.close_date,
        s.is_open,

        -- measures
        s.balance,
        s.is_balance_suspect,

        -- derived
        case
            when s.account_type = 'CURRENT'      then s.balance
            else null
        end                                                             as current_account_balance,

        case
            when s.account_type = 'TERM_DEPOSIT' then s.balance
            else null
        end                                                             as term_deposit_balance

    from hub h
    inner join sat s        on h.account_hk   = s.account_hk
    left join  lnk l        on h.account_hk   = l.account_hk
    left join  hub_cust hc  on l.customer_hk  = hc.customer_hk
    left join  dim_cust dc  on hc.customer_number = dc.customer_id

)

select * from final