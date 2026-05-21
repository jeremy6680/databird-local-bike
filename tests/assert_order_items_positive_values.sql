-- =============================================================================
-- Singular test: assert_order_items_positive_values
-- Layer: staging
-- Source model: stg_localbike__order_items
--
-- Purpose:
--   Ensure every order item has a valid quantity, list price, and discount.
--   This test catches data entry errors before they propagate to the mart layer
--   and corrupt revenue calculations.
--
-- Failure condition:
--   Returns one row per invalid record. dbt fails the test if row count > 0.
--
-- Rules enforced:
--   - quantity must be strictly positive (>= 1)
--   - list_price must be strictly positive (> 0)
--   - discount must be between 0 and 1 inclusive (0% to 100%)
--     A discount > 1 (> 100%) is invalid and likely a data entry error.
-- =============================================================================

SELECT
    order_id,
    item_id,
    quantity,
    list_price,
    discount
FROM {{ ref('stg_localbike__order_items') }}
WHERE
    -- A quantity of 0 or less makes no business sense for an order line
    quantity <= 0

    -- A list price of 0 or less is invalid for a retail product
    OR list_price <= 0

    -- A negative discount is not a valid concept in this data model
    OR discount < 0

    -- A discount greater than 1 means more than 100% off, which is erroneous
    OR discount > 1
