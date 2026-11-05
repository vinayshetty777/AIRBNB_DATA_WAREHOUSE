{% macro tag(col) %}
    case when {{col}} < 100 then 'low'
         when {{col}} >= 100 and {{col}} < 200 then 'medium'
         else 'high' 
    end
{% endmacro %}