{% docs stg_localbike__customers %}
Staging model for the `customers` source table.

One row per customer. Light cleaning plus sensitive data handling — no
joins, no aggregations.

**Cleaning applied:**

- `email` hashed (SHA-256) via the `hash_pii` macro

**Sensitive data handling (ADR-024):**

- `email` → exposed as `email_hash`, never raw past this layer
- `phone`, `street`, `city`, `state`, `zip_code` → excluded entirely, no
  downstream model requires them
- `first_name` / `last_name` → kept in plain text (legitimate ops use
  case), protected via Metabase access control rather than masking

**Grain:** one row per `customer_id`

**Downstream:** `int_orders__enriched`
{% enddocs %}

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

{% docs stg_localbike__staffs %}
Staging model for the `staffs` source table.

One row per staff member across all three Local Bike stores (10 total).

**Cleaning applied:**

- `active` cast to `BOOL`
- `active_label` derived as 'Active' / 'Inactive'
- `full_name` computed as `CONCAT(first_name, ' ', last_name)`
- `manager_id` cast via `SAFE_CAST` (source is STRING — see ADR-014)

**Grain:** one row per `staff_id`

**Org chart (as of source data):**
Fabiola Jackson (#1) — General Manager
├── Mireya Copeland (#2) — Store 1 (Santa Cruz)
│ ├── Genna Serrano (#3)
│ └── Virgie Wiggins (#4)
├── Jannette David (#5) — Store 2 (Baldwin)
│ ├── Marcelene Boyer (#6)
│ └── Venita Daniel (#7)
│ ├── Layla Terrell (#9)
│ └── Bernardine Houston (#10)
└── Kali Vargas (#8) — Store 3 (Rowlett)

**Downstream:** `int_orders__enriched`
{% enddocs %}

{% docs stg_localbike__brands %}
Staging model for the `brands` source table.

One row per brand. Reference table for the product catalogue.

**Cleaning applied:** none.

**Grain:** one row per `brand_id`

**Downstream:** `int_order_items__enriched` (via `stg_localbike__products`)
{% enddocs %}

{% docs stg_localbike__categories %}
Staging model for the `categories` source table.

One row per product category. Reference table for the product catalogue.

**Cleaning applied:** none.

**Grain:** one row per `category_id`

**Downstream:** `int_order_items__enriched` (via `stg_localbike__products`)
{% enddocs %}

{% docs stg_localbike__stocks %}
Staging model for the `stocks` source table.

One row per store × product combination. Represents current stock levels
across all three Local Bike stores.

**Cleaning applied:**

- `quantity` cast to `INT64`

**Grain:** one row per `(store_id, product_id)`

**Note:** this model is consumed directly by Metabase for stock analysis
(out-of-stock and overstock KPIs) — no intermediate model is required
since no joins are needed for this use case.

**Downstream:** mart layer (direct Metabase connection)
{% enddocs %}
