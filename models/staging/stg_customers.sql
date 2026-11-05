select
    upper(customer_address) as customer_address,
    upper(customer_state) as customer_state,
    upper(customer_first_name) as customer_first_name,
    upper(customer_last_name) as customer_last_name,
    upper(customer_country) as customer_country,
    upper(customer_email) as customer_email,
    customer_id,
    customer_phone,
    upper(customer_city) as customer_city,
    customer_zip
from {{ source("transactional_db", "customer") }}
