-- =============================================================================
-- Model: stg_localbike__order_items
-- Layer: Staging
-- Description: Light cleaning and standardisation of the order_items source
--              table. Casts all columns to their correct types and computes
--              net_price and line_revenue for downstream aggregations.
-- Source: localbike.order_items
-- Depends on: source('localbike', 'order_items')
-- Consumed by: int_order_items__enriched
-- =============================================================================

WITH

source AS (

    -- Pull all raw rows from the order_items source table
    SELECT * FROM {{ source('localbike', 'order_items') }}

),

renamed AS (

    SELECT

        -- -----------------------------------------------------------------------
        -- Primary key (composite: one row per order line)
        -- -----------------------------------------------------------------------
        order_id,
        item_id,

        -- -----------------------------------------------------------------------
        -- Foreign key
        -- -----------------------------------------------------------------------
        product_id,

        -- -----------------------------------------------------------------------
        -- Order line details
        -- -----------------------------------------------------------------------

        -- Quantity of units ordered on this line
        CAST(quantity AS INT64) AS quantity,

        -- List price of the product at the time of the order
        -- Note: may differ from the current list_price in stg_localbike__products
        CAST(list_price AS FLOAT64) AS list_price,

        -- Discount rate applied to this line (0.0 to 1.0)
        -- Example: 0.1 = 10% discount
        CAST(discount AS FLOAT64) AS discount,

        -- -----------------------------------------------------------------------
        -- Derived columns
        -- -----------------------------------------------------------------------

        -- Unit price after discount
        ROUND(
            CAST(list_price AS FLOAT64) * (1 - CAST(discount AS FLOAT64)),
            2
        ) AS net_price,

        -- Total revenue for this line (net_price × quantity)
        ROUND(
            CAST(list_price AS FLOAT64) * (1 - CAST(discount AS FLOAT64))
            * CAST(quantity AS INT64),
            2
        ) AS line_revenue

    FROM source

)

SELECT * FROM renamed
