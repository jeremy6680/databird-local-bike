-- =============================================================================
-- Analysis: Stock levels for the top 3 best-selling products
-- =============================================================================
-- Purpose : Cross-reference the top 3 products by revenue with their current
--           stock levels across all stores.
-- Sources : mart.top_products (revenue ranking)
--           staging.stg_localbike__stocks (stock quantities per store/product)
--           staging.stg_localbike__stores (store name lookup)
-- Grain   : one row per product × store
-- Usage   : Run in Metabase (native query) or BigQuery console
-- =============================================================================

WITH

-- Pull the top 3 products by revenue rank
top_3 AS (
    SELECT
        product_id,
        product_name,
        brand_name,
        category_name,
        total_revenue,
        units_sold,
        revenue_rank
    FROM {{ ref('top_products') }}
    -- ref() syntax for dbt docs/lineage — replace with full path for direct execution:
    -- FROM `databird-prep-work-ae`.`dbt_local_bike_prod_mart`.`top_products`
    WHERE revenue_rank <= 3
),

-- Pull stock levels for those products across all stores
stocks AS (
    SELECT
        product_id,
        store_id,
        quantity
    FROM {{ ref('stg_localbike__stocks') }}
    -- FROM `databird-prep-work-ae`.`dbt_local_bike_prod_staging`.`stg_localbike__stocks`
),

-- Store name lookup
stores AS (
    SELECT
        store_id,
        store_name
    FROM {{ ref('stg_localbike__stores') }}
    -- FROM `databird-prep-work-ae`.`dbt_local_bike_prod_staging`.`stg_localbike__stores`
)

-- Join everything: top 3 products × stock per store
SELECT
    t.revenue_rank,
    t.product_name,
    t.brand_name,
    t.category_name,
    t.total_revenue,
    t.units_sold,
    st.store_name,
    s.quantity                                          AS stock_quantity,

    -- Flag products at risk of stockout (threshold: <= 5 units)
    CASE
        WHEN s.quantity = 0 THEN 'Out of stock'
        WHEN s.quantity <= 5 THEN 'Low stock'
        ELSE 'In stock'
    END                                                 AS stock_status

FROM top_3 AS t
-- Left join to catch any product with no stock record (quantity implicitly 0)
LEFT JOIN stocks AS s
    ON t.product_id = s.product_id
LEFT JOIN stores AS st
    ON s.store_id = st.store_id

ORDER BY
    t.revenue_rank ASC,
    st.store_name   ASC