/*
  Singular test: assert_int_orders_no_row_explosion
  --------------------------------------------------
  Verifies that int_orders__enriched has exactly the same number of rows
  as stg_localbike__orders.
  A row count mismatch would indicate a join fanout (e.g. one-to-many
  relationship not accounted for in the intermediate model).
  This test fails if any rows were added or lost during the enrichment joins.
*/

with

orders_staging as (
    select count(*) as row_count from {{ ref('stg_localbike__orders') }}
),

orders_enriched as (
    select count(*) as row_count from {{ ref('int_orders__enriched') }}

)

select
    orders_staging.row_count    as staging_count,
    orders_enriched.row_count   as enriched_count
from orders_staging
cross join orders_enriched

-- A non-empty result means the test FAILS
where orders_staging.row_count != orders_enriched.row_count