select
    campaign_id,
    campaign_discount,
    upper(campaign_name) as campaign_name
from {{ source("transactional_db", "promotional_campaign") }}
