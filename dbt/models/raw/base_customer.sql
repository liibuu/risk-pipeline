/*
  Source : customerprofile / base_customer.parquet
  Layer  : raw (view)

  Casts all columns to correct types, renames to snake_case,
  adds Data Vault metadata. No cleaning - dirty values kept as-is.
*/

with source as (

    select * from {{ source('customerprofile', 'base_customer') }}

),

base as (

    select
        cast(CUSTOMER_NUMBER     as varchar(50))    as customer_number,
        cast(LEGAL_ID            as varchar(50))    as legal_id,
        cast(CLIENT_SEX          as varchar(10))    as client_sex,
        try_cast(CLIENT_CREATE_DATE as date)        as client_create_date,
        cast(DATE_OF_BIRTH       as varchar(20))    as date_of_birth,      -- kept as string; mixed formats cleaned in satellite
        try_cast(IB_REGISTER_DATE   as date)        as ib_register_date,
        cast(EB_REGISTER_CHANNEL as varchar(50))    as eb_register_channel,
        cast(SMS                 as varchar(10))    as sms,
        cast(VERIFY_METHOD       as varchar(50))    as verify_method,
        cast(STAFF_VIB           as varchar(10))    as staff_vib,

        -- Data Vault metadata
        'CUSTOMERPROFILE'                          as record_source,
        cast(getdate() as datetime2)                as load_ts

    from source

)

select * from base