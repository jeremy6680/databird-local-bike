-- =============================================================================
-- Model: stg_localbike__categories
-- Layer: Staging
-- Description: Light cleaning and standardisation of the categories source
--              table. Simple reference table — no derived columns.
-- Source: localbike.categories
-- Depends on: source('localbike', 'categories')
-- Consumed by: stg_localbike__products (via relationships test)
-- =============================================================================

WITH

source AS (

    SELECT * FROM {{ source('localbike', 'categories') }}

),

renamed AS (

    SELECT

        -- Primary key
        category_id,

        -- Category name
        category_name

    FROM source

)

SELECT * FROM renamed
