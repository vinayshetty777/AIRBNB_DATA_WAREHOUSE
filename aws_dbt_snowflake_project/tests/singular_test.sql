{{ config(severity='warn') }}

-- Test 1: total price should never be negative
select
    'total_price_not_negative' as test_name,
    booking_id,
    total_price as failing_value
from {{ ref('silver_bookings') }}
where total_price < 0

union all

-- Test 2: nights booked should be at least 1
select
    'nights_booked_at_least_one' as test_name,
    booking_id,
    nights_booked as failing_value
from {{ ref('silver_bookings') }}
where nights_booked < 1
