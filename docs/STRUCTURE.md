# STRUCTURE.md — Local Bike dbt Project

Folder and file structure of the project.
Updated after each significant structural change.
It reflects the full local project layout, including files not committed to GitHub.

---

## Project root

```
local_bike/
│
├── .github/                          # GitHub configuration (committed)
│   └── workflows/
│       ├── ci.yml                    # Slim CI — triggers on pull_request → main
│       └── cd.yml                    # Full deploy — triggers on push to main
│
├── analyses/                         # Ad-hoc SQL queries (not materialised by dbt)
│
├── docs/                             # ✅ committed — public project deliverables
│   ├── DECISIONS.md                  # Architecture and technical decisions log (ADRs)
│   ├── NEXT_STEPS.md                 # Current priorities and task backlog
│   ├── STRUCTURE.md                  # This file
│   └── SPECIFICATIONS.md             # Project specifications (scope, architecture, KPIs)
│
├── logs/                             # ❌ git-ignored — dbt runtime logs
│
├── macros/                           # Reusable Jinja macros
│   └── tests/                        # Custom generic test macros (if needed)
│
├── models/                           # dbt models — three-layer medallion architecture
│   ├── overview.md                   # Custom dbt docs site overview page
│   │
│   ├── staging/                      # Layer 1 — source-conformed, one model per source table
│   │   └── localbike/                # Subfolder per source system
│   │       ├── _localbike__sources.yml   # Source declarations (dataset: local_bike)
│   │       ├── _localbike__docs.md       # Long-form docs blocks for all staging models
│   │       ├── stg_localbike__customers.sql
│   │       ├── stg_localbike__customers.yml
│   │       ├── stg_localbike__orders.sql
│   │       ├── stg_localbike__orders.yml
│   │       ├── stg_localbike__order_items.sql
│   │       ├── stg_localbike__order_items.yml
│   │       ├── stg_localbike__products.sql
│   │       ├── stg_localbike__products.yml
│   │       ├── stg_localbike__stores.sql
│   │       ├── stg_localbike__stores.yml
│   │       ├── stg_localbike__staffs.sql
│   │       ├── stg_localbike__staffs.yml
│   │       ├── stg_localbike__brands.sql
│   │       ├── stg_localbike__brands.yml
│   │       ├── stg_localbike__categories.sql
│   │       ├── stg_localbike__categories.yml
│   │       ├── stg_localbike__stocks.sql
│   │       └── stg_localbike__stocks.yml
│   │
│   ├── intermediate/                 # Layer 2 — joins and business logic
│   │   └── sales/                    # Subfolder per business domain
│   │       ├── _int_sales__docs.md       # Long-form docs blocks for intermediate models
│   │       ├── int_orders__enriched.sql
│   │       ├── int_orders__enriched.yml
│   │       ├── int_order_items__enriched.sql
│   │       ├── int_order_items__enriched.yml
│   │       ├── int_orders__with_revenue.sql  # Order grain + pre-computed revenue
│   │       └── int_orders__with_revenue.yml
│   │
│   └── mart/                         # Layer 3 — aggregated, BI-ready tables
│       └── sales/                    # Subfolder per business domain
│           ├── _sales__docs.md           # Long-form docs blocks (four-section template)
│           ├── orders.sql                # Incremental model (unique_key: order_id)
│           ├── orders.yml
│           ├── revenue_by_store.sql
│           ├── revenue_by_store.yml
│           ├── revenue_by_category.sql
│           ├── revenue_by_category.yml
│           ├── top_products.sql
│           ├── top_products.yml
│           ├── customer_summary.sql
│           └── customer_summary.yml
│
├── seeds/                            # Small, static, dbt-managed reference CSVs (dbt seed)
│
├── snapshots/                        # SCD Type 2 snapshots (not used in this project)
│
├── target/                           # ❌ git-ignored — compiled dbt artifacts (generated)
│   └── manifest.json                 # Used by CI for state:modified+ comparison
│
├── tests/                            # Singular (one-off) data tests
│
├── .gitignore                        # ✅ committed
├── netlify.toml                      # ✅ committed — disables Netlify auto-build (docs deployed via CD)
├── dbt_project.yml                   # ✅ committed — project config, materialisation defaults
├── packages.yml                      # ✅ committed — dbt package dependencies (dbt-utils, codegen)
├── profiles.yml                      # ❌ git-ignored — connection profiles (credentials via env vars)
├── README.md                         # ✅ committed — public-facing project overview
└── requirements.txt                  # ✅ committed — Python dependencies (dbt-core, dbt-bigquery)
```

---

## Key conventions

| Path pattern                 | Rule                                                                                   |
| ---------------------------- | -------------------------------------------------------------------------------------- |
| `models/staging/localbike/`  | One subfolder per source system — enables `dbt build --select staging.localbike+`      |
| `models/intermediate/sales/` | One subfolder per business domain                                                      |
| `models/mart/sales/`         | One subfolder per business domain — Metabase connects here                             |
| `models/overview.md`         | dbt docs homepage content — rendered at https://local-bike-docs.jeremymarchandeau.com/ |
| `stg_<source>__<entity>.sql` | Always paired with a same-name `.yml` file                                             |
| `int_<entity>__<verb>.sql`   | Always paired with a same-name `.yml` file                                             |
| `<entity>.sql` (mart)        | No prefix — plain entity name (e.g. `orders.sql`, `top_products.sql`)                  |
| `_*__docs.md`                | One docs block file per layer/domain — never copy-paste descriptions across YAMLs      |
| `profiles.yml`               | Never committed — credentials injected via env vars locally, GitHub Secrets in CI/CD   |

---

## BigQuery datasets

| Dataset                            | Role                                     | Managed by                       |
| ---------------------------------- | ---------------------------------------- | -------------------------------- |
| `dbt_local_bike_dev_staging`       | Dev staging views                        | dbt (`dev` target)               |
| `dbt_local_bike_dev_intermediate`  | Dev intermediate views                   | dbt (`dev` target)               |
| `dbt_local_bike_dev_mart`          | Dev mart tables                          | dbt (`dev` target)               |
| `dbt_local_bike_prod_staging`      | Prod staging views                       | dbt (`prod` target, CD workflow) |
| `dbt_local_bike_prod_intermediate` | Prod intermediate views                  | dbt (`prod` target, CD workflow) |
| `dbt_local_bike_prod_mart`         | Prod mart tables — connected to Metabase | dbt (`prod` target, CD workflow) |

---

## Notes

- `target/manifest.json` is the key artifact for the slim CI strategy: the CD workflow uploads it to GitHub Actions after every successful production deploy; the CI workflow downloads it to perform `state:modified+` comparison.
- `snapshots/` exists as a dbt convention but is not used in this project.
- `seeds/` exists but is empty — no static reference data required for this dataset.
- `analyses/` is available for ad-hoc SQL exploration but no analyses are planned at this stage.
- Metabase connects exclusively to `dbt_local_bike_prod_mart` — never to staging or intermediate datasets.
