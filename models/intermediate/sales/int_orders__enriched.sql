/*
  int_orders__enriched
  --------------------
  Intermediate model: enriches orders with customer, store, and staff details.
  Also computes derived columns (order_status_label, delivery_delay_days,
  customer_full_name) that require either business logic or multi-table context.

  Grain: one row per order (order_id is unique).

  Sensitive data handling (ADR-024):
    - customer_email: arrives pre-hashed from stg_localbike__customers,
      exposed here as customer_email_hash — never raw past staging
    - customer_phone: removed entirely — dropped at staging, no downstream
      model required it
    - customer_city / customer_state: removed — combined with
      customer_full_name, precise customer-level geography increases
      re-identification risk with no stated business use case
    - customer_full_name: kept — legitimate ops use case (targeted
      outreach), protected via Metabase access control rather than masking

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
        -- Order identifiers
        -- ----------------------------------------------------------------
        orders.order_id,

        -- ----------------------------------------------------------------
        -- Order status
        -- Raw integer kept for performant filtering in Metabase.
        -- Label decoded here (intermediate layer) per ADR-012.
        -- ----------------------------------------------------------------
        orders.order_status,

        CASE orders.order_status
            WHEN 1 THEN 'Pending'
            WHEN 2 THEN 'Processing'
            WHEN 3 THEN 'Rejected'
            WHEN 4 THEN 'Completed'
        END AS order_status_label,

        -- ----------------------------------------------------------------
        -- Order dates
        -- ----------------------------------------------------------------
        orders.order_date,
        orders.required_date,

        -- NULL for orders not yet shipped (status 1, 2, or 3)
        orders.shipped_date,

        -- Delivery delay in calendar days:
        --   positive = late, negative = early, NULL = not yet shipped
        DATE_DIFF(orders.shipped_date, orders.required_date, DAY)
            AS delivery_delay_days,

        -- ----------------------------------------------------------------
        -- Customer details (LEFT JOIN)
        -- ----------------------------------------------------------------
        orders.customer_id,
        customers.first_name AS customer_first_name,
        customers.last_name  AS customer_last_name,

        -- Full name concatenated here — requires both first and last name
        CONCAT(
            COALESCE(customers.first_name, ''),
            ' ',
            COALESCE(customers.last_name, '')
        ) AS customer_full_name,

        -- Hashed at staging (ADR-024) — never raw past this point
        customers.email_hash AS customer_email_hash,

        -- ----------------------------------------------------------------
        -- Store details (LEFT JOIN)
        -- ----------------------------------------------------------------
        orders.store_id,
        stores.store_name,
        stores.city  AS store_city,
        stores.state AS store_state,

        -- ----------------------------------------------------------------
        -- Staff details (LEFT JOIN)
        -- ----------------------------------------------------------------
        orders.staff_id,
        staffs.first_name AS staff_first_name,
        staffs.last_name  AS staff_last_name

    FROM orders

    LEFT JOIN customers
        ON orders.customer_id = customers.customer_id

    LEFT JOIN stores
        ON orders.store_id = stores.store_id

    LEFT JOIN staffs
        ON orders.staff_id = staffs.staff_id

)

SELECT * FROM enriched