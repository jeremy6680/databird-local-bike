-- =============================================================================
-- Model: stg_localbike__staffs
-- Layer: Staging
-- Description: Light cleaning and standardisation of the staffs source table.
--              Casts active flag to BOOL and derives a human-readable label.
-- Source: localbike.staffs
-- Depends on: source('localbike', 'staffs')
-- Consumed by: int_orders__enriched
-- =============================================================================

WITH

source AS (

    -- Pull all raw rows from the staffs source table
    SELECT * FROM {{ source('localbike', 'staffs') }}

),

renamed AS (

    SELECT

        -- -----------------------------------------------------------------------
        -- Primary key
        -- -----------------------------------------------------------------------
        staff_id,

        -- -----------------------------------------------------------------------
        -- Foreign keys
        -- -----------------------------------------------------------------------

        -- Store this staff member belongs to
        store_id,

        -- Manager of this staff member (nullable — NULL for top-level managers)
        -- SAFE_CAST used instead of CAST: returns NULL on conversion failure
        -- (source column is STRING — invalid values are silently nullified)
        SAFE_CAST(manager_id AS INT64) AS manager_id,

        -- -----------------------------------------------------------------------
        -- Staff attributes
        -- -----------------------------------------------------------------------
        first_name,
        last_name,

        -- Convenience column: full name for display purposes
        CONCAT(first_name, ' ', last_name) AS full_name,

        -- Contact details
        phone,
        email,

        -- -----------------------------------------------------------------------
        -- Active status
        -- 1 = active employee, 0 = inactive (left the company)
        -- -----------------------------------------------------------------------
        CAST(active AS BOOL) AS active,

        CASE CAST(active AS INT64)
            WHEN 1 THEN 'Active'
            WHEN 0 THEN 'Inactive'
            ELSE 'Unknown'
        END AS active_label

    FROM source

)

SELECT * FROM renamed