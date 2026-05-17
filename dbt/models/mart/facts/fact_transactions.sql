/*
  Layer  : mart / Kimball fact
  Grain  : one row per financial transaction
  Source : hub_transaction + sat_transaction_details + lnk_customer_transaction

  Measures : trans_amount
  Flags    : is_amount_suspect, is_lv_mismatch, is_timestamp_null
*/

with txn_hub as (

    select transaction_hk, txn_id
    from {{ ref('hub_transaction') }}

),

txn_sat as (

    select
        transaction_hk,
        trans_lv1,
        trans_lv2,
        trans_amount,
        is_amount_suspect,
        trans_timestamp,
        is_timestamp_null,
        is_lv_mismatch,
        currency,
        fin_inst_id,
        fin_inst_name
    from {{ ref('sat_transaction_details') }}

),

lnk as (

    select transaction_hk, customer_hk
    from {{ ref('lnk_customer_transaction') }}

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

dim_currency as (
    select currency_sk, currency_code
    from {{ ref('dim_currency') }}
),

dim_fin_inst as (
    select fin_inst_sk, fin_inst_id
    from {{ ref('dim_financial_institution') }}
),

final as (

    select
        -- surrogate key
        {{ generate_hash_key(['t.txn_id']) }}                           as fact_txn_sk,

        -- degenerate dimension (natural key kept on fact)
        t.txn_id,

        -- foreign keys
        dc.dim_customer_sk                                              as customer_sk,
        hc.customer_number                                              as customer_id,
        cast(format(cast(s.trans_timestamp as date), 'yyyyMMdd') as int) as date_id,
        dc2.currency_sk                                                 as currency_sk,
        dfi.fin_inst_sk                                                 as fin_inst_sk,    

        -- measures
        s.trans_amount,

        -- descriptive attributes (degenerate dimensions)
        s.trans_lv1                                                     as transaction_category,
        s.trans_lv2                                                     as transaction_subcategory,
        s.trans_timestamp,
        datepart(hour, s.trans_timestamp)                               as trans_hour,

        -- data quality flags
        s.is_amount_suspect,
        s.is_lv_mismatch,
        s.is_timestamp_null

    from txn_hub t
    inner join txn_sat s        on t.transaction_hk = s.transaction_hk
    left join  lnk l            on t.transaction_hk = l.transaction_hk
    left join  hub_cust hc      on l.customer_hk    = hc.customer_hk
    left join  dim_cust dc      on hc.customer_number = dc.customer_id
    left join dim_currency dc2  on coalesce(s.currency, 'VND') = dc2.currency_code
    left join dim_fin_inst dfi  on s.fin_inst_id = dfi.fin_inst_id

    -- exclude dirty non-positive amounts
    where s.trans_amount > 0 or s.trans_amount is null

)

select * from final
