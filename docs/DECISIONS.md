# DECISIONS.md — Local Bike dbt Project

Architecture and technical decisions log.
Every non-obvious choice made during this project is recorded here with its rationale.
Any deviation from the conventions defined in `CLAUDE.md` must appear in this file.

---

## Decision log

---

### [ADR-001] Warehouse: BigQuery

**Date:** 2026-05-20
**Status:** Decided

**Context:**
DataBird bootcamp final project is hosted on Google Cloud Platform.
The source dataset is already loaded in BigQuery under the project `databird-prep-work-ae`.

**Decision:**
Use BigQuery as the sole warehouse for this project.
No DuckDB local fallback — the dataset is hosted remotely and BigQuery is the authoritative target.

**Consequences:**

- All SQL must be BigQuery-compatible (use `TIMESTAMP`, `QUALIFY` for deduplication, etc.)
- Credentials are managed via a GCP Service Account — never hardcoded
- Partitioning / clustering to evaluate on mart tables once row counts are known

---

### [ADR-002] dbt Core — latest stable release

**Date:** 2026-05-20
**Status:** Decided

**Context:**
Initial plan was to use dbt-fusion (v2.0.0-preview), the Rust-based rewrite of dbt Core.
After evaluation, dbt-fusion is still in preview and its ecosystem compatibility
(packages, adapters, CI tooling) is not yet stable enough for a graded project.

**Decision:**
Use the latest **stable** release of `dbt-core` with the `dbt-bigquery` adapter.
Exact version to be pinned in `requirements.txt` at project init time.

**Consequences:**

- Use `data_tests:` syntax (v1.10.5+) — never the deprecated `tests:` key
- Use `arguments:` sub-key for FK (`relationships`) and enum (`accepted_values`) tests
- Full compatibility with `dbt-codegen`, `dbt-utils`, and the GitHub Actions ecosystem

---

### [ADR-003] Three-layer medallion architecture

**Date:** 2026-05-20
**Status:** Decided

**Context:**
Standard dbt architecture for analytics engineering projects.

**Decision:**
Adopt the three-layer medallion architecture as defined in `CLAUDE.md`:

- **Staging** (`stg_<source>__<entity>`) — light cleaning, renaming, casting; materialised as `view`
- **Intermediate** (`int_<entity>__<verb>`) — joins and business logic; materialised as `view`
- **Mart** (`<entity>`, no prefix) — aggregations, BI-ready; materialised as `table`

Layer defaults are declared in `dbt_project.yml`. Overrides in SQL `{{ config() }}` blocks only.

**Consequences:**

- No mart model may reference a `source()` directly — always through staging
- No intermediate model is exposed as a BI artifact
- Materialisation changes require explicit justification in this file

---

### [ADR-004] Two BigQuery datasets — dev / prod separation

**Date:** 2026-05-20
**Status:** Decided

**Context:**
Need to isolate development work from the production dataset used by Metabase dashboards.

**Decision:**

| Environment | dbt target | Output dataset        | Source dataset (read-only) |
| ----------- | ---------- | --------------------- | -------------------------- |
| Development | `dev`      | `dbt_local_bike_dev`  | `local_bike`               |
| Production  | `prod`     | `dbt_local_bike_prod` | `local_bike`               |

The source dataset `local_bike` is provided by DataBird and is never written to by dbt.
It is declared via `source()` in `_localbike__sources.yml`.

`profiles.yml` uses environment variable interpolation to switch targets:

```yaml
local_bike:
  target: dev
  outputs:
    dev:
      type: bigquery
      dataset: dbt_local_bike_dev
      ...
    prod:
      type: bigquery
      dataset: dbt_local_bike_prod
      ...
```

**Consequences:**

- `profiles.yml` is never committed — managed via environment variables and GitHub Secrets
- Metabase connects exclusively to `dbt_local_bike_prod`
- Local development runs against `dbt_local_bike_dev` by default

---

### [ADR-005] Source data location — dedicated `local_bike` dataset

**Date:** 2026-05-20
**Status:** Decided

**Context:**
Question arose: should source tables live in `dbt_local_bike_prod`, or in a separate dataset?

