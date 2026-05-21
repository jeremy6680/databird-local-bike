-- =============================================================================
-- Model: stg_localbike__orders
-- Layer: Staging
-- Description: Light cleaning and standardisation of the orders source table.
--              Casts all columns to their correct types.
--              Status decoding and delay computation are handled downstream
--              in int_orders__enriched.
-- Source: localbike.orders
-- Depends on: source('localbike', 'orders')
-- Consumed by: int_orders__enriched
-- =============================================================================

WITH

source AS (

    SELECT * FROM {{ source('localbike', 'orders') }}

),

renamed AS (

    SELECT

        -- -----------------------------------------------------------------------
        -- Primary key
        -- -----------------------------------------------------------------------
        order_id,

        -- -----------------------------------------------------------------------
        -- Foreign keys
        -- -----------------------------------------------------------------------
        customer_id,
        store_id,
        staff_id,

        -- -----------------------------------------------------------------------
        -- Order status
        -- Raw integer (1–4) — decoded into a label in int_orders__enriched
        -- -----------------------------------------------------------------------
        order_date,

        -- -----------------------------------------------------------------------
        -- Dates
        -- order_date and required_date are native DATE columns — no cast needed.
        -- shipped_date is STRING in source — NULLIF removes the literal 'NULL'
        -- string before SAFE_CAST converts to DATE (ADR-014).
        -- -----------------------------------------------------------------------
        required_date,
        CAST(order_status AS INT64) AS order_status,
        SAFE_CAST(NULLIF(shipped_date, 'NULL') AS DATE) AS shipped_date

    FROM source

)

SELECT * FROM renamed
