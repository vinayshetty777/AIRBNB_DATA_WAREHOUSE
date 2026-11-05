{%- macro multiply(x, y,presision) -%}
round({{x}}*{{y}},{{presision}})
{%- endmacro -%}