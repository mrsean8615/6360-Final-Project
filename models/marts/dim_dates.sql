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
