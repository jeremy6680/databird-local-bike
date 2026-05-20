-- =============================================================================
-- Model: stg_localbike__stores
-- Layer: Staging
-- Description: Light cleaning and standardisation of the stores source table.
--              This is a small reference table (3 stores) — no derived columns.
-- Source: localbike.stores
-- Depends on: source('localbike', 'stores')
-- Consumed by: int_orders__enriched
-- =============================================================================

WITH

source AS (

    -- Pull all raw rows from the stores source table
    SELECT * FROM {{ source('localbike', 'stores') }}

),

renamed AS (

    SELECT

        -- -----------------------------------------------------------------------
        -- Primary key
        -- -----------------------------------------------------------------------
        store_id,

        -- -----------------------------------------------------------------------
        -- Store attributes
        -- -----------------------------------------------------------------------

        -- Store name (e.g. "Santa Cruz Bikes", "Baldwin Bikes", "Rowlett Bikes")
        store_name,

        -- Contact details
        phone,
        email,

        -- Physical address
        street,
        city,
        state,
        zip_code

    FROM source

)

SELECT * FROM renamed
