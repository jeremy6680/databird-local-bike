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

with

source as (

    -- Pull all raw rows from the order_items source table
    select * from {{ source('localbike', 'order_items') }}

),

renamed as (

    select

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
        cast(quantity   as INT64)   as quantity,

        -- List price of the product at the time of the order
        -- Note: may differ from the current list_price in stg_localbike__products
        cast(list_price as FLOAT64) as list_price,

        -- Discount rate applied to this line (0.0 to 1.0)
        -- Example: 0.1 = 10% discount
        cast(discount   as FLOAT64) as discount,

        -- -----------------------------------------------------------------------
        -- Derived columns
        -- -----------------------------------------------------------------------

        -- Unit price after discount
        round(
            cast(list_price as FLOAT64) * (1 - cast(discount as FLOAT64)),
            2
        ) as net_price,

        -- Total revenue for this line (net_price × quantity)
        round(
            cast(list_price as FLOAT64) * (1 - cast(discount as FLOAT64))
            * cast(quantity as INT64),
            2
        ) as line_revenue

    from source

)

select * from renamed