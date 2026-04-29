/*
  Parent hub : hub_customer
  Source     : base_customer

  Cleaning applied:
    1. client_sex  - normalise M/Male/male/1 → 'M', F/Female/female/2 → 'F', else 'U'
    2. date_of_birth - 5 formats observed in source data:
         a. '1996-01-01 00:00:00'  → standard datetime string, extract date part
         b. '07-06-1984'           → MM-DD-YYYY
         c. '09-25-1997'           → MM-DD-YYYY (same as above)
         d. '11/01/2001'           → MM/DD/YYYY
         e. '19831125'             → YYYYMMDD compact
         f. '27-08-1991'           → DD-MM-YYYY (day > 12 distinguishes from MM-DD-YYYY)
    3. Deduplication - dirty injection added ~2% duplicate rows;
       ROW_NUMBER keeps earliest load_ts per customer
*/

{{
  config(
    materialized = 'incremental',
    unique_key   = ['customer_hk', 'load_ts']
  )
}}

with source as (

    select * from {{ ref('base_customer') }}

    {% if is_incremental() %}
        where load_ts > (select max(load_ts) from {{ this }})
    {% endif %}

),

sex_cleaned as (

    select
        *,
        case
            when client_sex in ('M', 'male', 'Male')       then 'M'
            when client_sex in ('F', 'Female', 'female')   then 'F'
            when client_sex = '1'                          then 'M'
            when client_sex = '2'                          then 'F'
            else 'U'
        end as client_sex_clean

    from source

),

dob_cleaned as (

    select
        *,
        case
            -- format a: '1996-01-01 00:00:00' - datetime string
            when date_of_birth like '____-__-__ %'
                then try_cast(left(date_of_birth, 10) as date)

            -- format e: '19831125' - compact YYYYMMDD (8 digits, no separators)
            when date_of_birth like '________' and date_of_birth not like '%-%' and date_of_birth not like '%/%'
                then try_cast(
                    left(date_of_birth, 4) + '-' +
                    substring(date_of_birth, 5, 2) + '-' +
                    right(date_of_birth, 2)
                as date)

            -- format d: '11/01/2001' - MM/DD/YYYY
            when date_of_birth like '__/__/____'
                then try_cast(
                    right(date_of_birth, 4) + '-' +
                    left(date_of_birth, 2) + '-' +
                    substring(date_of_birth, 4, 2)
                as date)

            -- format f: '27-08-1991' - DD-MM-YYYY (day part > 12, unambiguous)
            when date_of_birth like '__-__-____'
                and try_cast(left(date_of_birth, 2) as int) > 12
                then try_cast(
                    right(date_of_birth, 4) + '-' +
                    substring(date_of_birth, 4, 2) + '-' +
                    left(date_of_birth, 2)
                as date)

            -- format b/c: '07-06-1984' or '09-25-1997' - MM-DD-YYYY
            -- (month <= 12, day could be > 12 making it unambiguous as MM-DD)
            when date_of_birth like '__-__-____'
                then try_cast(
                    right(date_of_birth, 4) + '-' +
                    left(date_of_birth, 2) + '-' +
                    substring(date_of_birth, 4, 2)
                as date)

            else null
        end as date_of_birth_clean

    from sex_cleaned

),

deduped as (

    select
        *,
        row_number() over (
            partition by customer_number
            order by load_ts asc
        ) as row_num

    from dob_cleaned

),

with_dv_keys as (

    select
        {{ generate_hash_key(['customer_number']) }}    as customer_hk,

        {{ generate_hash_diff([
            'client_sex_clean',
            'date_of_birth_clean',
            'legal_id',
            'client_create_date',
            'ib_register_date',
            'eb_register_channel',
            'sms',
            'verify_method',
            'staff_vib'
        ]) }}                                           as hash_diff,

        -- cleaned attributes
        client_sex_clean                                as client_sex,
        date_of_birth_clean                             as date_of_birth,

        -- pass-through attributes
        legal_id,
        client_create_date,
        ib_register_date,
        eb_register_channel,
        sms,
        verify_method,
        staff_vib,

        record_source,
        load_ts

    from deduped
    where row_num = 1

),

final as (

    select * from with_dv_keys

    {% if is_incremental() %}
        where not exists (
            select 1 from {{ this }} t
            where t.customer_hk = with_dv_keys.customer_hk
            and   t.hash_diff   = with_dv_keys.hash_diff
        )
    {% endif %}

)

select * from final
