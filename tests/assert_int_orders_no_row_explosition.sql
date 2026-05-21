/*
  Singular test: assert_int_orders_no_row_explosion
  --------------------------------------------------
  Verifies that int_orders__enriched has exactly the same number of rows
  as stg_localbike__orders.
  A row count mismatch would indicate a join fanout (e.g. one-to-many
  relationship not accounted for in the intermediate model).
  This test fails if any rows were added or lost during the enrichment joins.
*/

WITH

orders_staging AS (
    SELECT COUNT(*) AS row_count FROM {{ ref('stg_localbike__orders') }}
),

orders_enriched AS (
    SELECT COUNT(*) AS row_count FROM {{ ref('int_orders__enriched') }}

)

SELECT
    orders_staging.row_count AS staging_count,
    orders_enriched.row_count AS enriched_count
FROM orders_staging
CROSS JOIN orders_enriched

-- A non-empty result means the test FAILS
WHERE orders_staging.row_count != orders_enriched.row_count
