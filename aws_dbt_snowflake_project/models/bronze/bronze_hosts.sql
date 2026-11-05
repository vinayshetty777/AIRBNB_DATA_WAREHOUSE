{{ config(materialized='incremental') }}


select * from {{source('staging', 'hosts')}}

{% if is_incremental() %}
where 
CREATED_AT > (SELECT coalesce(MAX(CREATED_AT), '1900-01-01') FROM {{ this }})
{% endif %}
 