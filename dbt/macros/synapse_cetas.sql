{% macro create_table_as(temporary, relation, sql) %}

  {%- set location -%}
    {{ env_var('ADLS_BASE_URL') }}/{{ relation.schema }}/{{ relation.name }}/
  {%- endset -%}

  CREATE EXTERNAL TABLE {{ relation }}
  WITH (
    LOCATION     = '{{ location }}',
    DATA_SOURCE  = {{ env_var('ADLS_DATA_SOURCE') }},
    FILE_FORMAT  = parquet_format
  )
  AS {{ sql }}

{% endmacro %}