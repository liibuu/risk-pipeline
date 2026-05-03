{% macro synapse__get_test_sql(main_sql, fail_calc, warn_if, error_if, limit) %}

    {% set test_view = 'tv_' ~ modules.datetime.datetime.now().strftime('%H%M%S%f') %}
    {% set escaped_sql = main_sql | replace("'", "''") %}

    EXEC('create view dbt_test.{{ test_view }} as {{ escaped_sql }}');

    select
        {{ fail_calc }} as failures,
        case when {{ fail_calc }} {{ warn_if }} then 'true' else 'false' end as should_warn,
        case when {{ fail_calc }} {{ error_if }} then 'true' else 'false' end as should_error
    from dbt_test.{{ test_view }};

    EXEC('drop view dbt_test.{{ test_view }}');

{% endmacro %}