**Decision:**
Source tables live in a **dedicated, separate dataset** (`local_bike`) that dbt never writes to.
This is the standard best practice — it enforces a clean boundary between raw/source data
and dbt-managed transformed data, and makes the lineage immediately legible.

**Rule:** dbt reads from `local_bike` (via `source()`), writes to `dbt_local_bike_dev` or
`dbt_local_bike_prod` (via `ref()`). These two concerns never share a dataset.

---

### [ADR-006] CI/CD via GitHub Actions — Slim CI + Full CD

**Date:** 2026-05-20
**Status:** Decided

**Context:**
Need automated validation on PRs and automated deployment on merge to `main`.

**Decision:**
Two GitHub Actions workflows:

| Workflow | File                       | Trigger                 | Scope                                  |
| -------- | -------------------------- | ----------------------- | -------------------------------------- |
| CI       | `.github/workflows/ci.yml` | `pull_request` → `main` | Slim: `state:modified+` with `--defer` |
| CD       | `.github/workflows/cd.yml` | `push` on `main`        | Full: all models + tests + docs        |

**Slim CI strategy:**

- CD uploads `manifest.json` as a GitHub Actions artifact (`prod-manifest`, 90-day retention)
- CI downloads this artifact and uses it as `--state` reference for `state:modified+` selection
- `--defer` resolves unmodified upstream `ref()` calls to prod tables — no need to rebuild the full DAG on every PR

**Steps per workflow:**

- CI: `dbt deps` → `dbt run --select state:modified+ --defer --state` → `dbt test --select state:modified+ --defer --state` → `dbt docs generate`
- CD: `dbt deps` → `dbt run` → `dbt test` → `dbt docs generate` → upload `manifest.json`

**Consequences:**

- Three GitHub Secrets required: `GCP_SERVICE_ACCOUNT_KEY`, `DBT_PROJECT_ID`, `DBT_DATASET`
- `profiles.yml` is never committed — written at runtime from secrets
- First CD run bootstraps the artifact; CI will fail on an empty `prod-manifest` artifact until the first CD has run

---

### [ADR-007] dbt run + dbt test + dbt docs generate — separate steps

**Date:** 2026-05-20
**Status:** Decided

**Context:**
Alternative: use `dbt build` (runs + tests in one command).

**Decision:**
Run `dbt run`, `dbt test`, and `dbt docs generate` as **separate steps** in both CI and CD.

**Rationale:**

- Separate steps produce clearer failure signals in GitHub Actions logs:
  a failing model and a failing test are easier to diagnose as distinct steps
- `dbt docs generate` step confirms docs compile cleanly without mixing it into the build signal
- Slightly more verbose but significantly more readable CI output

---

### [ADR-008] Incremental model — `orders`

**Date:** 2026-05-20
**Status:** Decided

**Context:**
Project requires at least one incremental model. `orders` is the highest-volume table
and is updated regularly as order statuses change.

**Decision:**
Materialise `orders` (mart layer) as `incremental` with:

- `unique_key = 'order_id'`
- `incremental_strategy = 'merge'` (BigQuery)
- `is_incremental()` filter on `order_date`

**Consequences:**

- First run requires `--full-refresh`; this must be noted in any PR that touches `orders`
- PR body must include a note if a `--full-refresh` is required (e.g., schema change)

---

### [ADR-009] Metabase — local dev, then VPS (Hetzner) for presentation

**Date:** 2026-05-20
**Status:** Decided

**Context:**
Need a BI tool to expose mart models as dashboards.

**Decision:**

- **Development:** run Metabase locally via Docker for dashboard iteration
- **Production / presentation:** deploy Metabase on Hetzner VPS (same infra as other Web2Data services)
- Metabase connects exclusively to the `dbt_local_bike_prod` dataset in BigQuery

**Consequences:**

- Metabase Docker setup is not part of the dbt repo — documented separately
- Dashboards must be rebuilt or migrated from local to the VPS instance before the project presentation

---

### [ADR-010] Git workflow — branch naming and commit conventions

**Date:** 2026-05-20
**Status:** Decided

**Context:**
Following the DataBird dbt Git guide and Web2Data conventions.

