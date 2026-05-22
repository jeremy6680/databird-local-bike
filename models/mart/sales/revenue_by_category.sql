-- =============================================================================
-- Model: revenue_by_category
-- Layer: Mart
-- Materialisation: table
-- Description: One row per product category × calendar month. Aggregates
--              total revenue and units sold for each category and month.
--              Powers the revenue breakdown by category (pie/donut chart)
--              and category trend KPIs in Metabase.
--
-- Grain: category_id × order_month
-- Depends on: int_order_items__enriched, int_orders__with_revenue
-- Consumed by: Metabase dashboard (revenue by category KPIs)
-- =============================================================================

{{
    config(
        materialized = 'table'
    )
}}

WITH

-- ---------------------------------------------------------------------------
-- Source: enriched order items — line-level data with product/category dims
-- One row per order line (order_id + item_id)
-- ---------------------------------------------------------------------------
int_order_items AS (

    SELECT * FROM {{ ref('int_order_items__enriched') }}

),

-- ---------------------------------------------------------------------------
-- Source: enriched orders with revenue — used to filter completed orders
-- and retrieve order_date for monthly bucketing
-- order_revenue is NULL for non-completed orders (ADR-019)
-- ---------------------------------------------------------------------------
int_orders AS (

    SELECT
        order_id,
        order_date,
        order_status

    FROM {{ ref('int_orders__with_revenue') }}

    -- Only completed orders contribute to revenue (ADR-019)
    WHERE order_status = 4

),

-- ---------------------------------------------------------------------------
-- Join order items to completed orders only
-- Adds order_date for monthly bucketing
-- ---------------------------------------------------------------------------
completed_items AS (

    SELECT
        oi.category_id,
        oi.category_name,
        oi.order_id,

        -- Revenue per order line: pre-computed in int_order_items__enriched
        oi.line_revenue,

        -- Units sold per order line
        oi.quantity AS units_sold,

        -- First day of the calendar month — native DATE, enables Metabase
        -- date filters and temporal grouping (replaces FORMAT_DATE string)
        DATE_TRUNC(o.order_date, MONTH) AS order_month

    FROM int_order_items AS oi
    INNER JOIN int_orders AS o
        ON oi.order_id = o.order_id

),

-- ---------------------------------------------------------------------------
-- Final aggregation: one row per category × month
-- ---------------------------------------------------------------------------
final AS (

    SELECT

        -- ------------------------------------------------------------------
        -- Grain keys
        -- ------------------------------------------------------------------
        category_id,
        category_name,
        order_month,

        -- ------------------------------------------------------------------
        -- Metrics
        -- ------------------------------------------------------------------

        -- Total revenue for this category and month (completed orders only)
        ROUND(SUM(line_revenue), 2)         AS total_revenue,

        -- Total units sold for this category and month
        SUM(units_sold)                     AS units_sold,

        -- Number of distinct orders containing this category
        COUNT(DISTINCT order_id)            AS order_count

    FROM completed_items

    GROUP BY
        category_id,
        category_name,
        order_month

)

SELECT * FROM final
