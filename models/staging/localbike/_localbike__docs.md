{% docs stg_localbike__orders %}
Staging model for the `orders` source table.

One row per order. Covers all orders placed across the three Local Bike stores
(Santa Cruz, Baldwin, Rowlett) from 2016 onwards.

**Cleaning applied:**

- `order_status` cast to `INT64`; decoded into `order_status_label` (1 / 2 / 3 / Completed)
- `order_date`, `required_date`, `shipped_date` cast to `DATE`
- `days_to_ship` computed as `DATE_DIFF(shipped_date, required_date, DAY)` — used for on-time delivery KPIs

**Grain:** one row per `order_id`

**Downstream:** `int_orders__enriched`
{% enddocs %}
