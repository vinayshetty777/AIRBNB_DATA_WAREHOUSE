{{ config(materialized='incremental', unique_key='listing_id') 
    }}

select listing_id,host_id,
        room_type,
        city,
        country,
        accommodates,
        bedrooms,
        bathrooms,
        price_per_night,
        {{ tag('price_per_night') }} as price_category,
        created_at
 from {{ref('bronze_listings')}}