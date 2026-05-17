/*
  dim_date
  ---------
  Layer  : mart / Kimball dimension
  Grain  : one row per calendar date
  Source : generated - no upstream dbt model needed
  Range  : 2015-01-01 to 2030-12-31 (covers your transaction data range)
*/

with numbers as (
    select n from (
        values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)
    ) as t1(n)
),

thousands as (
    select
        t1.n + t2.n * 10 + t3.n * 100 + t4.n * 1000 as n
    from numbers t1
    cross join numbers t2
    cross join numbers t3
    cross join numbers t4
    where t1.n + t2.n * 10 + t3.n * 100 + t4.n * 1000 < 5844
),

date_spine as (
    select dateadd(day, n, cast('2015-01-01' as date)) as calendar_date
    from thousands
)

select
    cast(format(calendar_date, 'yyyyMMdd') as int)      as date_id,
    calendar_date,
    year(calendar_date)                                 as year,
    datepart(quarter, calendar_date)                    as quarter,
    month(calendar_date)                                as month,
    format(calendar_date, 'MMMM')                       as month_name,
    datepart(week, calendar_date)                       as week_of_year,
    day(calendar_date)                                  as day_of_month,
    datepart(weekday, calendar_date)                    as day_of_week,
    format(calendar_date, 'dddd')                       as day_name,
    case
        when datepart(weekday, calendar_date) in (1, 7) then 1
        else 0
    end                                                 as is_weekend,
    case
        when format(calendar_date, 'MM-dd') in (
            '01-01', '04-30', '05-01', '09-02'
        ) then 1
        else 0
    end                                                 as is_public_holiday,
    format(calendar_date, 'yyyy-MM')                    as year_month,
    datefromparts(
        year(calendar_date), month(calendar_date), 1
    )                                                   as month_start_date,
    eomonth(calendar_date)                              as month_end_date

from date_spine
