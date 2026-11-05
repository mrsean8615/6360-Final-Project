with customers as (

    select distinct
        coalesce(me.customer_id, c.customer_id) as customer_id,
        me.subscriber_id,
        coalesce(me.subscriber_first_name, c.customer_first_name) as first_name,
        coalesce(me.subscriber_last_name, c.customer_last_name) as last_name,
        coalesce(me.subscriber_email, c.customer_email) as customer_email,
        c.customer_phone,
        c.customer_address,
        c.customer_state,
        c.customer_country,
        c.customer_city,
        c.customer_zip

    from {{ ref("stg_marketing_emails") }} as me
        full outer join {{ ref("stg_customers") }} as c
            on me.subscriber_first_name = c.customer_first_name
            and me.subscriber_last_name = c.customer_last_name

)

select
    {{ dbt_utils.generate_surrogate_key([
        'first_name',
        'last_name'
    ]) }} as customer_key,
    *

from customers
