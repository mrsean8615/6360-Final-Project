with events as (

    select
        d_campaign.campaign_key,
        d_customer.customer_key,
        d_email.email_key,
        d_date.date_key,
        event_timestamp,
        event_type

    from {{ ref("stg_marketing_emails") }} as me
        inner join {{ ref("dim_campaigns") }} as d_campaign
            on me.campaign_id = d_campaign.campaign_key
        inner join {{ ref("dim_customers") }} as d_customer
            on {{ dbt_utils.generate_surrogate_key([
                'me.subscriber_first_name',
                'me.subscriber_last_name'
            ]) }} = d_customer.customer_key
        inner join {{ ref("dim_emails") }} as d_email
            on me.email_id = d_email.email_key
        inner join {{ ref("dim_dates") }} as d_date
            on me.event_date = d_date.date_key

)

select
    {{ dbt_utils.generate_surrogate_key([
        'campaign_key',
        'customer_key',
        'email_key',
        'date_key',
        'event_timestamp',
        'event_type'
    ]) }} as email_event_key,
    *

from events
