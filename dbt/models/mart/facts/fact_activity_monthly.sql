/*
  Layer  : mart / Kimball fact
  Grain  : one row per customer per month
  Source : hub_activity + sat_activity_details + lnk_customer_activity

  Measures:
    - total_events           : all activity events that month
    - active_days            : distinct days with any activity
    - transfer_vib_count     : count of TRANSFER_VIB_ACCOUNT events
    - first_activity_date    : earliest event in the month
    - last_activity_date     : latest event in the month
    - peak_weekday           : weekday name with highest activity count
    - peak_weekday_count     : number of events on that peak weekday
*/

with activity as (

    select
        a.activity_hk,
        s.activity_name,
        s.activity_timestamp,
        cast(s.activity_timestamp as date)                          as activity_date,
        format(cast(s.activity_timestamp as date), 'yyyy-MM')       as activity_month,
        datepart(weekday, cast(s.activity_timestamp as date))       as weekday_num,
        format(cast(s.activity_timestamp as date), 'dddd')          as weekday_name

    from {{ ref('hub_activity') }} a
    inner join {{ ref('sat_activity_details') }} s
        on a.activity_hk = s.activity_hk

    -- exclude rows with null timestamps
    where s.activity_timestamp is not null
        and s.is_activity_name_null = 0

),

lnk as (

    select activity_hk, customer_hk
    from {{ ref('lnk_customer_activity') }}

),

hub_cust as (

    select customer_hk, customer_number
    from {{ ref('hub_customer') }}

),

-- join customer info
with_customer as (

    select
        hc.customer_number,
        a.activity_name,
        a.activity_date,
        a.activity_month,
        a.weekday_num,
        a.weekday_name

    from activity a
    inner join lnk l        on a.activity_hk  = l.activity_hk
    inner join hub_cust hc  on l.customer_hk  = hc.customer_hk

),

-- weekday activity counts per customer per month
weekday_counts as (

    select
        customer_number,
        activity_month,
        weekday_name,
        weekday_num,
        count(*) as weekday_event_count,
        row_number() over (
            partition by customer_number, activity_month
            order by count(*) desc, weekday_num asc
        ) as rn

    from with_customer
    group by customer_number, activity_month, weekday_name, weekday_num

),

peak_weekday as (

    select
        customer_number,
        activity_month,
        weekday_name    as peak_weekday,
        weekday_event_count as peak_weekday_count

    from weekday_counts
    where rn = 1

),

-- main aggregation
aggregated as (

    select
        customer_number,
        activity_month,

        count(*)                                                    as total_events,
        count(distinct activity_date)                               as active_days,
        min(activity_date)                                          as first_activity_date,
        max(activity_date)                                          as last_activity_date,

        -- hardcoded TRANSFER_VIB_ACCOUNT count
        sum(case when activity_name = 'TRANSFER_VIB_ACCOUNT' then 1 else 0 end)
                                                                    as transfer_vib_count

    from with_customer
    group by customer_number, activity_month

),

dim_cust as (

    select dim_customer_sk, customer_id
    from {{ ref('dim_customer') }}
    where current_flag = 1

),

final as (

    select
        {{ generate_hash_key(['a.customer_number', 'a.activity_month']) }}  as fact_activity_monthly_sk,

        a.customer_number                                           as customer_id,
        dc.dim_customer_sk                                          as customer_sk,
        cast(format(cast(a.activity_month + '-01' as date), 'yyyyMMdd') as int)
                                                                    as date_id,
        a.activity_month,

        -- measures
        a.total_events,
        a.active_days,
        a.first_activity_date,
        a.last_activity_date,
        a.transfer_vib_count,

        -- peak weekday
        p.peak_weekday,
        p.peak_weekday_count,

        -- derived
        case
            when a.active_days > 0
            then cast(a.total_events as float) / a.active_days
            else 0
        end                                                         as avg_events_per_active_day

    from aggregated a
    left join peak_weekday p    on a.customer_number = p.customer_number
                                and a.activity_month  = p.activity_month
    left join dim_cust dc       on a.customer_number  = dc.customer_id

)

select * from final