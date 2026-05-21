-- =============================================================================
-- Singular test: assert_orders_date_consistency
-- Layer: staging
-- Source model: stg_localbike__orders
--
-- Purpose:
--   Ensure the three order dates follow a logically consistent chronology:
--     order_date <= required_date
--     order_date <= shipped_date (when shipped_date is not null)
--
--   This is critical: any violation would corrupt the lead time calculation
--   in the mart layer (orders.days_to_ship, on-time delivery rate KPI).
--
-- Failure condition:
--   Returns one row per inconsistent order. dbt fails the test if row count > 0.
--
-- Note on NULL shipped_date:
--   A NULL shipped_date is valid — it means the order has not yet been shipped.
--   We only validate shipped_date when it is present.
-- =============================================================================

SELECT
    order_id,
    order_date,
    required_date,
    shipped_date
FROM {{ ref('stg_localbike__orders') }}
WHERE
    -- required_date must be on or after the order was placed
    required_date < order_date

    -- shipped_date, when present, must be on or after the order was placed
    OR (
        shipped_date IS NOT NULL
        AND shipped_date < order_date
    )
