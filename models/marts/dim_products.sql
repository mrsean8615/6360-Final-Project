select
    product_id as product_key,
    product_id,
    product_type,
    product_name,
    price

from {{ ref("stg_products") }}
