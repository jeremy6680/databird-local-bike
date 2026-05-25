# Project Specifications — DataBird Final Project

## Local Bike · Analytics Engineering Capstone

> **Author:** Jeremy Marchandeau  
> **Programme:** DataBird Analytics Engineering Bootcamp (Apr–Jun 2026)  
> **Stack:** dbt Core 1.11.10 · Python 3.11.11 · BigQuery (EU) · Metabase · GitHub Actions  
> **BigQuery project:** `databird-prep-work-ae`  
> **Repository:** [github.com/jeremy6680/databird-local-bike](https://github.com/jeremy6680/databird-local-bike)

---

## 1. Business context

**Local Bike** is an American company founded in 2016 by Alexander Anthony, a former professional cyclist (Tour de France), with the mission of democratising urban cycling in the United States.

### 1.1 Store locations

| City       | State      | Positioning                        |
| ---------- | ---------- | ---------------------------------- |
| Santa Cruz | California | Outdoor / road & mountain cycling  |
| Baldwin    | New York   | Families & commuters (Long Island) |
| Rowlett    | Texas      | Fast-growing city near Dallas      |

### 1.2 Core values

1. **Personalisation** — in-depth consultation for every customer
2. **Quality** — premium materials, solid warranties
3. **Community engagement** — local events, mechanics workshops, group rides

---

## 2. Project objective

Build Local Bike's **first data system** to enable the operations team to optimise sales and maximise revenue, through:

- A rigorous dbt data model (three-layer medallion architecture)
- Actionable KPIs exposed in a Metabase dashboard

---

## 3. Source dataset

### 3.1 Relational schema

Two logical schemas:

**Sales**

- `customers` — customer profile (id, name, contact, address)
- `orders` — orders (id, status, dates, FK to customer/store/staff)
- `order_items` — order lines (order id, item id, product, quantity, list price, discount)
- `staffs` — employees (id, name, contact, active status, FK to store/manager)
- `stores` — stores (id, name, contact, address)

**Production**

- `products` — product catalogue (id, name, brand, category, model year, list price)
- `categories` — category reference (id, name)
- `brands` — brand reference (id, name)
- `stocks` — stock levels per product and store (store_id + product_id, quantity)

### 3.2 Key relationships

```
customers ──< orders >── stores
orders     ──< order_items >── products
products   ──> categories
products   ──> brands
products   ──< stocks >── stores
staffs     ──> stores
staffs     ──> staffs (self-join manager)
orders     ──> staffs
```

---

## 4. dbt architecture

### 4.1 Naming conventions (three-layer medallion)

| Layer        | Prefix                   | Materialisation | Role                              |
| ------------ | ------------------------ | --------------- | --------------------------------- |
| Staging      | `stg_<source>__<entity>` | `view`          | Light cleaning, casting, renaming |
| Intermediate | `int_<entity>__<verb>`   | `view`          | Joins, business logic             |
| Mart         | `<entity>` (no prefix)   | `table`         | Aggregations, BI-ready            |

### 4.2 Models to build

#### Staging (views)

- `stg_localbike__customers`
- `stg_localbike__orders`
- `stg_localbike__order_items`
- `stg_localbike__products`
- `stg_localbike__stores`
- `stg_localbike__staffs`
- `stg_localbike__brands`
- `stg_localbike__categories`
- `stg_localbike__stocks`

#### Intermediate (views)

- `int_orders__enriched` — orders + customers + stores + staffs
- `int_order_items__enriched` — order_items + products + brands + categories

#### Mart (tables — connected to Metabase)

- `orders` — enriched orders, ready for analysis
- `revenue_by_store` — revenue per store and period
- `revenue_by_category` — revenue per product category
- `top_products` — product ranking by revenue / volume
- `customer_summary` — per-customer summary (LTV, order count, average basket)

#### Incremental model (required)

- **`orders`** (mart) — rationale: potentially high volume, order statuses updated regularly
  - `unique_key = 'order_id'`
  - `incremental_strategy = 'merge'` (BigQuery)
  - `is_incremental()` filter on `order_date`
  - First run: `dbt run --full-refresh --select orders`

### 4.3 Simplified DAG

```
sources
  └─ stg_localbike__*
        └─ int_orders__enriched
        │     └─ orders (mart/table)
        │     └─ revenue_by_store (mart/table)
        │     └─ customer_summary (mart/table)
        └─ int_order_items__enriched
              └─ revenue_by_category (mart/table)
              └─ top_products (mart/table)
```

### 4.4 Environments

| Environment | dbt target      | BigQuery dataset (write) | Source dataset (read) |
| ----------- | --------------- | ------------------------ | --------------------- |
| Development | `dev` (default) | `dbt_local_bike_dev`     | `local_bike`          |
| Production  | `prod`          | `dbt_local_bike_prod`    | `local_bike`          |

- The `local_bike` dataset is provided by DataBird — dbt never writes to it; it is read-only via `source()`
- Metabase connects exclusively to `dbt_local_bike_prod`
- `profiles.yml` is never committed — credentials are injected via environment variables locally and via GitHub Secrets in CI/CD
- BigQuery region: **EU**

---

## 5. dbt tests and documentation

### 5.1 Required tests

- `not_null` + `unique` on all primary keys
- `not_null` on critical foreign keys (e.g. `order_id`, `customer_id`, `product_id`)
- `relationships` to validate referential integrity (e.g. `orders.store_id` → `stores.store_id`)
- `accepted_values` on `order_status` (expected values: `1`, `2`, `3`, `4`)

> **dbt-core 1.11.10:** use `data_tests:` (not `tests:`), and the `arguments:` sub-key for FK and enum tests.

### 5.2 Documentation

Every model must have a `.yml` file with:

- A model-level description
- A description for every column
- All associated tests

---

## 6. KPIs and Metabase visualisations

### 6.1 Priority analysis dimensions

| Dimension  | Business question                                           | Source mart model                     |
| ---------- | ----------------------------------------------------------- | ------------------------------------- |
| Revenue    | What is total revenue, per store, per month?                | `revenue_by_store`                    |
| Products   | Which products / categories sell best?                      | `revenue_by_category`, `top_products` |
| Customers  | What is customer lifetime value? Who are the top customers? | `customer_summary`                    |
| Operations | What is the average order processing lead time?             | `orders`                              |
| Stock      | Which products are out of stock or overstocked?             | `stg_localbike__stocks`               |

### 6.2 KPIs to implement in Metabase

- **Total revenue** (global, filterable by store and period)
- **Revenue by store** (monthly bar chart)
- **Top 10 products** by revenue (bar chart)
- **Revenue breakdown by category** (pie / donut chart)
- **Average basket** per order and per customer
- **On-time vs late delivery rate** (`shipped_date` vs `required_date`)
- **Customer LTV** (cumulative revenue per customer)
- **Monthly order trend** (line chart)

---

## 7. Deliverables

| #   | Deliverable                                | Validation criterion                             |
| --- | ------------------------------------------ | ------------------------------------------------ |
| 1   | dbt models (staging + intermediate + mart) | All `dbt run` commands pass without error        |
| 2   | dbt tests                                  | All `dbt test` commands pass (0 failures)        |
| 3   | Full `.yml` documentation                  | Every model and column documented                |
| 4   | At least one incremental model             | `unique_key` defined, `is_incremental()` used    |
| 5   | GitHub repository                          | Clean code, branches, PR with DAG screenshot     |
| 6   | Metabase dashboard                         | Min. 5 charts covering the KPIs above            |
| 7   | Peer review                                | PR submitted and reviewed by a peer              |
| 8   | CI/CD GitHub Actions pipeline              | `ci.yml` and `cd.yml` active and green on `main` |

---

## 8. Quality checklist

Before each PR, verify:

- [ ] No raw table paths (`project.dataset.table`) — always use `ref()` or `source()`
- [ ] Materialisation is appropriate for the model's position in the DAG
- [ ] No duplicated logic across models
- [ ] Every mart model has a complete `.yml` file
- [ ] `not_null` + `unique` tests pass on all primary keys
- [ ] The incremental model has a `unique_key` and an `is_incremental()` filter
- [ ] Every SQL clause is commented
- [ ] The DAG is clean (no orphaned or redundant models)
- [ ] CI workflow passes green on the PR (slim run + test + docs on `state:modified+`)
- [ ] `manifest.json` is uploaded as an artifact after every merge to `main`

---

## 9. CI/CD — GitHub Actions

### 9.1 Overview

| Workflow               | File                       | Trigger                 | Purpose                               |
| ---------------------- | -------------------------- | ----------------------- | ------------------------------------- |
| CI — Slim build        | `.github/workflows/ci.yml` | `pull_request` → `main` | Validate modified models before merge |
| CD — Production deploy | `.github/workflows/cd.yml` | `push` on `main`        | Deploy all models + generate docs     |

### 9.2 Slim CI strategy

CI rebuilds **only modified models and their downstream dependencies** (`state:modified+`),
by comparing the PR's `manifest.json` against the production `manifest.json` stored as a GitHub Actions artifact.

This requires:

1. The CD workflow uploads `manifest.json` as a **GitHub artifact** after each successful production deployment.
2. The CI workflow downloads this artifact into `./prod-manifest/` so dbt can perform state comparison (`--state`).

### 9.3 Required GitHub Secrets

| Secret                    | Value                                                                           |
| ------------------------- | ------------------------------------------------------------------------------- |
| `GCP_SERVICE_ACCOUNT_KEY` | Full Service Account JSON (roles: `BigQuery Data Editor` + `BigQuery Job User`) |
| `DBT_PROJECT_ID`          | `databird-prep-work-ae`                                                         |
| `DBT_DATASET`             | `dbt_local_bike_prod`                                                           |

### 9.4 CI workflow — `ci.yml`

Steps on `pull_request`:

1. Checkout PR code
2. Set up Python + install `dbt-bigquery`
3. Write `profiles.yml` from secrets (via `env`)
4. Download production `manifest.json` artifact
5. `dbt deps`
6. `dbt run --select state:modified+ --defer --state ./prod-manifest/`
7. `dbt test --select state:modified+ --defer --state ./prod-manifest/`
8. `dbt docs generate` (validates that docs compile cleanly)

> **`--defer`:** for unmodified upstream models, dbt resolves `ref()` calls to production tables rather than rebuilding them — avoids rebuilding the entire DAG on every PR.

### 9.5 CD workflow — `cd.yml`

Steps on `push` to `main`:

1. Checkout `main`
2. Set up Python + install `dbt-bigquery`
3. Write `profiles.yml` from secrets
4. `dbt deps`
5. `dbt run` (full run — all models)
6. `dbt test`
7. `dbt docs generate`
8. Upload `./target/manifest.json` as GitHub artifact named `prod-manifest` (overwrites previous — `retention-days: 90`)

### 9.6 File structure

```
.github/
  workflows/
    ci.yml      # Slim CI on pull_request
    cd.yml      # Full deploy on push to main
```

> `profiles.yml` must **never** contain credentials in plain text.
> All sensitive values are read from environment variables injected by GitHub Actions.

---

## 10. Bonus

- Full Metabase dashboard with interactive filters (store, period, category)
- Narrative analysis: actionable insights and recommendations for the Local Bike ops team

> **Metabase:** developed locally via Docker, then deployed on a Hetzner VPS for the final presentation. Connects exclusively to `dbt_local_bike_prod`.
