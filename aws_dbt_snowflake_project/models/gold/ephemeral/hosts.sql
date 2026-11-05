{{
  config(
    materialized = 'ephemeral',
    )
}}

WITH hosts AS
(
    SELECT
        HOST_ID,
        HOST_NAME,
        HOST_SINCE,
        IS_SUPERHOST,
        RESPONSE_RATE,
        RESPONSE_CATEGORY,
        HOSTS_CREATED_DATE
    FROM
        {{ ref('silver_hosts') }}
)
SELECT * FROM hosts
