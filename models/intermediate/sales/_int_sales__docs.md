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
