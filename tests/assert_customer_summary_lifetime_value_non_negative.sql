-- tests/assert_customer_summary_lifetime_value_non_negative.sql
-- Ensures no customer has a negative lifetime value.
-- lifetime_value is COALESCE'd to 0 for customers with no completed orders,
-- so any negative value would indicate a data issue in pricing or discounts.

SELECT
    customer_id,
    lifetime_value
FROM {{ ref('customer_summary') }}
WHERE lifetime_value < 0