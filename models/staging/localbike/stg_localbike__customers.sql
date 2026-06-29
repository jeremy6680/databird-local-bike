-- =============================================================================
-- Model: stg_localbike__customers
-- Layer: Staging
-- Description: Light cleaning and standardisation of the customers source
--              table. Casts zip_code to STRING (postal code, not a number).
--              Applies sensitive data handling per ADR-024:
--                - email: hashed (SHA-256) — no analytical value downstream,
--                  highest-risk field if exposed
--                - phone, street, city, state, zip_code: excluded entirely —
--                  never required by any downstream model
-- Source: localbike.customers
-- Depends on: source('localbike', 'customers')
-- Consumed by: int_orders__enriched
-- See also: docs/DECISIONS.md — ADR-024 (sensitive data handling)
-- =============================================================================

WITH source AS (

    -- Pull raw data from the localbike source dataset
    SELECT * FROM {{ source('localbike', 'customers') }}

),

renamed AS (

    SELECT
        -- Primary key
        customer_id,

        -- Customer name — kept in plain text: required by ops for targeted
        -- outreach (ADR-024). Protected via Metabase access control, not masking.
        first_name,
        last_name,

        -- Contact details — email hashed (ADR-024): no analytical value for
        -- LTV/basket/order-date metrics, highest exposure risk if leaked.
        -- phone excluded entirely: never required by any downstream model.
        {{ hash_pii('email') }} AS email_hash

        -- Address fields (street, city, state, zip_code) intentionally
        -- excluded — zero analytical value in any downstream model (ADR-024)

    FROM source

)

SELECT * FROM renamed