**Decision:**

- **Branch naming:** `feature/<name>`, `fix/<name>`, `refactor/<name>`
- **Commits:** imperative mood, lowercase, no trailing period ("add stg_localbike\_\_orders model")
- **PRs:** one functional grouping per PR; body includes DAG screenshot, context, breaking changes, special merge instructions
- **Merge:** author merges after ≥1 approval and all CI checks green
- **Draft PRs:** used for WIP / peer collaboration before the code is review-ready

---

### [ADR-011] Documentation file strategy — committed `docs/` vs git-ignored `_docs/`

**Date:** 2026-05-20
**Status:** Decided

**Context:**
Two categories of documentation exist in this project:

- **Public deliverables** — intended for peer reviewers, DataBird evaluators, and GitHub visitors
- **Internal working files** — Claude AI context, personal task tracking, architectural notes

**Decision:**

| File              | Location | Committed                 |
| ----------------- | -------- | ------------------------- |
| SPECIFICATIONS.md | `docs/`  | ✅ Yes                    |
| DECISIONS.md      | `docs/`  | ✅ Yes                    |
| NEXT_STEPS.md     | `docs/`  | ✅ Yes                    |
| STRUCTURE.md      | `docs/`  | ✅ Yes                    |
| CLAUDE.md         | root     | ❌ No — Claude AI context |

`_docs/` and `CLAUDE.md` are added to `.gitignore`.
`docs/` is committed and visible in the public repository.

**Consequences:**

- Internal files are maintained locally and never pushed to GitHub
- `STRUCTURE.md` will be generated after `dbt init` once the actual folder tree exists
- The public repo presents `docs/specifications.md` as the single source of truth for project scope

**Update — 2026-05-20:** DECISIONS.md, NEXT_STEPS.md and STRUCTURE.md were moved
from `_docs/` to `docs/` and are now committed to the repository.
Rationale: these files provide useful context for peer reviewers and DataBird
evaluators. The distinction between "internal" and "public" documentation was
not meaningful enough to justify keeping them git-ignored.
The `_docs/` folder and its `.gitignore` entry have been removed.

---

### [ADR-012] order_status labels — confirmed mapping

**Date:** 2026-05-21
**Status:** Decided

**Context:**
order_status values 1, 2, 3 all have shipped_date = NULL and cannot be
distinguished by data inference alone. Mapping was unconfirmed at staging layer build time.

**Decision:**
Confirmed with DataBird. The mapping is:

| Value | Label      |
| ----- | ---------- |
| 1     | Pending    |
| 2     | Processing |
| 3     | Rejected   |
| 4     | Completed  |

Applied in `stg_localbike__orders` as a `CASE WHEN` expression on `order_status`.
Rationale: the mapping is a stable, documented source-level decode (equivalent
to a cast or rename) with no business logic — appropriate for the staging layer.

```sql
CASE order_status
    WHEN 1 THEN 'Pending'
    WHEN 2 THEN 'Processing'
    WHEN 3 THEN 'Rejected'
    WHEN 4 THEN 'Completed'
END AS order_status_label
```

The raw integer `order_status` is preserved alongside the label column
to keep filtering performant in Metabase.

**Consequences:**

- `accepted_values` test on `order_status` in staging remains on integers (1, 2, 3, 4)
- The label column is introduced at the intermediate layer — never in staging
- Mart models downstream of `int_orders__enriched` expose `order_status_label` directly

---

### [ADR-013] accepted_values on integer columns — quote: false required

**Date:** 2026-05-20
**Status:** Decided

**Context:**
dbt's `accepted_values` test quotes values as strings by default.
When the column is cast to INT64 (e.g. `order_status`), BigQuery throws:
`No matching signature for operator IN for argument types INT64 and {STRING}`

**Decision:**
Always add `quote: false` to `accepted_values` tests on integer columns.

**Example:**

```yaml
- accepted_values:
    arguments:
      values: [1, 2, 3, 4]
      quote: false
```

**Affected models:** any staging model with an integer status/code column.

---

### [ADR-014] SAFE_CAST for STRING-to-INT64 FK columns

**Date:** 2026-05-20
**Status:** Decided

