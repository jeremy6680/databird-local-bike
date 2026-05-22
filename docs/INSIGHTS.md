# Revenue Insights — Local Bike

> **Author:** Jeremy Marchandeau  
> **Date:** May 2026, 22nd  
> **Data period:** January 2016 – March 2018  
> **Source models:** `revenue_by_store`, `revenue_by_category`, `top_products`, `orders`

---

## Context

This analysis examines Local Bike's sales performance across its three stores
(Baldwin NY, Santa Cruz CA, Rowlett TX) over approximately 27 months of operations.
Total revenue over the period: **$6,662,609** across **1,445 completed orders**.
Average order value: **$4,611**.

The goal is to surface actionable insights that help the operations team
optimise revenue and reduce structural risks.

---

## Insight 1 — Baldwin drives 70% of revenue: a concentration risk

| Store         | Revenue    | Share | Orders |
| ------------- | ---------- | ----- | ------ |
| Baldwin Bikes | $4,701,205 | 70.6% | 1,019  |
| Santa Cruz    | $1,255,490 | 18.8% | 284    |
| Rowlett       | $705,913   | 10.6% | 142    |

Baldwin Bikes alone generates **7x more revenue than Rowlett** and **nearly 4x
more than Santa Cruz**. While this reflects Baldwin's proximity to the New York
metro market, it creates a structural dependency: any operational disruption
at Baldwin (staffing, logistics, local competition) would have an outsized impact
on company-wide revenue.

**Baldwin's year-over-year growth confirms this dominance:**

| Year   | Baldwin    | Santa Cruz | Rowlett  |
| ------ | ---------- | ---------- | -------- |
| 2016   | $1,585,134 | $544,659   | $243,054 |
| 2017   | $2,433,947 | $544,196   | $368,826 |
| 2018\* | $682,124   | $166,635   | $94,033  |

\*2018 data covers January–March only.

Santa Cruz revenue was **flat between 2016 and 2017** ($544k vs $544k — essentially
zero growth), while Baldwin grew +54% and Rowlett grew +52%.

**Recommendation:** Investigate Santa Cruz's stagnation. Is it a market saturation
issue, a staffing issue, or a product mix mismatch with the California outdoor
cycling audience? Rowlett's strong growth (+52%) suggests it has untapped potential
worth investing in.

---

## Insight 2 — Mountain Bikes lead revenue, but Road and Electric generate the highest value per unit

| Category            | Revenue    | Units Sold | Avg Revenue/Unit |
| ------------------- | ---------- | ---------- | ---------------- |
| Road Bikes          | $1,327,155 | 449        | **$2,956**       |
| Electric Bikes      | $733,493   | 252        | **$2,911**       |
| Cyclocross Bicycles | $642,585   | 365        | $1,761           |
| Mountain Bikes      | $2,486,419 | 1,607      | $1,547           |
| Comfort Bicycles    | $346,449   | 733        | $473             |
| Cruisers Bicycles   | $866,523   | 1,865      | $465             |
| Children Bicycles   | $259,985   | 1,047      | $248             |

Mountain Bikes generate the most total revenue (37.3% of total) due to high
volume (1,607 units). However, Road Bikes and Electric Bikes generate nearly
**twice the revenue per unit sold** ($2,956 and $2,911 respectively vs $1,547
for Mountain Bikes).

Cruisers and Children Bicycles move high volumes but at very low unit value
($465 and $248). They contribute to order count but compress overall margin.

**Recommendation:** Prioritise upselling Road and Electric Bikes in customer
consultations — they deliver significantly higher revenue per transaction.
Consider whether Cruisers and Children Bicycles justify their shelf space
relative to margin contribution, particularly in stores with limited floor space.

---

## Insight 3 — Trek dominates the top 5: a supplier dependency worth monitoring

| Rank | Product                               | Brand | Category       | Revenue  | Units |
| ---- | ------------------------------------- | ----- | -------------- | -------- | ----- |
| 1    | Trek Slash 8 27.5 - 2016              | Trek  | Mountain Bikes | $544,318 | 151   |
| 2    | Trek Conduit+ - 2016                  | Trek  | Electric Bikes | $381,149 | 142   |
| 3    | Trek Fuel EX 8 29 - 2016              | Trek  | Mountain Bikes | $354,814 | 138   |
| 4    | Surly Straggler 650b - 2016           | Surly | Cyclocross     | $220,714 | 147   |
| 5    | Trek Remedy 29 Carbon Frameset - 2016 | Trek  | Mountain Bikes | $199,997 | 123   |

Trek accounts for **4 of the top 5 products** and **3 of the top 3**. The top
product alone (Trek Slash 8) generates $544k — more than Rowlett's entire
annual revenue. The top 3 products are all 2016 model-year bikes, suggesting
that the catalogue may not have been refreshed sufficiently in 2017.

**Recommendation:** Monitor Trek's pricing and availability terms closely — the
business is significantly exposed to this single supplier. Explore whether 2017
and 2018 model-year products are underrepresented in the catalogue and whether
newer inventory could drive incremental revenue.

---

## Insight 4 — 1 in 3 orders is delivered late

Out of 1,445 shipped orders:

- **On time:** 987 orders (68.3%)
- **Late:** 458 orders (31.7%)
- **Average delay when late:** 1.3 days

Nearly a third of all deliveries miss the required date. The average delay of
1.3 days suggests these are not extreme failures but systematic, recurring
slippage — likely a structural issue in the fulfilment process rather than
isolated incidents.

**Recommendation:** Identify whether late deliveries are concentrated in a
specific store, a specific period, or a specific product category (large/heavy
items may be harder to ship on time). A 31.7% late rate risks eroding customer
trust and repeat purchase rates — particularly for a brand built on personalised
service and community trust.

---

## Insight 5 — Strong growth in 2017, but 2018 data is incomplete

| Year   | Revenue    | Orders | Growth     |
| ------ | ---------- | ------ | ---------- |
| 2016   | $2,372,847 | 620    | —          |
| 2017   | $3,346,970 | 671    | **+41.0%** |
| 2018\* | $942,793   | 154    | (partial)  |

\*Q1 2018 only (January–March).

The business grew **+41% in revenue** from 2016 to 2017 with only an 8% increase
in order count — meaning average order value increased significantly. This
suggests the team successfully upsold higher-value products over time, which
is consistent with the brand's personalised consultation model.

The 2018 data (3 months only) shows an annualised run rate of ~$3.8M, which
would represent continued growth if the trend holds — but this cannot be
confirmed without full-year data.

**Recommendation:** Ensure the data pipeline captures 2018 data fully as it
becomes available. The upward trajectory is promising but the dataset is
insufficient to draw firm conclusions about 2018 performance.

---

## Summary — Priority actions for the operations team

| Priority  | Action                                                                 | Insight |
| --------- | ---------------------------------------------------------------------- | ------- |
| 🔴 High   | Investigate Santa Cruz's flat revenue — diagnose the root cause        | #1      |
| 🔴 High   | Reduce late delivery rate from 31.7% — identify fulfilment bottlenecks | #4      |
| 🟡 Medium | Shift sales focus toward Road and Electric Bikes (highest value/unit)  | #2      |
| 🟡 Medium | Invest in Rowlett's growth trajectory (+52% YoY)                       | #1      |
| 🟢 Low    | Diversify supplier mix beyond Trek to reduce concentration risk        | #3      |
| 🟢 Low    | Refresh catalogue with newer model-year products                       | #3      |
