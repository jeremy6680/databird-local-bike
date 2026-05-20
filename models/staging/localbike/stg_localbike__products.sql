-- =============================================================================
-- Model: stg_localbike__products
-- Layer: Staging
-- Description: Light cleaning and standardisation of the products source table.
--              Casts all columns to their correct types.
--              This is a reference table — no derived columns are computed here.
-- Source: localbike.products
-- Depends on: source('localbike', 'products')
-- Consumed by: int_order_items__enriched
-- =============================================================================

WITH

source AS (

    -- Pull all raw rows from the products source table
    SELECT * FROM {{ source('localbike', 'products') }}

),

renamed AS (

    SELECT

        -- -----------------------------------------------------------------------
        -- Primary key
        -- -----------------------------------------------------------------------
        product_id,

        -- -----------------------------------------------------------------------
        -- Foreign keys
        -- -----------------------------------------------------------------------
        brand_id,
        category_id,

        -- -----------------------------------------------------------------------
        -- Product attributes
        -- -----------------------------------------------------------------------

        -- Product name — kept as-is, no cleaning required
        product_name,

        -- Model year — cast to INT64 (stored as integer in source)
        CAST(model_year AS INT64) AS model_year,

        -- Current catalogue list price — cast to FLOAT64
        -- Note: this is the current price, not the price at order time
        -- (order-time price is captured in stg_localbike__order_items.list_price)
        CAST(list_price AS FLOAT64) AS list_price

    FROM source

)

SELECT * FROM renamed
