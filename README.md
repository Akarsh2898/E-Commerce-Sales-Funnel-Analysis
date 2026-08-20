# Olist Brazilian Marketplace — SQL Analytics (PostgreSQL)

**Resume title:** *Olist E-Commerce Marketplace Analytics with PostgreSQL Star Schema & Power BI*

End-to-end **SQL-first** analytics project on the public Olist Brazilian e-commerce and marketing-funnel datasets. PostgreSQL is the primary skill focus (schema design, cleaning, validation, 20+ analytical queries). Power BI is used only as the **visualization layer**.

---

## 1. Project objective

Build a production-style analytics pipeline that:

1. Loads raw Olist CSVs into a staging zone  
2. Cleans and constrains data into a relational model (`ecommerce` / `marketing`)  
3. Materializes a **physical star schema** (`analytics`) for fast BI and SQL analysis  
4. Answers revenue, seller, customer, delivery, growth, and acquisition questions in SQL  

---

## 2. Business problem

Olist connects independent sellers with customers across Brazil. Leadership needs answers to:

- Which categories and sellers drive GMV, and how is revenue trending over time?  
- How reliable is delivery, and does lateness hurt customer satisfaction?  
- How sticky are customers (repeat purchase / retention)?  
- Which marketing origins convert MQLs into sellers that actually sell on the marketplace?  

Without a clean SQL model, these questions require fragile spreadsheet joins and inconsistent KPI definitions.

---

## 3. Dataset description

