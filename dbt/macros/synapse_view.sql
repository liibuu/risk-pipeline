{% materialization view, adapter='synapse' -%}

  {%- set target_relation = this.incorporate(type='view') -%}

  {% call statement('main') -%}
    EXEC('
      IF OBJECT_ID(''{{ this.schema }}.{{ this.identifier }}'', ''V'') IS NOT NULL
          DROP VIEW {{ this.schema }}.{{ this.identifier }};
    ');
  {%- endcall %}

  {% call statement('main') -%}
    {{ get_create_view_as_sql(target_relation, sql) }}
  {%- endcall %}

  {{ return({'relations': [target_relation]}) }}

{%- endmaterialization %}