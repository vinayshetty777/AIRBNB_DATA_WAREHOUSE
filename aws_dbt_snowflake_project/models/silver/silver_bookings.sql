{{ config(materialized='incremental',
        unique_key='booking_id') 
}}


select 
booking_id,
booking_date,
listing_id,
nights_booked,
{{multiply('nights_booked','booking_amount',2)}} as total_price,
cleaning_fee,
service_fee,
booking_status,
created_at
from {{ref('bronze_bookings')}}