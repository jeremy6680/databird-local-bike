-- =============================================================================
-- Model: orders
-- Layer: Mart
-- Materialisation: incremental (merge) — ADR-008
-- Description: One row per order, fully enriched with customer, store, and
--              staff dimensions, plus pre-computed order-level revenue.
--              This is the central mart model — it powers the monthly order
--              trend, on-time delivery, revenue, and operations KPIs in
--              Metabase.
--
-- Incremental strategy:
--   - unique_key: order_id
--   - strategy: merge (BigQuery)
--   - filter: only processes orders whose order_date is >= the latest
--     order_date already in the table minus 7 days (catches new orders
--     AND status updates on recent orders)
--   - First run: dbt run --full-refresh --select orders
--
-- Depends on: int_orders__with_revenue
-- Consumed by: Metabase dashboard (orders KPIs)
-- =============================================================================

{{
    config(
        materialized         = 'incremental',
        unique_key           = 'order_id',
        incremental_strategy = 'merge',
        partition_by         = {
            'field': 'order_date',
            'data_type': 'date',
            'granularity': 'month'
        },
        cluster_by = ['store_id', 'order_status']
    )
}}

WITH

-- ---------------------------------------------------------------------------
-- Base: enriched orders with pre-computed revenue (one row per order)
-- Revenue metrics are NULL for non-completed orders (ADR-019)
-- ---------------------------------------------------------------------------
int_orders AS (

    SELECT * FROM {{ ref('int_orders__with_revenue') }}

),

-- ---------------------------------------------------------------------------
-- Incremental filter: on incremental runs, only process rows whose
-- order_date falls within the window already present in the table.
-- The 7-day lookback ensures we catch late status updates on recent orders.
-- On a full-refresh run, this block is ignored entirely.
-- ---------------------------------------------------------------------------
filtered AS (

    SELECT * FROM int_orders

    {% if is_incremental() %}
        WHERE order_date >= (
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

        -- Raw integer kept for performant filtering in Metabase
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

        -- TRUE if shipped on or before required_date, FALSE if late,
        -- NULL if not yet shipped
        CASE
            WHEN shipped_date IS NULL     THEN NULL
            WHEN delivery_delay_days <= 0 THEN TRUE
            ELSE FALSE
        END AS is_on_time,

        -- Year-month string for monthly aggregations in Metabase (format: YYYY-MM)
        FORMAT_DATE('%Y-%m', order_date) AS order_year_month,

        -- ---------------------------------------------------------------------
        -- Customer dimensions
        -- ---------------------------------------------------------------------
        customer_id,
        customer_first_name,
        customer_last_name,
        customer_full_name,
        customer_city,
        customer_state,

        -- ---------------------------------------------------------------------
        -- Store dimensions
        -- ---------------------------------------------------------------------
        store_id,
        store_name,
        store_city,
        store_state,

        -- ---------------------------------------------------------------------
        -- Staff dimensions
        -- ---------------------------------------------------------------------
        staff_id,
        staff_first_name,
        staff_last_name,

        -- ---------------------------------------------------------------------
        -- Revenue metrics (NULL for non-completed orders — ADR-019)
        -- ---------------------------------------------------------------------

        -- Total revenue for this order after discounts
        order_revenue,

        -- Total units sold across all product lines
        order_units_sold,

        -- Number of distinct product lines in this order
        order_line_count

    FROM filtered

)

SELECT * FROM final
