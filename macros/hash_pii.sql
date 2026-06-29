{% macro hash_pii(column_name) %}
    TO_HEX(SHA256(CAST({{ column_name }} AS STRING)))
{% endmacro %}