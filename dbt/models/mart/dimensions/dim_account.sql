/*
  dim_account
  ────────────
  Layer  : mart / Kimball dimension
  Grain  : one row per account per snapshot month
  Source : hub_account + sat_account_details + lnk_customer_account

  Note: deposit accounts are snapshot-based (one record per month per account)
  so this dimension naturally tracks history via snapshot_month rather than SCD2.
  current_flag identifies the most recent snapshot per account.
*/

with hub as (

    select
        account_hk,
        account_id
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
        snapshot_month,
        load_ts,
        row_number() over (
            partition by account_hk
            order by load_ts desc
        ) as rn

    from {{ ref('sat_account_details') }}

),

lnk as (

    select
        account_hk,
        customer_hk
    from {{ ref('lnk_customer_account') }}

),

hub_cust as (

    select
        customer_hk,
        customer_number
    from {{ ref('hub_customer') }}

),

joined as (

    select
        {{ generate_hash_key(['h.account_id', 's.snapshot_month']) }}  as dim_account_sk,

        h.account_id,
        hc.customer_number                                              as customer_id,
        s.account_type,
        s.balance,
        s.is_balance_suspect,
        s.open_date,
        s.close_date,
        s.is_open,
        s.snapshot_month,
        case when s.rn = 1 then 1 else 0 end                           as current_flag

    from hub h
    inner join sat s     on h.account_hk  = s.account_hk
    left join  lnk l     on h.account_hk  = l.account_hk
    left join  hub_cust hc on l.customer_hk = hc.customer_hk

)

select * from joined
