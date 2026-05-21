/*
  int_orders__enriched
  --------------------
  Intermediate model: enriches orders with customer, store, and staff details.

  Grain: one row per order (order_id is unique).

  Joins:
    - stg_localbike__orders        (base table)
    - stg_localbike__customers     (LEFT JOIN — customer details)
    - stg_localbike__stores        (LEFT JOIN — store details)
    - stg_localbike__staffs        (LEFT JOIN — staff details)

  LEFT JOINs are intentional: orphaned FK values are caught by
  relationships tests at the staging layer. We preserve all orders here
  rather than silently dropping rows with unresolved FKs.

  Downstream consumers:
    - mart/sales/orders.sql
    - mart/sales/revenue_by_store.sql
    - mart/sales/customer_summary.sql
*/

WITH

-- -----------------------------------------------------------------------
-- Source CTEs
-- -----------------------------------------------------------------------

orders AS (

    SELECT * FROM {{ ref('stg_localbike__orders') }}

),

customers AS (

    SELECT * FROM {{ ref('stg_localbike__customers') }}

),

stores AS (

    SELECT * FROM {{ ref('stg_localbike__stores') }}

),

staffs AS (

    SELECT * FROM {{ ref('stg_localbike__staffs') }}

),

-- -----------------------------------------------------------------------
-- Enrichment: join all four staging models
-- -----------------------------------------------------------------------

enriched AS (

    SELECT

        -- ----------------------------------------------------------------
        -- Order identifiers and status
        -- ----------------------------------------------------------------
        orders.order_id,
        orders.order_status,

        /*
          order_status_label: human-readable decode of the integer status.
          Introduced here (intermediate layer) per ADR-012.
          The raw integer is kept above for performant filtering in Metabase.
          Mapping confirmed with DataBird:
            1 = Pending | 2 = Processing | 3 = Rejected | 4 = Completed
        */
        orders.order_date,

        -- ----------------------------------------------------------------
        -- Order dates
        -- ----------------------------------------------------------------
        orders.required_date,
        orders.shipped_date,
        orders.customer_id,

        /*
          delivery_delay_days: positive = late delivery, negative = early,
          null = not yet shipped (status 1, 2, or 3).
          Computed here once; consumed by the mart's on-time KPI.
        */
        customers.first_name AS customer_first_name,

        -- ----------------------------------------------------------------
        -- Customer details (LEFT JOIN — customers)
        -- ----------------------------------------------------------------
        customers.last_name AS customer_last_name,
        customers.email AS customer_email,
        customers.phone AS customer_phone,

        /*
          full_name: convenience concat for display in Metabase.
          COALESCE guards against null first_name or last_name.
        */
        customers.city AS customer_city,

        customers.state AS customer_state,
        orders.store_id,
        stores.store_name,
        stores.city AS store_city,

        -- ----------------------------------------------------------------
        -- Store details (LEFT JOIN — stores)
        -- ----------------------------------------------------------------
        stores.state AS store_state,
        orders.staff_id,
        staffs.first_name AS staff_first_name,
        staffs.last_name AS staff_last_name,

        -- ----------------------------------------------------------------
        -- Staff details (LEFT JOIN — staffs)
        -- ----------------------------------------------------------------
        CASE orders.order_status
            WHEN 1 THEN 'Pending'
            WHEN 2 THEN 'Processing'
            WHEN 3 THEN 'Rejected'
            WHEN 4 THEN 'Completed'
        END AS order_status_label,
        DATE_DIFF(orders.shipped_date, orders.required_date, DAY)
            AS delivery_delay_days,
        CONCAT(
            COALESCE(customers.first_name, ''),
            ' ',
            COALESCE(customers.last_name, '')
        ) AS customer_full_name

    FROM orders

    LEFT JOIN customers
        ON orders.customer_id = customers.customer_id

    LEFT JOIN stores
        ON orders.store_id = stores.store_id

    LEFT JOIN staffs
        ON orders.staff_id = staffs.staff_id

)

-- -----------------------------------------------------------------------
-- Final select
-- -----------------------------------------------------------------------

SELECT * FROM enriched
