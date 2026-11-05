select
    campaign_id,
    order_id,
    price_after_discount,
    quantity,
    order_line_id,
    promotional_campaign,
    product_id,
    discount
from {{ source("transactional_db", "order_line") }}
