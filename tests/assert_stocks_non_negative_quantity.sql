-- =============================================================================
-- Singular test: assert_stocks_non_negative_quantity
-- Layer: staging
-- Source model: stg_localbike__stocks
--
-- Purpose:
--   Ensure that no stock record has a negative quantity.
--   A quantity of 0 is valid (product is out of stock at this store).
--   A negative quantity is a data error with no valid business interpretation.
--
-- Failure condition:
--   Returns one row per invalid stock record. dbt fails the test if row count > 0.
--
-- Note:
--   The grain of stg_localbike__stocks is (store_id, product_id).
--   Both columns are included in the output to make failures easy to investigate.
-- =============================================================================

SELECT
    store_id,
    product_id,
    quantity
FROM {{ ref('stg_localbike__stocks') }}
WHERE
    -- Negative stock quantity is a data entry error
    quantity < 0