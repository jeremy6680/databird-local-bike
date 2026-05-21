-- =============================================================================
-- Model: orders
-- Layer: Mart
-- Materialisation: incremental (merge) — ADR-008
-- Description: One row per order, fully enriched with customer, store, and
--              staff dimensions. This is the central mart model — it powers
--              the monthly order trend, on-time delivery, and operations KPIs
--              in Metabase.
--
-- Incremental strategy:
--   - unique_key: order_id
--   - strategy: merge (BigQuery)
--   - filter: only processes orders whose order_date is >= the latest
--     order_date already in the table (catches new orders AND status updates
--     on recent orders)
--   - First run: dbt run --full-refresh --select orders
--
-- Depends on: int_orders__enriched
-- Consumed by: Metabase dashboard (orders KPIs)
-- =============================================================================

{{
    config(
        materialized  = 'incremental',
        unique_key    = 'order_id',
        incremental_strategy = 'merge',
        partition_by  = {
            'field': 'order_date',
            'data_type': 'date',
            'granularity': 'month'
        },
        cluster_by    = ['store_id', 'order_status']
    )
}}

WITH

source AS (

    SELECT * FROM {{ ref('int_orders__enriched') }}

    -- -------------------------------------------------------------------------
    -- Incremental filter: on incremental runs, only process rows whose
    -- order_date falls within the window already present in the table.
    -- The 7-day lookback (INTERVAL 7 DAY) ensures we catch late status updates
    -- (e.g. an order placed last week that just moved to 'Completed').
    -- On a full-refresh run, this block is ignored entirely.
    -- -------------------------------------------------------------------------
    {% if is_incremental() %}
        WHERE source.order_date >= (
            SELECT DATE_SUB(MAX(this_table.order_date), INTERVAL 7 DAY)
            FROM {{ this }} AS this_table
        )
    {% endif %}

),

final AS (

    SELECT

        -- ---------------------------------------------------------------------
        -- Primary key
        -- ---------------------------------------------------------------------
        order_id,

        -- ---------------------------------------------------------------------
        -- Order status
        -- ---------------------------------------------------------------------

        -- Raw integer status — kept for performant filtering in Metabase
        order_status,

        -- Human-readable label (Pending / Processing / Rejected / Completed)
        order_status_label,

        -- ---------------------------------------------------------------------
        -- Order dates
        -- ---------------------------------------------------------------------
        order_date,
        required_date,

        -- NULL when order has not yet shipped (status 1, 2, or 3)
        shipped_date,

        -- Delivery delay in calendar days:
        --   positive = late, negative = early, NULL = not yet shipped
        delivery_delay_days,

        -- Boolean flag: TRUE when the order shipped on or before required_date
        -- NULL when shipped_date is NULL (not yet shipped)
        customer_id,

        -- Convenience column: year-month of order_date for monthly aggregations
        customer_full_name,

        -- ---------------------------------------------------------------------
        -- Customer dimensions
        -- ---------------------------------------------------------------------
        customer_city,
        customer_state,
        store_id,
        store_name,

        -- ---------------------------------------------------------------------
        -- Store dimensions
        -- ---------------------------------------------------------------------
        store_city,
        store_state,
        staff_id,
        staff_first_name,

        -- ---------------------------------------------------------------------
        -- Staff dimensions
        -- ---------------------------------------------------------------------
        staff_last_name,
        CASE
            WHEN shipped_date IS NULL THEN NULL
            WHEN delivery_delay_days <= 0 THEN TRUE
            ELSE FALSE
        END AS is_on_time,
        FORMAT_DATE('%Y-%m', order_date) AS order_year_month

    FROM source

)

SELECT * FROM final
