-- =============================================================================
-- Model: stg_localbike__orders
-- Layer: Staging
-- Description: Light cleaning and standardisation of the orders source table.
--              Casts all columns to their correct types, decodes order_status
--              into a human-readable label, and computes a shipping delay
--              column used by downstream KPI models.
-- Source: localbike.orders
-- Depends on: source('localbike', 'orders')
-- Consumed by: int_orders__enriched
-- =============================================================================

WITH

source AS (

    -- Pull all raw rows from the orders source table
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
        -- Integer in source (1–4); decoded into a human-readable label.
        -- 1 = Pending, 2 = Processing, 3 = Rejected, 4 = Completed
        -- Reference: DataBird dataset documentation
        -- -----------------------------------------------------------------------
        CAST(order_status AS INT64) AS order_status,

        CASE CAST(order_status AS INT64)
            WHEN 1 THEN 'Status_1'  -- TODO: confirm label with DataBird
            WHEN 2 THEN 'Status_2'  -- TODO: confirm label with DataBird
            WHEN 3 THEN 'Status_3'  -- TODO: confirm label with DataBird
            WHEN 4 THEN 'Completed' -- confirmed: shipped_date always present
            ELSE 'Unknown'
        END AS order_status_label,

        -- -----------------------------------------------------------------------
        -- Dates — cast to DATE (source may store as STRING or TIMESTAMP)
        -- -----------------------------------------------------------------------
        CAST(order_date AS DATE) AS order_date,
        CAST(required_date AS DATE) AS required_date,

        -- shipped_date is nullable: an order may not yet have shipped
        CAST(shipped_date AS DATE) AS shipped_date,

        -- -----------------------------------------------------------------------
        -- Derived column: shipping delay in calendar days
        -- Positive value = shipped after the required date (late)
        -- Negative value = shipped before the required date (on time)
        -- NULL when shipped_date is null (order not yet shipped)
        -- Used by the orders mart for the on-time delivery KPI
        -- -----------------------------------------------------------------------
        DATE_DIFF(
            CAST(shipped_date AS DATE),
            CAST(required_date AS DATE),
            DAY
        ) AS days_to_ship

    FROM source

)

SELECT * FROM renamed
