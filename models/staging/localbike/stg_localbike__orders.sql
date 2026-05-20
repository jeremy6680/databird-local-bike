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

with

source as (

    -- Pull all raw rows from the orders source table
    select * from {{ source('localbike', 'orders') }}

),

renamed as (

    select

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
        cast(order_status as INT64) as order_status,

        case cast(order_status as INT64)
            when 1 then 'Status_1'  -- TODO: confirm label with DataBird
            when 2 then 'Status_2'  -- TODO: confirm label with DataBird
            when 3 then 'Status_3'  -- TODO: confirm label with DataBird
            when 4 then 'Completed' -- confirmed: shipped_date always present
            else 'Unknown'
        end as order_status_label,

        -- -----------------------------------------------------------------------
        -- Dates — cast to DATE (source may store as STRING or TIMESTAMP)
        -- -----------------------------------------------------------------------
        cast(order_date    as DATE) as order_date,
        cast(required_date as DATE) as required_date,

        -- shipped_date is nullable: an order may not yet have shipped
        cast(shipped_date  as DATE) as shipped_date,

        -- -----------------------------------------------------------------------
        -- Derived column: shipping delay in calendar days
        -- Positive value = shipped after the required date (late)
        -- Negative value = shipped before the required date (on time)
        -- NULL when shipped_date is null (order not yet shipped)
        -- Used by the orders mart for the on-time delivery KPI
        -- -----------------------------------------------------------------------
        date_diff(
            cast(shipped_date  as DATE),
            cast(required_date as DATE),
            day
        ) as days_to_ship

    from source

)

select * from renamed