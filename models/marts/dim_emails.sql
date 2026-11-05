select distinct
    email_id as email_key,
    email_id,
    email_name

from {{ ref("stg_marketing_emails") }}
