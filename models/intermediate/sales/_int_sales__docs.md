{% docs int_orders__enriched %}

## int_orders\_\_enriched

**Layer:** Intermediate  
**Domain:** Sales  
**Grain:** One row per order (`order_id` is unique)

### Purpose

Enriches the orders staging model with denormalised customer, store, and staff
attributes. This model is the single source of truth for any mart model that
needs order-level data combined with dimensional context.

### Joins

| Joined model               | Join type | Join key      |
| -------------------------- | --------- | ------------- |
| stg_localbike\_\_customers | LEFT JOIN | `customer_id` |
| stg_localbike\_\_stores    | LEFT JOIN | `store_id`    |
| stg_localbike\_\_staffs    | LEFT JOIN | `staff_id`    |

LEFT JOINs are used deliberately: referential integrity is validated by
`relationships` tests at the staging layer. Using LEFT JOINs here ensures that
no orders are silently dropped if a FK is orphaned.

### Business logic

- **`order_status_label`** — human-readable decode of the integer `order_status`
  column. Mapping confirmed with DataBird (ADR-012):
  `1=Pending`, `2=Processing`, `3=Rejected`, `4=Completed`.
  The raw integer is preserved for performant filtering.
- **`delivery_delay_days`** — computed as `shipped_date - required_date` in days.
  Positive values indicate late delivery. Null when the order has not been shipped.

### Downstream consumers

- `mart/sales/orders` (incremental)
- `mart/sales/revenue_by_store`
- `mart/sales/customer_summary`

{% enddocs %}

{% docs int_order_items__enriched %}

## int_order_items\_\_enriched

**Layer:** Intermediate  
**Domain:** Sales  
**Grain:** One row per order line (`order_id` + `item_id` is unique)

### Purpose

Enriches order items with denormalised product, brand, and category attributes.
Computes `line_revenue` — the canonical effective revenue metric used by all
downstream product and category mart models.

### Joins

| Joined model                | Join type | Join key      |
| --------------------------- | --------- | ------------- |
| stg_localbike\_\_products   | LEFT JOIN | `product_id`  |
| stg_localbike\_\_brands     | LEFT JOIN | `brand_id`    |
| stg_localbike\_\_categories | LEFT JOIN | `category_id` |

Note: brands and categories are reached via products — there is no direct FK
from order_items to brands or categories.

### Business logic

- **`line_revenue`** — effective revenue per order line after discount:
  `quantity * list_price * (1 - discount)`, rounded to 2 decimal places.
  This is the single canonical revenue metric for all product/category marts.
  Never recompute this formula downstream — always reference `line_revenue`.

### Downstream consumers

- `mart/sales/revenue_by_category`
- `mart/sales/top_products`
- `mart/sales/customer_summary`

{% enddocs %}

{% docs int_orders__with_revenue %}

## int_orders\_\_with_revenue

**Layer:** Intermediate  
**Grain:** One row per order (`order_id`)  
**Materialisation:** view

### Purpose

Joins `int_orders__enriched` with `int_order_items__enriched` to produce a
single intermediate model that carries both order dimensions and pre-computed
order-level revenue metrics.

This model was introduced to eliminate duplicated join logic that previously
existed in every mart model. All mart models that need revenue now depend
exclusively on this model — none of them join the two intermediate models
directly.

### Revenue rule

Only completed orders (`order_status = 4`) produce a non-NULL `order_revenue`.
All other orders are preserved with `order_revenue = NULL` so that mart models
can compute both activity metrics (all statuses) and financial metrics
(completed only) from a single source.

### Key columns

| Column             | Description                                                 |
| ------------------ | ----------------------------------------------------------- |
| `order_id`         | Primary key                                                 |
| `order_revenue`    | Total order revenue after discounts — NULL if not completed |
| `order_units_sold` | Total units across all lines — NULL if not completed        |
| `order_line_count` | Number of product lines — populated for all statuses        |

### Upstream dependencies

- `int_orders__enriched`
- `int_order_items__enriched`

### Downstream consumers

- `mart/sales/orders.sql`
- `mart/sales/revenue_by_store.sql`
- `mart/sales/revenue_by_category.sql`
- `mart/sales/top_products.sql`
- `mart/sales/customer_summary.sql`

{% enddocs %}
