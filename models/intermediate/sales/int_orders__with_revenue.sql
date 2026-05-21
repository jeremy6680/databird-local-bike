/*
  int_orders__with_revenue
  ------------------------
  Intermediate model: joins enriched orders with enriched order items to
  produce one row per order with its total revenue pre-computed.

  This model centralises the join between int_orders__enriched and
  int_order_items__enriched, eliminating duplicated join logic that
  previously existed in every mart model (revenue_by_store, top_products,
  revenue_by_category, customer_summary).

  Grain: one row per order (order_id is unique).

  Revenue rule (ADR-019):
    Only completed orders (order_status = 4) have a non-NULL order_revenue.
    Pending / Processing / Rejected orders are preserved in the output
    with order_revenue = NULL, so mart models can filter or COALESCE
    as needed without losing order activity metrics.

  Joins:
    - int_orders__enriched       (base — all order + customer + store + staff dims)
    - int_order_items__enriched  (LEFT JOIN — aggregated to order grain)

  Downstream consumers:
    - mart/sales/orders.sql
    - mart/sales/revenue_by_store.sql
    - mart/sales/revenue_by_category.sql
    - mart/sales/top_products.sql
    - mart/sales/customer_summary.sql
*/

WITH

-- ---------------------------------------------------------------------------
-- Source: enriched orders — all dimensions, one row per order
-- ---------------------------------------------------------------------------
int_orders AS (

    SELECT * FROM {{ ref('int_orders__enriched') }}

),

-- ---------------------------------------------------------------------------
-- Source: enriched order items — aggregated to order grain
-- Revenue is summed per order_id so the join does not fan out rows.
-- Only completed orders (status = 4) produce revenue — others get NULL.
-- ---------------------------------------------------------------------------
order_revenue AS (

    SELECT
        oi.order_id,

        -- Total revenue for this order: sum of all line revenues after discount
        ROUND(SUM(oi.line_revenue), 2) AS order_revenue,

        -- Total units sold across all lines for this order
        SUM(oi.quantity)               AS order_units_sold,

        -- Number of distinct product lines in this order
        COUNT(oi.item_id)              AS order_line_count

    FROM {{ ref('int_order_items__enriched') }} AS oi

    GROUP BY oi.order_id

),

-- ---------------------------------------------------------------------------
-- Final: join order dimensions with pre-aggregated revenue
-- LEFT JOIN preserves all orders, including those with no matching lines
-- (data quality edge cases caught by singular tests at intermediate layer)
-- ---------------------------------------------------------------------------
final AS (

    SELECT

        -- ----------------------------------------------------------------
        -- Primary key
        -- ----------------------------------------------------------------
        o.order_id,

        -- ----------------------------------------------------------------
        -- Order status
        -- ----------------------------------------------------------------
        o.order_status,
        o.order_status_label,

        -- ----------------------------------------------------------------
        -- Order dates
        -- ----------------------------------------------------------------
        o.order_date,
        o.required_date,
        o.shipped_date,
        o.delivery_delay_days,

        -- ----------------------------------------------------------------
        -- Customer dimensions
        -- ----------------------------------------------------------------
        o.customer_id,
        o.customer_first_name,
        o.customer_last_name,
        o.customer_full_name,
        o.customer_email,
        o.customer_phone,
        o.customer_city,
        o.customer_state,

        -- ----------------------------------------------------------------
        -- Store dimensions
        -- ----------------------------------------------------------------
        o.store_id,
        o.store_name,
        o.store_city,
        o.store_state,

        -- ----------------------------------------------------------------
        -- Staff dimensions
        -- ----------------------------------------------------------------
        o.staff_id,
        o.staff_first_name,
        o.staff_last_name,

        -- ----------------------------------------------------------------
        -- Revenue metrics (NULL for non-completed orders)
        -- Mart models filter on order_status = 4 OR use COALESCE(order_revenue, 0)
        -- ----------------------------------------------------------------

        -- Total revenue for this order (completed orders only, else NULL)
        CASE
            WHEN o.order_status = 4 THEN r.order_revenue
        END AS order_revenue,

        -- Total units sold for this order (completed orders only, else NULL)
        CASE
            WHEN o.order_status = 4 THEN r.order_units_sold
        END AS order_units_sold,

        -- Number of product lines for this order (all statuses — useful for ops)
        r.order_line_count

    FROM int_orders AS o

    LEFT JOIN order_revenue AS r
        ON o.order_id = r.order_id

)

SELECT * FROM final
