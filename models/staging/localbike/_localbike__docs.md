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

{% docs stg_localbike__order_items %}
Staging model for the `order_items` source table.

One row per order line. Each order can contain multiple lines (one per product).

**Cleaning applied:**

- `quantity` cast to `INT64`
- `list_price` and `discount` cast to `FLOAT64`
- `net_price` computed as `list_price × (1 - discount)`, rounded to 2 decimal places
- `line_revenue` computed as `net_price × quantity`, rounded to 2 decimal places

**Grain:** one row per `(order_id, item_id)`

**Note:** `list_price` reflects the price at order time — it may differ from the
current price in `stg_localbike__products`.

**Downstream:** `int_order_items__enriched`
{% enddocs %}

{% docs stg_localbike__products %}
Staging model for the `products` source table.

One row per product. Serves as the product reference catalogue for Local Bike.

**Cleaning applied:**

- `model_year` cast to `INT64`
- `list_price` cast to `FLOAT64`

**Grain:** one row per `product_id`

**Note:** `list_price` here reflects the current catalogue price.
The price actually charged on an order is captured in
`stg_localbike__order_items.list_price`.

**Downstream:** `int_order_items__enriched`
{% enddocs %}

{% docs stg_localbike__stores %}
Staging model for the `stores` source table.

One row per store. Local Bike operates three stores across the United States:
Santa Cruz (CA), Baldwin (NY), and Rowlett (TX).

**Cleaning applied:** none — all columns are already clean in the source.

**Grain:** one row per `store_id`

**Downstream:** `int_orders__enriched`
{% enddocs %}
