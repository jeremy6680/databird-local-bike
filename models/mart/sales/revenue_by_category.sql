-- =============================================================================
-- Model: revenue_by_category
-- Layer: Mart
-- Materialisation: table
-- Description: One row per product category × calendar month. Aggregates
--              total revenue and units sold for each category and month.
--              Powers the revenue breakdown by category (pie/donut chart)
--              and category trend KPIs in Metabase.
--
-- Grain: category_id × order_year_month
-- Depends on: int_order_items__enriched
-- Consumed by: Metabase dashboard (revenue by category KPIs)
-- =============================================================================

{{
    config(
        materialized = 'table'
    )
}}

WITH

-- ---------------------------------------------------------------------------
-- Source: enriched order items (one row per order line, with product,
-- brand, and category dimensions already joined)
-- ---------------------------------------------------------------------------
int_order_items AS (

    SELECT * FROM {{ ref('int_order_items__enriched') }}

),

-- ---------------------------------------------------------------------------
-- Source: enriched orders — used to filter completed orders only
-- (order_status = 4) and to get the order_date for monthly bucketing
-- ---------------------------------------------------------------------------
int_orders AS (

    SELECT
        order_id,
        order_date,
        order_status

    FROM {{ ref('int_orders__enriched') }}

    -- Only completed orders contribute to revenue
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

        -- Revenue per order line: unit price after discount × quantity
        oi.list_price * oi.quantity * (1 - oi.discount) AS line_revenue,

        -- Units sold per order line
        oi.quantity AS units_sold,

        -- Calendar month derived from order_date (format: YYYY-MM)
        FORMAT_DATE('%Y-%m', o.order_date) AS order_year_month

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
        order_year_month,

        -- ------------------------------------------------------------------
        -- Metrics
        -- ------------------------------------------------------------------

        -- Total revenue for this category and month (completed orders only)
        ROUND(SUM(line_revenue), 2)  AS total_revenue,

        -- Total units sold for this category and month
        SUM(units_sold)              AS units_sold,

        -- Number of distinct orders containing this category
        COUNT(DISTINCT order_id)     AS order_count

    FROM completed_items

    GROUP BY
        category_id,
        category_name,
        order_year_month

)

SELECT * FROM final
