-- =============================================================================
-- Model: top_products
-- Layer: Mart
-- Materialisation: table
-- Description: One row per product. Ranks all products by total revenue
--              across all completed orders. Powers the Top 10 products bar
--              chart in Metabase.
--
-- Grain: product_id
-- Depends on: int_order_items__enriched, int_orders__enriched
-- Consumed by: Metabase dashboard (top products KPI)
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
-- ---------------------------------------------------------------------------
int_orders AS (

    SELECT
        order_id,
        order_status

    FROM {{ ref('int_orders__enriched') }}

    -- Only completed orders contribute to revenue
    WHERE order_status = 4

),

-- ---------------------------------------------------------------------------
-- Join order items to completed orders only
-- ---------------------------------------------------------------------------
completed_items AS (

    SELECT
        oi.product_id,
        oi.product_name,
        oi.brand_name,
        oi.category_name,

        -- Revenue per order line: unit price after discount × quantity
        oi.list_price * oi.quantity * (1 - oi.discount) AS line_revenue,

        -- Units sold per order line
        oi.quantity AS units_sold,

        oi.order_id

    FROM int_order_items AS oi
    INNER JOIN int_orders AS o
        ON oi.order_id = o.order_id

),

-- ---------------------------------------------------------------------------
-- Aggregate by product (all-time totals)
-- ---------------------------------------------------------------------------
aggregated AS (

    SELECT
        product_id,
        product_name,
        brand_name,
        category_name,

        -- Total all-time revenue for this product (completed orders only)
        ROUND(SUM(line_revenue), 2)      AS total_revenue,

        -- Total units sold all-time
        SUM(units_sold)                  AS units_sold,

        -- Number of distinct orders containing this product
        COUNT(DISTINCT order_id)         AS order_count

    FROM completed_items

    GROUP BY
        product_id,
        product_name,
        brand_name,
        category_name

),

-- ---------------------------------------------------------------------------
-- Rank products by total revenue (dense rank to avoid gaps)
-- ---------------------------------------------------------------------------
final AS (

    SELECT
        product_id,
        product_name,
        brand_name,
        category_name,
        total_revenue,
        units_sold,
        order_count,

        -- Revenue rank across all products (1 = highest revenue)
        DENSE_RANK() OVER (
            ORDER BY total_revenue DESC
        ) AS revenue_rank

    FROM aggregated

)

SELECT * FROM final
