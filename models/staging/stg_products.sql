select
    upper(product_type) as product_type,
    product_id,
    upper(product_name) as product_name,
    price
from {{ source("transactional_db", "product") }}
