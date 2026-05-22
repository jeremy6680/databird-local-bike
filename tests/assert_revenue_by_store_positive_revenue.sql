-- tests/assert_revenue_by_store_positive_revenue.sql
-- Ensures no store × month row has zero or negative total revenue.
-- A completed order must always produce positive revenue.

SELECT
    store_id,
    order_month,
    total_revenue
FROM {{ ref('revenue_by_store') }}
WHERE total_revenue <= 0
