-- =============================================================================
-- Model: revenue_by_store
-- Layer: Mart
-- Materialisation: table
-- Description: One row per store × month. Aggregates total revenue and order
--              count for each store and calendar month. Powers the monthly
--              revenue bar chart and store comparison KPIs in Metabase.
--
-- Grain: store_id × order_month
-- Depends on: int_orders__with_revenue
-- Consumed by: Metabase dashboard (revenue by store KPIs)
-- =============================================================================

{{
    config(
        materialized = 'table'
    )
}}

WITH

-- ---------------------------------------------------------------------------
-- Source: enriched orders with pre-computed revenue (one row per order)
-- order_revenue is NULL for non-completed orders — filter applied below
-- ---------------------------------------------------------------------------
int_orders AS (

    SELECT * FROM {{ ref('int_orders__with_revenue') }}

),

-- ---------------------------------------------------------------------------
-- Filter: keep only completed orders (order_revenue is non-NULL)
-- Consistent with ADR-019: only status = 4 contributes to revenue figures
-- ---------------------------------------------------------------------------
completed_orders AS (

    SELECT
        store_id,
        store_name,
        store_city,
        store_state,
        order_id,
        order_revenue,

        -- First day of the calendar month — native DATE, enables Metabase
        -- date filters and temporal grouping (replaces FORMAT_DATE string)
        DATE_TRUNC(order_date, MONTH) AS order_month

    FROM int_orders

    WHERE order_status = 4

),

-- ---------------------------------------------------------------------------
-- Final aggregation: one row per store × month
-- ---------------------------------------------------------------------------
final AS (

    SELECT

        -- ------------------------------------------------------------------
        -- Grain keys
        -- ------------------------------------------------------------------
        store_id,
        store_name,
        store_city,
        store_state,
        order_month,

        -- ------------------------------------------------------------------
        -- Metrics
        -- ------------------------------------------------------------------

        -- Total revenue for this store and month (completed orders only)
        ROUND(SUM(order_revenue), 2) AS total_revenue,

        -- Number of completed orders for this store and month
        COUNT(*) AS order_count,

        -- Average revenue per order for this store and month
        ROUND(SUM(order_revenue) / NULLIF(COUNT(*), 0), 2) AS avg_order_revenue

    FROM completed_orders

    GROUP BY
        store_id,
        store_name,
        store_city,
        store_state,
        order_month

)

SELECT * FROM final
