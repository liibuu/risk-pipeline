/*
  Generates a Data Vault hash key (HK) from one or more business key columns.
  Uses MD5 for portability with Synapse Serverless.

  Usage:
      {{ generate_hash_key(['cif_id']) }}
      {{ generate_hash_key(['account_id', 'snapshot_month']) }}
*/

{% macro generate_hash_key(columns) %}
    convert(
        char(32),
        hashbytes(
            'MD5',
            upper(
                concat_ws('||',
                    {% for col in columns %}
                        coalesce(cast({{ col }} as varchar(255)), '^^')
                        {%- if not loop.last %},{% endif %}
                    {% endfor %}
                )
            )
        ),
        2
    )
{% endmacro %}


/*
  macros/generate_hash_diff.sql
  ------------------------------
  Generates a hash diff for Satellite change detection.
  When hash_diff changes between loads, a new Satellite record is inserted.

  Usage:
      {{ generate_hash_diff(['full_name', 'date_of_birth_raw', 'client_sex']) }}
*/

{% macro generate_hash_diff(columns) %}
    convert(
        char(32),
        hashbytes(
            'MD5',
            concat_ws('||',
                {% for col in columns %}
                    coalesce(cast({{ col }} as varchar(255)), '^^')
                    {%- if not loop.last %},{% endif %}
                {% endfor %}
            )
        ),
        2
    )
{% endmacro %}