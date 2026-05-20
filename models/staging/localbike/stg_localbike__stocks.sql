-- =============================================================================
-- Model: stg_localbike__stocks
-- Layer: Staging
-- Description: Light cleaning and standardisation of the stocks source table.
--              One row per store/product combination.
-- Source: localbike.stocks
-- Depends on: source('localbike', 'stocks')
-- Consumed by: mart layer (stg_localbike__stocks exposed directly to Metabase
--              for stock analysis — no intermediate model required)
-- =============================================================================

WITH

source AS (

    SELECT * FROM {{ source('localbike', 'stocks') }}

),

renamed AS (

    SELECT

        -- -----------------------------------------------------------------------
        -- Primary key (composite: one row per store × product)
        -- -----------------------------------------------------------------------
        store_id,
        product_id,

        -- -----------------------------------------------------------------------
        -- Stock level
        -- -----------------------------------------------------------------------

        -- Current quantity in stock for this product at this store
        CAST(quantity AS INT64) AS quantity

    FROM source

)

SELECT * FROM renamed
