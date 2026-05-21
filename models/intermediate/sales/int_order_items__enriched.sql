/*
  int_order_items__enriched
  -------------------------
  Intermediate model: enriches order items with product, brand, and category details.

  Grain: one row per order line (order_id + item_id is unique).

  Joins:
    - stg_localbike__order_items   (base table)
    - stg_localbike__products      (LEFT JOIN — product details)
    - stg_localbike__brands        (LEFT JOIN — brand details)
    - stg_localbike__categories    (LEFT JOIN — category details)

  LEFT JOINs are intentional: orphaned FK values are caught by
  relationships tests at the staging layer. We preserve all order lines
  rather than silently dropping rows with unresolved FKs.

  Business logic:
    - line_revenue: effective revenue per line after discount
      formula: quantity * list_price * (1 - discount)

  Downstream consumers:
    - mart/sales/revenue_by_category.sql
    - mart/sales/top_products.sql
    - mart/sales/customer_summary.sql
*/

WITH

-- -----------------------------------------------------------------------
-- Source CTEs
-- -----------------------------------------------------------------------

order_items AS (

    SELECT * FROM {{ ref('stg_localbike__order_items') }}

),

products AS (

    SELECT * FROM {{ ref('stg_localbike__products') }}

),

brands AS (

    SELECT * FROM {{ ref('stg_localbike__brands') }}

),

categories AS (

    SELECT * FROM {{ ref('stg_localbike__categories') }}

),

-- -----------------------------------------------------------------------
-- Enrichment: join all four staging models
-- -----------------------------------------------------------------------

enriched AS (

    SELECT

        -- ----------------------------------------------------------------
        -- Order line identifiers
        -- ----------------------------------------------------------------
        order_items.order_id,
        order_items.item_id,

        -- ----------------------------------------------------------------
        -- Pricing and quantity
        -- ----------------------------------------------------------------
        order_items.quantity,
        order_items.list_price,
        order_items.discount,

        /*
          line_revenue: effective revenue for this order line after discount.
          Formula: quantity * list_price * (1 - discount)
          Rounded to 2 decimal places to avoid floating-point drift.
          This is the canonical revenue metric — used by all downstream marts.
        */
        order_items.product_id,

        -- ----------------------------------------------------------------
        -- Product details (LEFT JOIN — products)
        -- ----------------------------------------------------------------
        products.product_name,
        products.model_year,
        products.list_price AS product_list_price,
        products.brand_id,

        -- ----------------------------------------------------------------
        -- Brand details (LEFT JOIN — brands via products)
        -- ----------------------------------------------------------------
        brands.brand_name,
        products.category_id,

        -- ----------------------------------------------------------------
        -- Category details (LEFT JOIN — categories via products)
        -- ----------------------------------------------------------------
        categories.category_name,
        ROUND(
            order_items.quantity
            * order_items.list_price
            * (1 - order_items.discount),
            2
        ) AS line_revenue

    FROM order_items

    LEFT JOIN products
        ON order_items.product_id = products.product_id

    LEFT JOIN brands
        ON products.brand_id = brands.brand_id

    LEFT JOIN categories
        ON products.category_id = categories.category_id

)

-- -----------------------------------------------------------------------
-- Final select
-- -----------------------------------------------------------------------

SELECT * FROM enriched
