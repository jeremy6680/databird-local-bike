{% docs __overview__ %}

# Local Bike — Analytics Engineering Project

**Built by** [Jeremy Marchandeau](https://jeremymarchandeau.com) · DataBird Analytics Engineering Bootcamp · Apr–Jun 2026

---

## About this project

This dbt project is the first data system built for **Local Bike**, an American cycling retailer founded in 2016 by Alexander Anthony — former professional cyclist (Tour de France).

Local Bike operates three stores across the United States:

| Store      | State      | Market                             |
| ---------- | ---------- | ---------------------------------- |
| Santa Cruz | California | Road & mountain cycling            |
| Baldwin    | New York   | Families & commuters (Long Island) |
| Rowlett    | Texas      | Fast-growing market near Dallas    |

The goal of this project is to model Local Bike's raw transactional data into a clean, tested, and documented analytics layer — enabling the operations team to optimise sales and maximise revenue.

---

## Architecture

This project follows a **three-layer medallion architecture** — staging → intermediate → mart.

| Layer        | Prefix                   | Materialisation | Role                                          |
| ------------ | ------------------------ | --------------- | --------------------------------------------- |
| Staging      | `stg_<source>__<entity>` | View            | Cast, rename, defensive cleaning              |
| Intermediate | `int_<entity>__<verb>`   | View            | Joins, business logic, derived columns        |
| Mart         | `<entity>`               | Table           | Aggregations, BI-ready, connected to Metabase |

Raw source tables (BigQuery `local_bike` dataset) flow through staging views into intermediate views, then into mart tables consumed by Metabase. The `orders` mart is the only incremental model — all others are full-refresh tables.

---

## Key models

| Model                        | Layer        | Description                                                   |
| ---------------------------- | ------------ | ------------------------------------------------------------- |
| `stg_localbike__orders`      | Staging      | Orders with status cast and date cleaning                     |
| `stg_localbike__order_items` | Staging      | Order lines with quantity and price                           |
| `int_orders__enriched`       | Intermediate | Orders joined with customers, stores, staffs                  |
| `int_order_items__enriched`  | Intermediate | Order lines joined with products, brands, categories          |
| `int_orders__with_revenue`   | Intermediate | Order grain with pre-computed revenue (completed orders only) |
| `orders`                     | Mart         | Incremental model — full enriched order history               |
| `revenue_by_store`           | Mart         | Monthly revenue aggregated by store                           |
| `revenue_by_category`        | Mart         | Monthly revenue aggregated by product category                |
| `top_products`               | Mart         | Product ranking by revenue and units sold                     |
| `customer_summary`           | Mart         | Per-customer LTV, order count, average basket                 |

---

## Data quality

Every model is covered by:

- `not_null` + `unique` tests on all primary keys
- `not_null` tests on critical foreign keys
- `relationships` tests for referential integrity
- `accepted_values` on `order_status` (1 = Pending, 2 = Processing, 3 = Rejected, 4 = Completed)
- Singular tests for domain constraints (positive quantities, non-negative revenue, date consistency)
- Singular tests for join grain validation (no row explosion at intermediate layer)

---

## Stack

| Tool                 | Role                                           |
| -------------------- | ---------------------------------------------- |
| **dbt Core 1.11.10** | Transformation & documentation                 |
| **BigQuery (EU)**    | Cloud data warehouse                           |
| **Metabase**         | Business intelligence & dashboards             |
| **GitHub Actions**   | CI/CD — slim build on PR, full deploy on merge |
| **Netlify**          | dbt docs hosting                               |

---

## Live dashboard

The Metabase dashboard is publicly available at:
👉 [local-bike-data.jeremymarchandeau.com](https://local-bike-data.jeremymarchandeau.com/public/dashboard/9dc87740-46b7-47d1-88a7-13578c238598)

It connects exclusively to the `dbt_local_bike_prod_mart` dataset in BigQuery.

---

## Repository

[github.com/jeremy6680/databird-local-bike](https://github.com/jeremy6680/databird-local-bike)

{% enddocs %}
