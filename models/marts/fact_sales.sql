with sales as (

    select
        d_date.date_key,
        d_customer.customer_key,
        d_product.product_key,
        d_campaign.campaign_key,
        ol.order_line_id,
        orders.order_id,
        orders.order_timestamp,
        ol.quantity,
        ol.discount,
        ol.price_after_discount

    from {{ ref("stg_order_lines") }} as ol
        left join {{ ref("stg_orders") }} as orders
            on ol.order_id = orders.order_id
        inner join {{ ref("dim_campaigns") }} as d_campaign
            on ol.campaign_id = d_campaign.campaign_key
        inner join {{ ref("dim_customers") }} as d_customer
            on orders.customer_id = d_customer.customer_id
        inner join {{ ref("dim_products") }} as d_product
            on ol.product_id = d_product.product_key
        inner join {{ ref("dim_dates") }} as d_date
            on orders.order_date = d_date.date_key

)

select
    {{ dbt_utils.generate_surrogate_key([
        'date_key',
        'customer_key',
        'product_key',
        'campaign_key',
        'order_line_id',
        'order_id',
        'order_timestamp',
        'quantity',
        'discount',
        'price_after_discount'
    ]) }} as sales_key,
    *

from sales
