/*
  dim_customer
  -------------
  Layer  : mart / Kimball dimension
  Grain  : one row per customer per version (SCD Type 2)
  Source : hub_customer + sat_customer_details

  SCD Type 2 logic:
    - Each attribute change in sat_customer_details creates a new version
    - valid_from / valid_to window tracks when each version was active
    - current_flag = 1 identifies the latest version
    - Analysts filter WHERE current_flag = 1 for current state queries
*/

with hub as (

    select
        customer_hk,
        customer_number
    from {{ ref('hub_customer') }}

),

sat as (

    select
        customer_hk,
        client_sex,
        date_of_birth,
        legal_id,
        client_create_date,
        ib_register_date,
        eb_register_channel,
        sms,
        verify_method,
        staff_vib,
        load_ts,
        lead(load_ts) over (
            partition by customer_hk
            order by load_ts asc
        ) as next_load_ts

    from {{ ref('sat_customer_details') }}

),

joined as (

    select
        -- surrogate key: unique per customer per version
        {{ generate_hash_key(['h.customer_number', 's.load_ts']) }}     as dim_customer_sk,

        h.customer_number                                               as customer_id,
        s.client_sex,
        s.date_of_birth,
        case
            when s.date_of_birth is not null
            then datediff(year, s.date_of_birth, getdate())
            else null
        end                                                             as age,
        s.legal_id,
        s.client_create_date,
        s.ib_register_date,
        s.eb_register_channel,
        s.sms,
        s.verify_method,
        s.staff_vib,

        -- SCD2 validity window
        s.load_ts                                                       as valid_from,
        coalesce(s.next_load_ts, cast('9999-12-31' as date))           as valid_to,
        case
            when s.next_load_ts is null then 1
            else 0
        end                                                             as current_flag

    from hub h
    inner join sat s on h.customer_hk = s.customer_hk

)

select * from joined
