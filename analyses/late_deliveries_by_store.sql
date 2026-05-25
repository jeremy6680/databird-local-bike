-- =============================================================================
-- Analysis: Late delivery rate by store
-- =============================================================================
-- Purpose : Identify whether late deliveries are concentrated in a specific
--           store or distributed evenly across all locations.
-- Sources : mart.orders — contains delivery_delay_days, store_name, order_status
-- Grain   : one row per store (aggregated)
-- Definition of "late": shipped_date > required_date (delivery_delay_days > 0)
--   Only completed orders (status = 4) are included — pending/rejected orders
--   have no shipped_date and cannot be evaluated for delivery performance.
-- Usage   : Run in Metabase (native query) or BigQuery console
-- =============================================================================

WITH

-- Base: completed orders only, with delivery delay information
completed_orders AS (
    SELECT
        store_id,
        store_name,
        order_id,
        order_date,
        required_date,
        shipped_date,
        delivery_delay_days,

        -- Classify each order as on-time or late
        CASE
            WHEN delivery_delay_days > 0 THEN 'Late'
            ELSE 'On time'
        END AS delivery_status

    FROM {{ ref('orders') }}
    -- ref() syntax for dbt docs/lineage — replace with full path for direct execution:
    -- FROM `databird-prep-work-ae`.`dbt_local_bike_prod_mart`.`orders`

    -- Completed orders only: pending/processing/rejected have no shipped_date
    WHERE order_status = 4

        -- Guard: exclude rows where shipped_date is null
        -- (completed orders should all have a shipped_date, but defensive filter)
        AND shipped_date IS NOT NULL
),

-- Aggregate by store
store_stats AS (
    SELECT
        store_id,
        store_name,
        COUNT(order_id)                                         AS total_completed_orders,
        COUNTIF(delivery_status = 'Late')                       AS late_orders,
        COUNTIF(delivery_status = 'On time')                    AS on_time_orders,

        -- Average delay in days (late orders only)
        ROUND(
            AVG(
                CASE WHEN delivery_status = 'Late'
                     THEN delivery_delay_days
                END
            ), 1
        )                                                       AS avg_delay_days_when_late,

        -- Maximum delay observed per store
        MAX(
            CASE WHEN delivery_status = 'Late'
                 THEN delivery_delay_days
            END
        )                                                       AS max_delay_days

    FROM completed_orders
    GROUP BY store_id, store_name
)

-- Final output with late delivery rate
SELECT
    store_name,
    total_completed_orders,
    on_time_orders,
    late_orders,

    -- Late rate as a percentage, rounded to 1 decimal
    ROUND(
        SAFE_DIVIDE(late_orders, total_completed_orders) * 100,
        1
    )                                                           AS late_delivery_rate_pct,

    avg_delay_days_when_late,
    max_delay_days

FROM store_stats
ORDER BY late_delivery_rate_pct DESC