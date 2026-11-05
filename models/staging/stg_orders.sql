select
    customer_id,
    order_id,
    order_timestamp::date as order_date,
    order_timestamp
from {{ source("transactional_db", "order") }}
