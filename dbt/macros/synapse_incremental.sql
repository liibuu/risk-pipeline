{% materialization incremental, adapter='synapse' -%}

  {%- set target_relation = this.incorporate(type='table') -%}

  {%- call statement('main') -%}

    IF EXISTS (
        SELECT 1 FROM sys.external_tables
        WHERE object_id = OBJECT_ID('{{ this.schema }}.{{ this.identifier }}')
    )
    DROP EXTERNAL TABLE {{ this }};

    CREATE EXTERNAL TABLE {{ this }}
    WITH (
        LOCATION     = '{{ this.schema }}/{{ this.identifier }}/',
        DATA_SOURCE  = {{ env_var('ADLS_DATA_SOURCE') }},
        FILE_FORMAT  = parquet_format
    )
    AS {{ sql }}

  {%- endcall -%}

  {{ return({'relations': [target_relation]}) }}

{%- endmaterialization %}