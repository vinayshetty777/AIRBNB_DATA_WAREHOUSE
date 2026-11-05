{% macro trimmer(col,node) %}
    {{col | trim | upper}}

{% endmacro %}
