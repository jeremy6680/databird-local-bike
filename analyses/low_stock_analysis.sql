-- =============================================================================
-- Analysis: Stock risk — low stock weighted by sales velocity
-- =============================================================================
-- Purpose : Identify products at risk of stockout that actually drive revenue.
--           A product with 2 units in stock matters only if it sells well.
-- Risk score logic:
--   HIGH   → low/out of stock AND top 20% by units sold
--   MEDIUM → low/out of stock AND mid-tier seller
--   LOW    → low/out of stock but slow mover (deprioritise)
-- =============================================================================

WITH

-- All products with their sales rank and total units sold
all_products AS (
    SELECT
        product_id,
        product_name,
        brand_name,
        category_name,
        units_sold,
        total_revenue,

        -- Percentile rank by units sold (1.0 = best seller)
        PERCENT_RANK() OVER (ORDER BY units_sold ASC) AS sales_percentile

    FROM {{ ref('top_products') }}
    -- FROM `databird-prep-work-ae`.`dbt_local_bike_prod_mart`.`top_products`
),

-- Stock levels per product × store
stocks AS (
    SELECT
        product_id,
        store_id,
        quantity
    FROM {{ ref('stg_localbike__stocks') }}
    -- FROM `databird-prep-work-ae`.`dbt_local_bike_prod_staging`.`stg_localbike__stocks`
),

stores AS (
    SELECT store_id, store_name
    FROM {{ ref('stg_localbike__stores') }}
    -- FROM `databird-prep-work-ae`.`dbt_local_bike_prod_staging`.`stg_localbike__stores`
),

-- Join and classify
joined AS (
    SELECT
        p.product_name,
        p.brand_name,
        p.category_name,
        p.units_sold,
        p.total_revenue,
        p.sales_percentile,
        st.store_name,
        s.quantity AS stock_quantity,

        CASE
            WHEN s.quantity = 0  THEN 'Out of stock'
            WHEN s.quantity <= 5 THEN 'Low stock'
            ELSE 'OK'
        END AS stock_status,

        -- Risk score: combines stock status + sales velocity
        CASE
            WHEN s.quantity <= 5 AND p.sales_percentile >= 0.8 THEN 'HIGH'
            WHEN s.quantity <= 5 AND p.sales_percentile >= 0.5 THEN 'MEDIUM'
            WHEN s.quantity <= 5                               THEN 'LOW'
            ELSE NULL
        END AS restock_priority

    FROM all_products AS p
    LEFT JOIN stocks AS s USING (product_id)
    LEFT JOIN stores AS st ON s.store_id = st.store_id
)

SELECT *
FROM joined

-- Only surface products that actually need attention
WHERE stock_status IN ('Out of stock', 'Low stock')
ORDER BY
    -- Sort by risk first, then by revenue impact
    CASE restock_priority WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,
    total_revenue DESC