# NEXT_STEPS.md — Local Bike dbt Project

Current priorities and task backlog.
Updated after each work session. Completed items are moved to the bottom.

---

## ✅ Done

- [x] Define project scope and architecture (CDC)
- [x] Choose dbt-core over dbt-fusion (ADR-002)
- [x] Define dev/prod dataset strategy (ADR-004, ADR-005)
- [x] Design CI/CD pipeline (ADR-006, ADR-007)
- [x] Define Git workflow and branching conventions (ADR-010)
- [x] Define documentation file strategy — `_docs/` + `.gitignore` (ADR-011)

### — Project bootstrap

- [x] **Initialise the dbt project**
  - `dbt init local_bike` (or chosen project name)
  - Pin `dbt-core` and `dbt-bigquery` versions in `requirements.txt`
  - Configure `profiles.yml` with `dev` and `prod` targets pointing to BigQuery
  - Verify connection: `dbt debug`

- [x] **Create BigQuery datasets**
  - Confirm `local_bike` source dataset is accessible (provided by DataBird)
  - Create `dbt_local_bike_dev` dataset in BigQuery (used by local dev)
  - Create `dbt_local_bike_prod` dataset in BigQuery (used by CD + Metabase)

- [x] **Configure `dbt_project.yml`**
  - Set project name, version, `model-paths`, `seed-paths`, etc.
  - Declare layer-level materialization defaults:
    - `staging/` → `view`
    - `intermediate/` → `view`
    - `mart/` → `table`
  - Enable `persist_docs` for models and columns

- [x] **Set up GitHub repository**
  - Create repo `databird-local-bike`
  - Push initial project skeleton
  - Add `.gitignore` (see `_docs/` and `CLAUDE.md` entries — cf. ADR-011)
  - Add PR template (`.github/pull_request_template.md`)

- [x] **Configure GitHub Secrets**
  - `GCP_SERVICE_ACCOUNT_KEY` — Service Account JSON with BigQuery roles
  - `DBT_PROJECT_ID` — `databird-prep-work-ae`
  - `DBT_DATASET` — `dbt_local_bike_prod` (used by CD workflow)

- [x] **Create GitHub Actions workflows**
  - `.github/workflows/ci.yml` — slim CI on `pull_request`
  - `.github/workflows/cd.yml` — full deploy on `push` to `main`
  - Run first CD manually (or via push to `main`) to bootstrap the `prod-manifest` artifact

### — Staging layer

- [x] **Declare sources** in `models/staging/localbike/_localbike__sources.yml`
  - Source name: `localbike`, database: `databird-prep-work-ae`, schema: `local_bike`
  - Declare all 9 source tables: `customers`, `orders`, `order_items`, `products`,
    `stores`, `staffs`, `brands`, `categories`, `stocks`
  - Add `loaded_at_field` if a freshness check is desired

- [x] **Install `dbt-codegen`** and use it to scaffold staging boilerplate
  - `dbt run-operation generate_source` → `_localbike__sources.yml`
  - `dbt run-operation generate_base_model` → per-source SQL draft

- [x] **Write all 9 staging models** (one per source table)
  - `stg_localbike__customers.sql` + `.yml`
  - `stg_localbike__orders.sql` + `.yml`
  - `stg_localbike__order_items.sql` + `.yml`
  - `stg_localbike__products.sql` + `.yml`
  - `stg_localbike__stores.sql` + `.yml`
  - `stg_localbike__staffs.sql` + `.yml`
  - `stg_localbike__brands.sql` + `.yml`
  - `stg_localbike__categories.sql` + `.yml`
  - `stg_localbike__stocks.sql` + `.yml`
  - Each model: light cleaning only (casts, renames, `not_null` on PKs + FKs)
  - Create `_localbike__docs.md` with docs blocks for each model

- [x] **Add staging tests**
  - `unique` + `not_null` on all PKs
  - `not_null` on critical FKs
  - `accepted_values` on `order_status` (values: `1`, `2`, `3`, `4`)
  - Verify: `dbt test --select staging`

### - Intermediate layer

