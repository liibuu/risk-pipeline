/*
  dim_currency
  -------------
  Layer  : mart / Kimball dimension
  Grain  : one row per currency code
  Source : sat_transaction_details

  Note: VND is the base currency - null currency in source = VND.
*/

with source as (

    select distinct
        coalesce(currency, 'VND')   as currency_code

    from {{ ref('sat_transaction_details') }}

),

final as (

    select
        {{ generate_hash_key(['currency_code']) }}  as currency_sk,
        currency_code,
        case
            when currency_code = 'VND' then 'Vietnamese Dong'
            when currency_code = 'USD' then 'US Dollar'
            when currency_code = 'EUR' then 'Euro'
            when currency_code = 'GBP' then 'British Pound'
            else 'Other'
        end                                         as currency_name,
        case
            when currency_code = 'VND' then 1
            else 0
        end                                         as is_domestic

    from source

)

select * from final