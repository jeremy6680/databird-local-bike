-- =============================================================================
-- Model: stg_localbike__brands
-- Layer: Staging
-- Description: Light cleaning and standardisation of the brands source table.
--              Simple reference table — no derived columns.
-- Source: localbike.brands
-- Depends on: source('localbike', 'brands')
-- Consumed by: stg_localbike__products (via relationships test)
-- =============================================================================

WITH

source AS (

    SELECT * FROM {{ source('localbike', 'brands') }}

),

renamed AS (

    SELECT

        -- Primary key
        brand_id,

        -- Brand name
        brand_name

    FROM source

)

SELECT * FROM renamed
