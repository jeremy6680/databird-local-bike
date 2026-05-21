-- =============================================================================
-- Model: customer_summary
-- Layer: Mart
-- Materialisation: table
-- Description: One row per customer. Summarises order history, lifetime value,
--              average basket, and first/last order dates. Powers the customer
--              LTV and top customers KPIs in Metabase.
--
-- Grain: customer_id
-- Depends on: int_orders__enriched, int_order_items__enriched
-- Consumed by: Metabase dashboard (customer KPIs)
-- =============================================================================

{{
    config(
        materialized = 'table'
    )
}}

WITH

-- ---------------------------------------------------------------------------
-- Source: enriched orders — customer dimensions + order dates + status
-- ---------------------------------------------------------------------------
int_orders AS (

    SELECT
        order_id,
        customer_id,
        customer_full_name,
        customer_city,
        customer_state,
        order_date,
        order_status

    FROM {{ ref('int_orders__enriched') }}

),

-- ---------------------------------------------------------------------------
-- Source: enriched order items — line-level pricing for revenue calculation
-- ---------------------------------------------------------------------------
int_order_items AS (

    SELECT
        order_id,
        list_price,
        quantity,
        discount

    FROM {{ ref('int_order_items__enriched') }}

),

-- ---------------------------------------------------------------------------
-- Compute revenue per completed order
-- Only completed orders (status = 4) contribute to revenue and LTV
-- ---------------------------------------------------------------------------
revenue_per_order AS (

    SELECT
        oi.order_id,
        o.customer_id,
        o.order_date,

        -- Revenue per order: sum of all line revenues
        SUM(oi.list_price * oi.quantity * (1 - oi.discount)) AS order_revenue

    FROM int_order_items AS oi
    INNER JOIN int_orders AS o
        ON oi.order_id = o.order_id

    -- Only completed orders contribute to revenue
    WHERE o.order_status = 4

    GROUP BY
        oi.order_id,
        o.customer_id,
        o.order_date

),

-- ---------------------------------------------------------------------------
-- Aggregate order counts across ALL orders (any status) per customer
-- A customer who placed 5 orders (2 rejected) still placed 5 orders
-- ---------------------------------------------------------------------------
all_orders_per_customer AS (

    SELECT
        customer_id,
        COUNT(DISTINCT order_id)  AS total_order_count,
        MIN(order_date)           AS first_order_date,
        MAX(order_date)           AS last_order_date

    FROM int_orders

    GROUP BY customer_id

),

-- ---------------------------------------------------------------------------
-- Aggregate revenue metrics across completed orders only
-- ---------------------------------------------------------------------------
revenue_per_customer AS (

    SELECT
        customer_id,

        -- Lifetime value: total revenue across all completed orders
        ROUND(SUM(order_revenue), 2)                                AS lifetime_value,

        -- Number of completed orders (used for avg basket calculation)
        COUNT(DISTINCT order_id)                                    AS completed_order_count,

        -- Average basket: LTV / number of completed orders
        ROUND(
            SUM(order_revenue) / NULLIF(COUNT(DISTINCT order_id), 0),
            2
        )                                                           AS avg_basket

    FROM revenue_per_order

    GROUP BY customer_id

),

-- ---------------------------------------------------------------------------
-- Extract distinct customer dimensions (one row per customer)
-- Avoids an inline subquery in the final SELECT — ST05
-- ---------------------------------------------------------------------------
customer_dims AS (

    SELECT DISTINCT
        customer_id,
        customer_full_name,
        customer_city,
        customer_state

    FROM int_orders

),

-- ---------------------------------------------------------------------------
-- Final: join customer dimensions, order counts, and revenue metrics
-- ---------------------------------------------------------------------------
final AS (

    SELECT

        -- ------------------------------------------------------------------
        -- Primary key
        -- ------------------------------------------------------------------
        cd.customer_id,

        -- ------------------------------------------------------------------
        -- Customer dimensions
        -- ------------------------------------------------------------------
        cd.customer_full_name,
        cd.customer_city,
        cd.customer_state,

        -- ------------------------------------------------------------------
        -- Order activity metrics (all statuses)
        -- ------------------------------------------------------------------

        -- Total orders placed regardless of status
        ao.total_order_count,

        -- First and last order dates across all statuses
        ao.first_order_date,
        ao.last_order_date,

        -- ------------------------------------------------------------------
        -- Revenue metrics (completed orders only)
        -- ------------------------------------------------------------------

        -- Number of completed orders (may differ from total_order_count)
        COALESCE(rc.completed_order_count, 0) AS completed_order_count,

        -- Lifetime value — 0 for customers with no completed orders
        COALESCE(rc.lifetime_value, 0)        AS lifetime_value,

        -- Average basket — NULL for customers with no completed orders
        rc.avg_basket

    FROM all_orders_per_customer AS ao

    -- Keep all customers, even those with no completed orders
    LEFT JOIN revenue_per_customer AS rc
        ON ao.customer_id = rc.customer_id

    -- Join pre-extracted customer dimensions
    LEFT JOIN customer_dims AS cd
        ON ao.customer_id = cd.customer_id

)

SELECT * FROM final
