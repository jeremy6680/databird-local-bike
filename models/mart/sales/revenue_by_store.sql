-- =============================================================================
-- Model: revenue_by_store
-- Layer: Mart
-- Materialisation: table
-- Description: One row per store × month. Aggregates total revenue and order
--              count for each store and calendar month. Powers the monthly
--              revenue bar chart and store comparison KPIs in Metabase.
--
-- Grain: store_id × order_year_month
-- Depends on: int_orders__enriched
-- Consumed by: Metabase dashboard (revenue by store KPIs)
-- =============================================================================

{{
    config(
        materialized = 'table'
    )
}}

WITH

-- ---------------------------------------------------------------------------
-- Source: enriched orders (one row per order, with store dimensions)
-- Only completed orders (status = 4) contribute to revenue.
-- Pending / Processing / Rejected orders are excluded from revenue figures.
-- ---------------------------------------------------------------------------
int_orders AS (

    SELECT * FROM {{ ref('int_orders__enriched') }}

),

-- ---------------------------------------------------------------------------
-- Filter: keep only completed orders
-- ---------------------------------------------------------------------------
completed_orders AS (

    SELECT * FROM int_orders
    WHERE order_status = 4

),

-- ---------------------------------------------------------------------------
-- Join order lines to get revenue per order
-- Revenue = SUM((list_price * quantity) * (1 - discount)) across all items
-- This requires joining to int_order_items__enriched
-- ---------------------------------------------------------------------------
order_items AS (

    SELECT * FROM {{ ref('int_order_items__enriched') }}

),

-- ---------------------------------------------------------------------------
-- Compute revenue per order (line-level aggregation before store grouping)
-- ---------------------------------------------------------------------------
revenue_per_order AS (

    SELECT
        oi.order_id,
        -- Revenue per order line: unit price after discount × quantity
        SUM(oi.list_price * oi.quantity * (1 - oi.discount)) AS order_revenue

    FROM order_items AS oi

    -- Only include lines for completed orders
    INNER JOIN completed_orders AS co
        ON oi.order_id = co.order_id

    GROUP BY oi.order_id

),

-- ---------------------------------------------------------------------------
-- Attach store dimensions to each order's revenue
-- ---------------------------------------------------------------------------
orders_with_revenue AS (

    SELECT
        co.store_id,
        co.store_name,
        co.store_city,
        co.store_state,
        FORMAT_DATE('%Y-%m', co.order_date) AS order_year_month,
        rpo.order_revenue

    FROM completed_orders AS co
    INNER JOIN revenue_per_order AS rpo
        ON co.order_id = rpo.order_id

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

        -- Calendar month (YYYY-MM) derived from order_date in the intermediate
        order_year_month,

        -- ------------------------------------------------------------------
        -- Metrics
        -- ------------------------------------------------------------------

        -- Total revenue for this store and month (completed orders only)
        ROUND(SUM(order_revenue), 2)  AS total_revenue,

        -- Number of completed orders for this store and month
        COUNT(*)                      AS order_count,

        -- Average revenue per order for this store and month
        ROUND(SUM(order_revenue) / NULLIF(COUNT(*), 0), 2) AS avg_order_revenue

    FROM orders_with_revenue

    GROUP BY
        store_id,
        store_name,
        store_city,
        store_state,
        order_year_month

)

SELECT * FROM final
