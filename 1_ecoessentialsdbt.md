# Project Deliverable 2

## Transform (dbt)

### Define Materialization

We will organize our staging models and final star schemas in separate folders. We would like to materialize all staging models as views and the star schema models as tables. We can set this in dbt_project.yml

`dbt_project.yml`

```yaml
models:
  ecoessentials:
    # Materialize staging models as views, and marts as tables
    staging:
      +materialized: view
    marts:
      +materialized: table
```

### Configure Sources

In the staging file, we will create a .yml file to tell dbt where to find our source data.

`models/staging/__sources.yml`

```yaml
version: 2

sources:
  - name: salesforce
    database: group1project
    schema: ecoessentials
    tables:
      - name: marketing_emails

  - name: transactional_db
    database: group1project
    schema: ecoessentials_transactional_db
    tables:
      - name: customer
      - name: order
        identifier: ORDER
        quoting:
          identifier: true
      - name: order_line
      - name: product
      - name: promotional_campaign
```

### Build Staging Models

The staging models apply minimal transformations and align with the tables in our sources. In our case, we cast all text data to uppercase for consistency and separate the date portion of all timestamps in order to join to our date dimension. We also rename columns to snake_case for consistency. Below is the code for our staging models:

`models/staging/stg_customers.sql`

```sql
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
```

`models/staging/stg_marketing_emails.sql`

```sql
select
    emaileventid as email_event_id,
    emailid as email_id,
    upper(emailname) as email_name,
    campaignid as campaign_id,
    upper(campaignname) as campaign_name,
    (case when customerid = 'NULL' then NULL else customerid end)::integer as customer_id,
    subscriberid as subscriber_id,
    upper(subscriberemail) as subscriber_email,
    upper(subscriberfirstname) as subscriber_first_name,
    upper(subscriberlastname) as subscriber_last_name,
    sendtimestamp::date as send_date,
    sendtimestamp as send_timestamp,
    upper(eventtype) as event_type,
    eventtimestamp::date as event_date,
    eventtimestamp as event_timestamp
from {{ source("salesforce", "marketing_emails") }}
```

`models/staging/stg_order_lines.sql`

```sql
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
```

`models/staging/stg_orders.sql`

```sql
select
    customer_id,
    order_id,
    order_timestamp::date as order_date,
    order_timestamp
from {{ source("transactional_db", "order") }}
```

`models/staging/stg_products.sql`

```sql
select
    upper(product_type) as product_type,
    product_id,
    upper(product_name) as product_name,
    price
from {{ source("transactional_db", "product") }}
```

`models/staging/stg_promotional_campaigns.sql`

```sql
select
    campaign_id,
    campaign_discount,
    upper(campaign_name) as campaign_name
from {{ source("transactional_db", "promotional_campaign") }}
```

### Build Dimensions and Facts

Now use the staging models to build the dimension and fact table. Here is the code for each of those tables:

`models/marts/dim_campaigns.sql`

```sql
select distinct
    coalesce(me.campaign_id, c.campaign_id) as campaign_key,
    coalesce(me.campaign_id, c.campaign_id) as campaign_id,
    coalesce(me.campaign_name, c.campaign_name) as campaign_name,
    c.campaign_discount

from {{ ref("stg_marketing_emails") }} as me
    full outer join {{ ref("stg_promotional_campaigns") }} as c
        on me.campaign_id = c.campaign_id
```

`models/marts/dim_customers.sql`

```sql
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
```

`models/marts/dim_dates.sql`

```sql
with cte_date as (
    {{ dbt_date.get_date_dimension("1990-01-01", "2050-12-31") }}
)

SELECT
    date_day as date_key,
    date_day as full_date,
    day_of_week,
    week_of_year,
    month_of_year as month_number,
    month_name,
    quarter_of_year,
    year_number

from cte_date
```

`models/marts/dim_emails.sql`

```sql
select distinct
    email_id as email_key,
    email_id,
    email_name

from {{ ref("stg_marketing_emails") }}
```

`models/marts/dim_products.sql`

```sql
select
    product_id as product_key,
    product_id,
    product_type,
    product_name,
    price

from {{ ref("stg_products") }}
```

`models/marts/fact_email_events.sql`

```sql
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
```

`models/marts/fact_sales.sql`

```sql
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
```

### Document the Models

Create a schema file to document the models. Since we split our models into two subfolders, we create a file for each of the folders. Here is the code for each of those files:

`models/staging/__schema.yml`

```yaml
version: 2

models:
  - name: stg_customers
    description: "Staging Model for Transactional Customers"
  
  - name: stg_marketing_emails
    description: "Staging Model for Marketing Emails"

  - name: stg_order_lines
    description: "Staging Model for Transactional Order Lines"

  - name: stg_orders
    description: "Staging Model for Transactional Orders"

  - name: stg_products
    description: "Staging Model for Transactional Products"

  - name: stg_promotional_campaigns
    description: "Staging Model for Transactional Promotional Campaigns"
```

`models/marts/__schema.yml`

```yaml
version: 2

models:
  - name: dim_campaigns
    description: "Promotional Campaign Dimension"

  - name: dim_customers
    description: |
      Customer Dimension.
      Also includes subscribers who are not yet customers

  - name: dim_dates
    description: "Date Dimension"

  - name: dim_emails
    description: "Email Dimension"

  - name: dim_products
    description: "Product Dimension"

  - name: fact_email_events
    description: |
      Marketing Email Events Fact.
      The grain of this table is customer + email + event
      Each row represents a discrete event for a single customer on a single email

  - name: fact_sales
    description: |
      Sales Fact.
      Each row represents a discrete line item of a customer order
```
