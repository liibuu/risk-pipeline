/*
  fact_loan_snapshot
  ───────────────────
  Layer  : mart / Kimball fact
  Grain  : one row per loan (latest snapshot)
  Source : hub_loan + sat_loan_details + lnk_customer_loan

  Used for: credit risk analysis — total exposure per customer,
  loan type breakdown, outstanding vs paid off loans.
*/

with loan_hub as (

    select loan_hk, loan_id
    from {{ ref('hub_loan') }}

),

loan_sat as (

    -- take latest snapshot per loan
    select
        loan_hk,
        loan_type,
        loan_amount,
        loan_amount_flag,
        disbursement_date,
        is_disbursement_date_suspect,
        payoff_date,
        load_ts,
        row_number() over (
            partition by loan_hk
            order by load_ts desc
        ) as rn

    from {{ ref('sat_loan_details') }}

),

lnk as (

    select loan_hk, customer_hk
    from {{ ref('lnk_customer_loan') }}

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
        {{ generate_hash_key(['l.loan_id']) }}                          as fact_loan_sk,

        l.loan_id,
        dc.dim_customer_sk                                              as customer_sk,
        hc.customer_number                                              as customer_id,

        s.loan_type,
        s.loan_amount,
        s.loan_amount_flag,
        s.disbursement_date,
        s.is_disbursement_date_suspect,
        s.payoff_date,

        -- derived flags useful for risk
        case
            when s.payoff_date is null then 1
            else 0
        end                                                             as is_outstanding,

        case
            when s.payoff_date is not null
            then datediff(day, s.disbursement_date, s.payoff_date)
            else null
        end                                                             as days_to_payoff,

        case
            when s.payoff_date is null and s.disbursement_date is not null
            then datediff(day, s.disbursement_date, cast(getdate() as date))
            else null
        end                                                             as days_outstanding

    from loan_hub l
    inner join loan_sat s   on l.loan_hk      = s.loan_hk and s.rn = 1
    left join  lnk lk       on l.loan_hk      = lk.loan_hk
    left join  hub_cust hc  on lk.customer_hk = hc.customer_hk
    left join  dim_cust dc  on hc.customer_number = dc.customer_id

    -- exclude loans with dirty amounts
    where s.loan_amount_flag != 'NEGATIVE' or s.loan_amount_flag is null

)

select * from final
