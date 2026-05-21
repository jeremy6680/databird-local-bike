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

{% docs revenue_by_store %}

## revenue_by_store

**Layer:** Mart | **Materialisation:** table | **Grain:** one row per store × calendar month

### Purpose

Aggregates completed order revenue and order counts by store and calendar month.
This is the primary model powering the monthly revenue bar chart and store
comparison KPIs in Metabase.

### Business logic

- Only **completed orders** (order_status = 4) contribute to revenue figures.
  Pending, Processing, and Rejected orders are excluded.
- Revenue per order line is computed as:
  `list_price × quantity × (1 - discount)`
- Line-level revenue is summed at order level, then aggregated by store × month.

### Grain

One row per `store_id` × `order_year_month`.
Uniqueness is enforced by the `dbt_utils.unique_combination_of_columns` test.

### Upstream dependencies

| Model                       | Role                                      |
| --------------------------- | ----------------------------------------- |
| `int_orders__enriched`      | Store dimensions and order_year_month     |
| `int_order_items__enriched` | Line-level pricing (list_price, discount) |

### Downstream consumers

- Metabase — Revenue by store (monthly bar chart)
- Metabase — Total revenue KPI (filterable by store and period)

{% enddocs %}

{% docs revenue_by_category %}

## revenue_by_category

**Layer:** Mart | **Materialisation:** table | **Grain:** one row per category × calendar month

### Purpose

Aggregates completed order revenue and units sold by product category and
calendar month. Powers the revenue breakdown by category (pie/donut chart)
and category trend KPIs in Metabase.

### Business logic

- Only **completed orders** (order_status = 4) contribute to revenue figures.
- Revenue per order line: `list_price × quantity × (1 - discount)`
- A single order can span multiple categories — `order_count` uses
  `COUNT(DISTINCT order_id)` to avoid double-counting.

### Grain

One row per `category_id` × `order_year_month`.
Uniqueness enforced by `dbt_utils.unique_combination_of_columns`.

### Upstream dependencies

| Model                       | Role                                        |
| --------------------------- | ------------------------------------------- |
| `int_order_items__enriched` | Line-level pricing, quantity, category dims |
| `int_orders__enriched`      | Order status filter and order_date          |

### Downstream consumers

- Metabase — Revenue breakdown by category (pie/donut chart)
- Metabase — Category trend (monthly line chart)

{% enddocs %}

{% docs top_products %}

## top_products

**Layer:** Mart | **Materialisation:** table | **Grain:** one row per product (all-time)

### Purpose

Ranks all products by total revenue across all completed orders.
Powers the Top 10 products bar chart in Metabase.

### Business logic

- Only **completed orders** (order_status = 4) contribute to revenue figures.
- Revenue per order line: `list_price × quantity × (1 - discount)`
- Ranking uses `DENSE_RANK()` — no gaps if two products share the same revenue.
- No time dimension — this is an all-time ranking. For monthly trends, use
  `revenue_by_category`.

### Grain

One row per `product_id`. Uniqueness enforced by `unique` + `not_null` tests.

### Upstream dependencies

| Model                       | Role                                       |
| --------------------------- | ------------------------------------------ |
| `int_order_items__enriched` | Line-level pricing, quantity, product dims |
| `int_orders__enriched`      | Order status filter                        |

### Downstream consumers

- Metabase — Top 10 products by revenue (bar chart)

{% enddocs %}
