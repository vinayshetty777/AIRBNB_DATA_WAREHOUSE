{{ config(materialized='incremental', unique_key='host_id') 
    }}

select host_id,
        replace(trim(host_name), ' ', '_') as host_name,
        host_since,
        is_superhost,
        response_rate,
        case 
            when response_rate < 60 then 'low'
            when response_rate >60 and response_rate <75 then 'average'
            else 'high'
        end as response_category,
        created_at as hosts_created_date
         from {{ref('bronze_hosts')}}