- [x] **Write `int_orders__enriched`**
  - Joins: `stg_localbike__orders` + `stg_localbike__customers` + `stg_localbike__stores` + `stg_localbike__staffs`
  - `.sql` + `.yml` + docs block in `_int_sales__docs.md`

- [x] **Write `int_order_items__enriched`**
  - Joins: `stg_localbike__order_items` + `stg_localbike__products` + `stg_localbike__brands` + `stg_localbike__categories`
  - `.sql` + `.yml` + docs block

- [x] **Add intermediate tests**
  - `not_null` on join keys
  - Verify no row explosion on joins (check grain in a singular test if needed)
  - Verify: `dbt test --select intermediate`

- [x] **Refactor staging/intermediate — layer assignment cleanup**
  - Removed `order_status_label` and `days_to_ship` from `stg_localbike__orders`
  - `order_status_label` and `delivery_delay_days` now computed once in `int_orders__enriched`
  - Fixed misaligned comments in `int_orders__enriched` (residual from refactor)
  - Added ADR-017

### — Mart layer

- [x] **Write `orders` (incremental)**
  - Source: `int_orders__enriched`
  - Strategy: `merge`, `unique_key = 'order_id'`, `is_incremental()` filter on `order_date`
  - Evaluate `partition_by` (order_date) and `cluster_by` (store_id) for BigQuery
  - Four-section docs block (mart template) in `_sales__docs.md`

- [x] **Write `revenue_by_store`**
  - Source: `int_orders__enriched`
  - Grain: one row per store × month
  - Columns: `store_id`, `store_name`, `year_month`, `total_revenue`, `order_count`

- [x] **Write `revenue_by_category`**
  - Source: `int_order_items__enriched`
  - Grain: one row per category × month
  - Columns: `category_id`, `category_name`, `year_month`, `total_revenue`, `units_sold`

- [x] **Write `top_products`**
  - Source: `int_order_items__enriched`
  - Grain: one row per product
  - Columns: `product_id`, `product_name`, `brand_name`, `category_name`, `total_revenue`, `units_sold`, `revenue_rank`

- [x] **Write `customer_summary`**
  - Source: `int_orders__enriched` + `int_order_items__enriched`
  - Grain: one row per customer
  - Columns: `customer_id`, `full_name`, `order_count`, `avg_basket`, `lifetime_value`, `first_order_date`, `last_order_date`

- [x] **Add mart tests and docs**
  - `unique` + `not_null` on all PKs
  - Four-section docs block for each mart model (mandatory per CLAUDE.md)
  - Verify: `dbt test --select mart`

- [x] **Refactor mart layer — introduce `int_orders__with_revenue`**
  - Centralised revenue join logic previously duplicated across all mart models
  - DAG is now strictly linear (ADR-021)

### — Docs and hosting

- [x] Write `models/overview.md` — dbt docs homepage
- [x] Deploy dbt docs to Netlify via GitHub Actions CLI (ADR-022)
  - Live: https://local-bike-docs.jeremymarchandeau.com/
     
### — BI and presentation

- [x] **Set up Metabase locally** (Docker)
  - Connect to `dbt_local_bike_prod` in BigQuery
  - Build the 8 KPI charts (see CDC section 6.2)
  - Build a dashboard with interactive filters (store, period, category)

- [x] **Deploy Metabase on Hetzner VPS**
  - Install Metabase (Docker or JAR) on the existing Hetzner instance
  - Migrate or rebuild dashboards from local
  - Validate connection to BigQuery prod dataset

- [x] **Generate and serve dbt docs**
  - `dbt docs generate && dbt docs serve` — verify DAG is clean
  - Screenshot the full DAG for the final PR body

- [x] **Peer review**
  - Open PR on `main` with full body (context, DAG screenshot, no breaking changes)
  - Request review from a bootcamp peer
  - Address feedback, merge once approved + CI green

- [x] **Bonus — narrative analysis**
  - Identify 3–5 actionable insights from the dashboards
  - Write a short narrative (`docs/INSIGHTS.md`) for the ops team
