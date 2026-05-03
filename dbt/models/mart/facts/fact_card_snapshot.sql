/*
  fact_card_snapshot
  ───────────────────
  Layer  : mart / Kimball fact
  Grain  : one row per card (latest snapshot)
  Source : hub_card + sat_card_details + lnk_customer_card

  Used for: portfolio exposure analysis — how many cards per customer,
  what types, active vs expired vs blocked breakdown.
*/

with card_hub as (

    select card_hk, card_id
    from {{ ref('hub_card') }}

),

card_sat as (

    -- take latest snapshot per card
    select
        card_hk,
        card_type,
        issue_date,
        status,
        load_ts,
        row_number() over (
            partition by card_hk
            order by load_ts desc
        ) as rn

    from {{ ref('sat_card_details') }}

),

lnk as (

    select card_hk, customer_hk
    from {{ ref('lnk_customer_card') }}

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
        {{ generate_hash_key(['c.card_id']) }}                          as fact_card_sk,

        c.card_id,
        dc.dim_customer_sk                                              as customer_sk,
        hc.customer_number                                              as customer_id,

        s.card_type,
        s.issue_date,
        s.status,

        -- derived flags useful for risk
        case when s.status = 'ACTIVE'  then 1 else 0 end               as is_active,
        case when s.status = 'BLOCKED' then 1 else 0 end               as is_blocked,
        case when s.status = 'EXPIRED' then 1 else 0 end               as is_expired,

        -- days since issue
        datediff(day, s.issue_date, cast(getdate() as date))           as days_since_issue

    from card_hub c
    inner join card_sat s   on c.card_hk      = s.card_hk and s.rn = 1
    left join  lnk l        on c.card_hk      = l.card_hk
    left join  hub_cust hc  on l.customer_hk  = hc.customer_hk
    left join  dim_cust dc  on hc.customer_number = dc.customer_id

)

select * from final
