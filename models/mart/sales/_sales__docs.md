{% docs orders %}

## orders

**Layer:** Mart  
**Domain:** Sales  
**Grain:** One row per order (`order_id` is unique)  
**Materialisation:** Incremental — merge strategy on `order_id` (ADR-008)

### Purpose

Central mart model exposing one fully-enriched row per order, combining order
lifecycle data with denormalised customer, store, and staff dimensions. This is
the primary model for operations KPIs in Metabase: monthly order trends,
on-time delivery rate, and order-level drill-downs.

### Incremental strategy

| Parameter                 | Value                                    |
| ------------------------- | ---------------------------------------- |
| `unique_key`              | `order_id`                               |
| `incremental_strategy`    | `merge`                                  |
| `is_incremental()` filter | `order_date >= MAX(order_date) - 7 days` |
| `partition_by`            | `order_date` (monthly, DATE)             |
| `cluster_by`              | `store_id`, `order_status`               |

The 7-day lookback window ensures that late status updates on recent orders
(e.g. a Pending order that becomes Completed) are caught on incremental runs.  
First run: `dbt run --full-refresh --select orders`

### Derived columns

- **`is_on_time`** — `TRUE` if `shipped_date <= required_date`, `FALSE` if late,
  `NULL` if the order has not yet shipped. Drives the on-time delivery KPI.
- **`order_year_month`** — `FORMAT_DATE('%Y-%m', order_date)`. Used as the
  time axis for monthly bar charts in Metabase.
- **`delivery_delay_days`** — inherited from `int_orders__enriched`. Positive =
  late, negative = early, `NULL` = not yet shipped.

### Source

| Upstream model         | Relationship                                                                                              |
| ---------------------- | --------------------------------------------------------------------------------------------------------- |
| `int_orders__enriched` | 1-to-1 pass-through with one derived column (`is_on_time`) and one formatting column (`order_year_month`) |

### Downstream consumers

- Metabase dashboard — monthly order trend (line chart)
- Metabase dashboard — on-time vs late delivery rate (bar / KPI card)
- Metabase dashboard — operations drill-down by store and staff

{% enddocs %}