**Context:**
Some FK columns are stored as STRING in the source (e.g. `staffs.manager_id`).
Using `CAST(manager_id AS INT64)` causes BigQuery to fail on the dbt
`relationships` test with "Bad int64 value: NULL".
Root cause: BigQuery evaluates the cast at join time, after the IS NOT NULL
filter, on the raw STRING values.

**Decision:**
Use `SAFE_CAST` instead of `CAST` for any STRING column that represents
a numeric FK. `SAFE_CAST` returns NULL on conversion failure instead of
throwing an error.

**Affected models:** `stg_localbike__staffs.manager_id` — to watch for on
any other STRING FK columns.

**Extension — 2026-05-20 — mixed DATE/STRING columns in the same source table:**
`order_date` and `required_date` are native DATE columns in the source — no cast needed.
`shipped_date` alone is stored as STRING and requires `SAFE_CAST(NULLIF(shipped_date, 'NULL') AS DATE)`.
Never apply `NULLIF(col, 'NULL')` on a native DATE column — BigQuery attempts to cast the
comparison string `'NULL'` to DATE at query time and throws `Could not cast literal "NULL" to type DATE`.
Rule: always verify the actual BigQuery column type before applying defensive STRING casting patterns.

---

### [ADR-015] Schema separation for intermediate and mart layers

**Date:** 2026-05-21
**Status:** Decided

**Context:**
By default, dbt writes all models to the same dataset (e.g. `dbt_local_bike_dev`).
Adding `+schema` per layer in `dbt_project.yml` creates separate BigQuery datasets
per layer.

**Decision:**
Add `+schema` for intermediate and mart layers in `dbt_project.yml`:

- `intermediate` → `dbt_local_bike_dev_intermediate` / `dbt_local_bike_prod_intermediate`
- `mart` → `dbt_local_bike_dev_mart` / `dbt_local_bike_prod_mart`

Staging already had `+schema: staging` from project init.

**Consequences:**

- Metabase connects exclusively to the `_mart` dataset — no risk of exposing
  intermediate views
- BigQuery console shows a clear visual separation between layers
- dbt creates missing datasets automatically at run time if the service account
  has `bigquery.datasets.create` rights

---

### [ADR-016] Singular tests strategy

**Date:** 2026-05-21
**Status:** Decided

**Context:**
Generic dbt tests (`unique`, `not_null`, `accepted_values`, `relationships`)
validate column-level constraints but cannot detect certain classes of data
quality issues that require cross-model or multi-condition logic.

**Decision:**
Add singular tests for two distinct purposes:

#### 1. Staging — domain-specific data quality

Tests that encode business rules not expressible as generic tests:

| Test file                                 | Validates                                                                       |
| ----------------------------------------- | ------------------------------------------------------------------------------- |
| `assert_order_items_positive_values.sql`  | `quantity > 0`, `list_price > 0`, `discount` between 0 and 1 on all order lines |
| `assert_stocks_non_negative_quantity.sql` | `quantity >= 0` on all stock records                                            |
| `assert_orders_date_consistency.sql`      | `order_date <= required_date`, and `shipped_date >= order_date` when not null   |

#### 2. Intermediate — join grain validation

Tests that detect row explosion caused by unexpected one-to-many relationships
introduced during joins:

| Test file                                     | Validates                                                                      |
| --------------------------------------------- | ------------------------------------------------------------------------------ |
| `assert_int_orders_no_row_explosion.sql`      | `int_orders__enriched` row count = `stg_localbike__orders` row count           |
| `assert_int_order_items_no_row_explosion.sql` | `int_order_items__enriched` row count = `stg_localbike__order_items` row count |

**Rationale:**

- Staging singular tests catch invalid source data that would silently corrupt
  revenue calculations downstream (negative quantities, out-of-range discounts)
- Intermediate singular tests catch join fanout, which would multiply rows and
  corrupt all downstream aggregations (revenue totals, order counts, LTV)

**Convention:**

- Any new staging model with numeric business-critical columns should have a
  singular test validating their domain constraints
- Any new intermediate model that performs joins must have a corresponding
  row explosion singular test in `tests/`
