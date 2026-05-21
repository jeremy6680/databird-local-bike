/*
  Singular test: assert_int_order_items_no_row_explosion
  -------------------------------------------------------
  Verifies that int_order_items__enriched has exactly the same number of rows
  as stg_localbike__order_items.
  A row count mismatch would indicate a join fanout on products, brands,
  or categories.
  This test fails if any rows were added or lost during the enrichment joins.
*/

WITH

items_staging AS (
    SELECT COUNT(*) AS row_count FROM {{ ref('stg_localbike__order_items') }}
),

items_enriched AS (
    SELECT COUNT(*) AS row_count FROM {{ ref('int_order_items__enriched') }}
)

SELECT
    items_staging.row_count AS staging_count,
    items_enriched.row_count AS enriched_count
FROM items_staging
CROSS JOIN items_enriched

-- A non-empty result means the test FAILS
WHERE items_staging.row_count != items_enriched.row_count
