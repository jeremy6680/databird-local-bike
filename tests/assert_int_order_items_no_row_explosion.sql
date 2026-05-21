/*
  Singular test: assert_int_order_items_no_row_explosion
  -------------------------------------------------------
  Verifies that int_order_items__enriched has exactly the same number of rows
  as stg_localbike__order_items.
  A row count mismatch would indicate a join fanout on products, brands,
  or categories.
  This test fails if any rows were added or lost during the enrichment joins.
*/

with

items_staging as (
    select count(*) as row_count from {{ ref('stg_localbike__order_items') }}
),

items_enriched as (
    select count(*) as row_count from {{ ref('int_order_items__enriched') }}
)

select
    items_staging.row_count     as staging_count,
    items_enriched.row_count    as enriched_count
from items_staging
cross join items_enriched

-- A non-empty result means the test FAILS
where items_staging.row_count != items_enriched.row_count