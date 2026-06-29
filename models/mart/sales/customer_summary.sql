-- =============================================================================
-- Model: customer_summary
-- Layer: Mart
-- Materialisation: table
-- Description: One row per customer. Summarises order history, lifetime value,
--              average basket, and first/last order dates. Powers the customer
--              LTV and top customers KPIs in Metabase.
--
-- Sensitive data handling (ADR-024):
--   - customer_city / customer_state removed — combined with
--     customer_full_name, customer-level geography increases
--     re-identification risk with no stated business use case
--   - customer_full_name kept — legitimate ops use case, protected via
--     Metabase access control (internal-only collection), not masking
--
-- Grain: customer_id
-- Depends on: int_orders__with_revenue
-- Consumed by: Metabase dashboard (customer KPIs)
-- =============================================================================

{{
    config(
        materialized = 'table'
    )
}}

WITH

-- ---------------------------------------------------------------------------
-- Source: enriched orders with pre-computed revenue (one row per order)
-- order_revenue is NULL for non-completed orders (ADR-019)
-- ---------------------------------------------------------------------------
int_orders AS (

    SELECT * FROM {{ ref('int_orders__with_revenue') }}

),

-- ---------------------------------------------------------------------------
-- Aggregate order counts across ALL orders (any status) per customer
-- A customer who placed 5 orders (2 rejected) still placed 5 orders
-- ---------------------------------------------------------------------------
all_orders_per_customer AS (

    SELECT
        customer_id,
        COUNT(DISTINCT order_id)    AS total_order_count,
        MIN(order_date)             AS first_order_date,
        MAX(order_date)             AS last_order_date

    FROM int_orders

    GROUP BY customer_id

),

-- ---------------------------------------------------------------------------
-- Aggregate revenue metrics across completed orders only
-- COALESCE on order_revenue is safe — NULL means non-completed (ADR-019)
-- ---------------------------------------------------------------------------
revenue_per_customer AS (

    SELECT
        customer_id,

        -- Number of completed orders
        COUNT(DISTINCT order_id) AS completed_order_count,

        -- Lifetime value: total revenue across all completed orders
        ROUND(SUM(order_revenue), 2) AS lifetime_value,

        -- Average basket: LTV / number of completed orders
        ROUND(
            SUM(order_revenue) / NULLIF(COUNT(DISTINCT order_id), 0),
            2
        ) AS avg_basket

    FROM int_orders

    -- Only completed orders contribute to revenue metrics (ADR-019)
    WHERE order_status = 4

    GROUP BY customer_id

),

-- ---------------------------------------------------------------------------
-- Extract distinct customer dimensions (one row per customer)
-- ---------------------------------------------------------------------------
customer_dims AS (

    SELECT DISTINCT
        customer_id,
        customer_full_name

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

        -- ------------------------------------------------------------------
        -- Order activity metrics (all statuses)
        -- ------------------------------------------------------------------

        -- Total orders placed regardless of status
        ao.total_order_count,

        -- First and last order dates across all statuses
        ao.first_order_date,
        ao.last_order_date,

        -- ------------------------------------------------------------------
        -- Revenue metrics (completed orders only — ADR-019)
        -- ------------------------------------------------------------------

        -- Number of completed orders (may differ from total_order_count)
        COALESCE(rc.completed_order_count, 0)   AS completed_order_count,

        -- Lifetime value — 0 for customers with no completed orders
        COALESCE(rc.lifetime_value, 0)          AS lifetime_value,

        -- Average basket — NULL for customers with no completed orders
        rc.avg_basket

    FROM all_orders_per_customer AS ao

    -- Keep all customers, even those with no completed orders
    LEFT JOIN revenue_per_customer AS rc
        ON ao.customer_id = rc.customer_id

    LEFT JOIN customer_dims AS cd
        ON ao.customer_id = cd.customer_id

)

SELECT * FROM final