| Domain | Source | Core entities |
|--------|--------|---------------|
| E-commerce | [Kaggle — Brazilian E-Commerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) | customers, orders, order items, products, sellers, payments, reviews, geolocation, category translation |
| Marketing funnel | [Kaggle — Marketing Funnel](https://www.kaggle.com/datasets/olistbr/marketing-funnel-olist) | marketing qualified leads (MQLs), closed deals |

Approximate volumes after load: ~99k orders, ~113k order items, ~3k sellers, 8k MQLs, 842 closed deals.

Place CSVs in `data/raw/` (see `data/README.md`). Raw files are gitignored.

---

## 4. Database schema

### Relational layer (`ecommerce`, `marketing`)

```
customers 1──* orders 1──* order_items *──1 products
                         *──1 sellers
              orders 1──* order_payments
              orders 1──* order_reviews

qualified_leads 1──0..1 closed_deals  (seller_id soft-links to sellers)
```

Primary/foreign keys, indexes, and check constraints are defined in `sql/schema/`.

### Star schema (`analytics`) — physically built in SQL

| Type | Table | Grain |
|------|-------|-------|
| Fact | `fact_order_items` | 1 row = 1 order line item |
| Dim | `dim_date`, `dim_customer`, `dim_product`, `dim_seller`, `dim_order`, `dim_payment`, `dim_review` | descriptive attributes + pre-computed delivery flags |

Population script: `sql/data_cleaning/02_populate_star_schema.sql`.

Marketing remains an **event-based funnel model** (not forced into a star) — intentional modeling judgment.

Detailed ER notes: `docs/schema_design.md`.

---

## 5. SQL techniques demonstrated

- DDL with PKs, FKs, indexes, `CHECK` constraints, schemas  
- Staging → typed analytical load with casting / `NULLIF` / boolean normalization  
- `INNER` / `LEFT` / `RIGHT` joins and anti-joins  
- `GROUP BY` / `HAVING`, aggregations, `FILTER (WHERE …)`  
- CTEs, subqueries, correlated-style patterns  
- `CASE` bucketing (price bands, delivery SLA, RFM segments)  
- Window functions: `RANK`, `DENSE_RANK`, `NTILE`, `LAG`, running totals, rolling frames  
- Date/time analysis: `DATE_TRUNC`, delivery day diffs, cohort retention  
- Cross-domain analysis: marketing acquisition × marketplace GMV  

Query inventory lives under `sql/analysis/` and `sql/business_queries/` (**23+ business queries** plus validation suites).

---

## 6. Key business insights

*(Validated on the full public Olist extract — see `data/validation_results/key_insights.json`)*

| Finding | Evidence |
|---------|----------|
| Marketplace GMV ≈ **R$13.5M** across ~98k non-canceled orders | Executive KPI pack |
| **On-time delivery ≈ 91.9%** | `dim_order.is_late_delivery` |
| Late deliveries crush satisfaction: **2.57 vs 4.30** avg review | Late vs on-time comparison |
| Repeat purchase rate is low (**~3.1%**) — acquisition-heavy marketplace | Customer behavior CTE |
| Top revenue categories: **health_beauty**, **watches_gifts**, **bed_bath_table** | Category ranking |
| Marketing funnel converts **~10.5%** of MQLs (8000 → 842) | Funnel LEFT JOIN |
| Not all closed deals appear as active marketplace sellers — CRM/marketplace lag | Validation coverage check |

Narrative write-up: `docs/key_insights.md`.

---

## 7. Project workflow

```
Raw CSVs (data/raw)
        │
        ▼
 staging.*          ← sql/schema/02 + sql/load/*
        │
        ▼
 ecommerce.* / marketing.*   ← sql/data_cleaning/01  (typed + FK-safe)
        │
        ▼
 analytics.* star schema     ← sql/data_cleaning/02
        │
        ├── sql/data_validation/*     quality gates
        ├── sql/analysis/*            deep SQL analytics
        └── sql/business_queries/*    exec + interview demos
                │
                ▼
         Power BI (visualization only)
```

---

## 8. Project structure

```
├── README.md
├── docs/
│   ├── project_overview.md
│   ├── data_sources.md
│   ├── schema_design.md
│   └── key_insights.md
├── sql/
│   ├── schema/              # database + tables + star DDL
│   ├── load/                # COPY / \copy into staging
│   ├── data_cleaning/       # transform + populate star
│   ├── data_validation/     # integrity & sanity checks
│   ├── analysis/            # 20+ analytical queries
│   └── business_queries/    # KPI + funnel + interview demos
├── power_bi/                # dashboard links & screenshots notes
├── data/
│   ├── README.md            # how to obtain CSVs
│   └── raw/                 # place CSVs here (gitignored)
└── scripts/
    └── validate_pipeline.py # local DuckDB validation harness
```

---

## 9. Setup instructions (PostgreSQL)

### Prerequisites

- PostgreSQL 14+ (`psql` on PATH)  
- Olist CSV files in `data/raw/` (see `data/README.md`)  

### Step-by-step

```bash
# 1) Create DB + schemas
psql -U postgres -f sql/schema/01_create_database.sql
psql -U postgres -d olist_analytics -f sql/schema/02_create_staging_tables.sql
psql -U postgres -d olist_analytics -f sql/schema/03_create_analytical_tables.sql
psql -U postgres -d olist_analytics -f sql/schema/04_create_star_schema.sql

# 2) Load staging (client-side copy — edit paths inside the file first)
psql -U postgres -d olist_analytics -f sql/load/01b_psql_client_copy.sql

# 3) Clean + star schema
psql -U postgres -d olist_analytics -f sql/data_cleaning/01_clean_and_load_analytical.sql
psql -U postgres -d olist_analytics -f sql/data_cleaning/02_populate_star_schema.sql

# 4) Validate
psql -U postgres -d olist_analytics -f sql/data_validation/01_ecommerce_validation.sql
psql -U postgres -d olist_analytics -f sql/data_validation/02_marketing_validation.sql

# 5) Analyze
psql -U postgres -d olist_analytics -f sql/analysis/01_revenue_trends.sql
# …run remaining files under sql/analysis and sql/business_queries
```

### Optional local validation (no Postgres install)

```bash
pip install duckdb pandas
python scripts/validate_pipeline.py
```

This rebuilds the layers in DuckDB and executes the analysis SQL suite (59/59 statements validated on the full dataset).

---

## 10. Power BI (visualization layer)

Power BI consumes the **`analytics` star schema** (and optionally marketing tables). It is **not** the core of this project — SQL modeling and querying are.

- Dashboard file / link: `power_bi/dashboard_link.md`  
- Screenshot placeholders: `power_bi/README.md`  

Suggested pages: Executive KPIs · Revenue trends · Category/Seller rank · Delivery SLA · Marketing funnel.

---

## 11. Tools & skills

PostgreSQL · Star-schema modeling · Data cleaning & validation · Advanced SQL (windows, CTEs, cohorts) · Funnel analytics · Power BI (presentation)

---

## License / data credit

Olist public datasets on Kaggle. This repository contains SQL/analytics code only; raw CSVs are not redistributed.
