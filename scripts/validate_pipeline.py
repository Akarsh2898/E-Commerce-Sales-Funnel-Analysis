"""
End-to-end pipeline validator for Olist SQL analytics project.

Builds staging → cleaned → star-schema layers in DuckDB (PostgreSQL-compatible
SQL dialect for local validation), then executes analysis / business queries.

Target production engine remains PostgreSQL — see README setup instructions.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
OUT = ROOT / "data" / "validation_results"
OUT.mkdir(parents=True, exist_ok=True)


def connect() -> duckdb.DuckDBPyConnection:
    con = duckdb.connect(str(ROOT / "data" / "olist_analytics.duckdb"))
    con.execute("INSTALL postgres_scanner;")  # no-op if unused; ignore failures
    return con


def run(con: duckdb.DuckDBPyConnection, sql: str) -> None:
    con.execute(sql)


def q(con: duckdb.DuckDBPyConnection, sql: str):
    return con.execute(sql).fetchdf()


def build_schemas(con: duckdb.DuckDBPyConnection) -> None:
    for schema in ("staging", "ecommerce", "marketing", "analytics"):
        run(con, f"CREATE SCHEMA IF NOT EXISTS {schema};")


def load_staging(con: duckdb.DuckDBPyConnection) -> None:
    mapping = {
        "customers": "olist_customers_dataset.csv",
        "orders": "olist_orders_dataset.csv",
        "order_items": "olist_order_items_dataset.csv",
        "products": "olist_products_dataset.csv",
        "sellers": "olist_sellers_dataset.csv",
        "order_payments": "olist_order_payments_dataset.csv",
        "order_reviews": "olist_order_reviews_dataset.csv",
        "category_translation": "product_category_name_translation.csv",
        "marketing_qualified_leads": "olist_marketing_qualified_leads_dataset.csv",
        "marketing_closed_deals": "olist_marketing_closed_deals_dataset.csv",
    }
    # Skip full geolocation in local validation (large; not required for core KPIs)
    for table, filename in mapping.items():
        path = (RAW / filename).as_posix()
        run(con, f"DROP TABLE IF EXISTS staging.{table};")
        run(
            con,
            f"""
            CREATE TABLE staging.{table} AS
            SELECT * FROM read_csv_auto('{path}', header=true, sample_size=-1);
            """,
        )
        n = con.execute(f"SELECT COUNT(*) FROM staging.{table}").fetchone()[0]
        print(f"  staging.{table}: {n:,} rows")


def clean_analytical(con: duckdb.DuckDBPyConnection) -> None:
    # Drop/recreate cleaned tables (DuckDB-friendly simplified DDL)
    run(con, "DROP TABLE IF EXISTS marketing.closed_deals;")
    run(con, "DROP TABLE IF EXISTS marketing.qualified_leads;")
    run(con, "DROP TABLE IF EXISTS ecommerce.order_reviews;")
    run(con, "DROP TABLE IF EXISTS ecommerce.order_payments;")
    run(con, "DROP TABLE IF EXISTS ecommerce.order_items;")
    run(con, "DROP TABLE IF EXISTS ecommerce.orders;")
    run(con, "DROP TABLE IF EXISTS ecommerce.products;")
    run(con, "DROP TABLE IF EXISTS ecommerce.sellers;")
    run(con, "DROP TABLE IF EXISTS ecommerce.customers;")
    run(con, "DROP TABLE IF EXISTS ecommerce.category_translation;")

    run(
        con,
        """
        CREATE TABLE ecommerce.category_translation AS
        SELECT DISTINCT
            TRIM(CAST(product_category_name AS VARCHAR)) AS product_category_name,
            TRIM(CAST(product_category_name_english AS VARCHAR)) AS product_category_name_english
        FROM staging.category_translation
        WHERE product_category_name IS NOT NULL;
        """,
    )

    run(
        con,
        """
        CREATE TABLE ecommerce.customers AS
        SELECT
            TRIM(CAST(customer_id AS VARCHAR)) AS customer_id,
            TRIM(CAST(customer_unique_id AS VARCHAR)) AS customer_unique_id,
            TRY_CAST(customer_zip_code_prefix AS INTEGER) AS customer_zip_code_prefix,
            TRIM(CAST(customer_city AS VARCHAR)) AS customer_city,
            UPPER(TRIM(CAST(customer_state AS VARCHAR))) AS customer_state
        FROM staging.customers;
        """,
    )

    run(
        con,
        """
        CREATE TABLE ecommerce.sellers AS
        SELECT
            TRIM(CAST(seller_id AS VARCHAR)) AS seller_id,
            TRY_CAST(seller_zip_code_prefix AS INTEGER) AS seller_zip_code_prefix,
            LOWER(TRIM(CAST(seller_city AS VARCHAR))) AS seller_city,
            UPPER(TRIM(CAST(seller_state AS VARCHAR))) AS seller_state
        FROM staging.sellers;
        """,
    )

    # Handle Kaggle typo columns product_name_lenght / product_description_lenght
    cols = [r[0] for r in con.execute("DESCRIBE staging.products").fetchall()]
    name_len = "product_name_lenght" if "product_name_lenght" in cols else "product_name_length"
    desc_len = (
        "product_description_lenght"
        if "product_description_lenght" in cols
        else "product_description_length"
    )

    run(
        con,
        f"""
        CREATE TABLE ecommerce.products AS
        SELECT
            TRIM(CAST(product_id AS VARCHAR)) AS product_id,
            NULLIF(TRIM(CAST(product_category_name AS VARCHAR)), '') AS product_category_name,
            TRY_CAST({name_len} AS INTEGER) AS product_name_length,
            TRY_CAST({desc_len} AS INTEGER) AS product_description_length,
            TRY_CAST(product_photos_qty AS INTEGER) AS product_photos_qty,
            TRY_CAST(product_weight_g AS INTEGER) AS product_weight_g,
            TRY_CAST(product_length_cm AS INTEGER) AS product_length_cm,
            TRY_CAST(product_height_cm AS INTEGER) AS product_height_cm,
            TRY_CAST(product_width_cm AS INTEGER) AS product_width_cm
        FROM staging.products;
        """,
    )

    run(
        con,
        """
        CREATE TABLE ecommerce.orders AS
        SELECT
            TRIM(CAST(order_id AS VARCHAR)) AS order_id,
            TRIM(CAST(customer_id AS VARCHAR)) AS customer_id,
            LOWER(TRIM(CAST(order_status AS VARCHAR))) AS order_status,
            TRY_CAST(order_purchase_timestamp AS TIMESTAMP) AS order_purchase_timestamp,
            TRY_CAST(order_approved_at AS TIMESTAMP) AS order_approved_at,
            TRY_CAST(order_delivered_carrier_date AS TIMESTAMP) AS order_delivered_carrier_date,
            TRY_CAST(order_delivered_customer_date AS TIMESTAMP) AS order_delivered_customer_date,
            TRY_CAST(order_estimated_delivery_date AS TIMESTAMP) AS order_estimated_delivery_date
        FROM staging.orders
        WHERE order_id IS NOT NULL AND order_purchase_timestamp IS NOT NULL;
        """,
    )

    run(
        con,
        """
        CREATE TABLE ecommerce.order_items AS
        SELECT
            TRIM(CAST(oi.order_id AS VARCHAR)) AS order_id,
            TRY_CAST(oi.order_item_id AS INTEGER) AS order_item_id,
            TRIM(CAST(oi.product_id AS VARCHAR)) AS product_id,
            TRIM(CAST(oi.seller_id AS VARCHAR)) AS seller_id,
            TRY_CAST(oi.shipping_limit_date AS TIMESTAMP) AS shipping_limit_date,
            GREATEST(COALESCE(TRY_CAST(oi.price AS DECIMAL(12,2)), 0), 0) AS price,
            GREATEST(COALESCE(TRY_CAST(oi.freight_value AS DECIMAL(12,2)), 0), 0) AS freight_value
        FROM staging.order_items oi
        INNER JOIN ecommerce.orders o ON o.order_id = TRIM(CAST(oi.order_id AS VARCHAR))
        INNER JOIN ecommerce.products p ON p.product_id = TRIM(CAST(oi.product_id AS VARCHAR))
        INNER JOIN ecommerce.sellers s ON s.seller_id = TRIM(CAST(oi.seller_id AS VARCHAR));
        """,
    )

    run(
        con,
        """
        CREATE TABLE ecommerce.order_payments AS
        SELECT
            TRIM(CAST(op.order_id AS VARCHAR)) AS order_id,
            TRY_CAST(op.payment_sequential AS INTEGER) AS payment_sequential,
            LOWER(TRIM(CAST(op.payment_type AS VARCHAR))) AS payment_type,
            COALESCE(TRY_CAST(op.payment_installments AS INTEGER), 0) AS payment_installments,
            GREATEST(COALESCE(TRY_CAST(op.payment_value AS DECIMAL(12,2)), 0), 0) AS payment_value
        FROM staging.order_payments op
        INNER JOIN ecommerce.orders o ON o.order_id = TRIM(CAST(op.order_id AS VARCHAR));
        """,
    )

    run(
        con,
        """
        CREATE TABLE ecommerce.order_reviews AS
        SELECT * EXCLUDE (rn) FROM (
            SELECT
                TRIM(CAST(r.review_id AS VARCHAR)) AS review_id,
                TRIM(CAST(r.order_id AS VARCHAR)) AS order_id,
                LEAST(GREATEST(TRY_CAST(r.review_score AS INTEGER), 1), 5) AS review_score,
                NULLIF(TRIM(CAST(r.review_comment_title AS VARCHAR)), '') AS review_comment_title,
                NULLIF(TRIM(CAST(r.review_comment_message AS VARCHAR)), '') AS review_comment_message,
                TRY_CAST(r.review_creation_date AS TIMESTAMP) AS review_creation_date,
                TRY_CAST(r.review_answer_timestamp AS TIMESTAMP) AS review_answer_timestamp,
                ROW_NUMBER() OVER (
                    PARTITION BY TRIM(CAST(r.review_id AS VARCHAR))
                    ORDER BY TRY_CAST(r.review_creation_date AS TIMESTAMP) DESC NULLS LAST
                ) AS rn
            FROM staging.order_reviews r
            INNER JOIN ecommerce.orders o
                ON o.order_id = TRIM(CAST(r.order_id AS VARCHAR))
            WHERE r.review_id IS NOT NULL AND r.review_score IS NOT NULL
        ) t
        WHERE rn = 1;
        """,
    )

    run(
        con,
        """
        CREATE TABLE marketing.qualified_leads AS
        SELECT
            TRIM(CAST(mql_id AS VARCHAR)) AS mql_id,
            TRY_CAST(first_contact_date AS DATE) AS first_contact_date,
            NULLIF(TRIM(CAST(landing_page_id AS VARCHAR)), '') AS landing_page_id,
            COALESCE(NULLIF(LOWER(TRIM(CAST(origin AS VARCHAR))), ''), 'unknown') AS origin
        FROM staging.marketing_qualified_leads
        WHERE mql_id IS NOT NULL AND first_contact_date IS NOT NULL;
        """,
    )

    run(
        con,
        """
        CREATE TABLE marketing.closed_deals AS
        SELECT
            TRIM(CAST(c.mql_id AS VARCHAR)) AS mql_id,
            NULLIF(TRIM(CAST(c.seller_id AS VARCHAR)), '') AS seller_id,
            NULLIF(TRIM(CAST(c.sdr_id AS VARCHAR)), '') AS sdr_id,
            NULLIF(TRIM(CAST(c.sr_id AS VARCHAR)), '') AS sr_id,
            TRY_CAST(c.won_date AS DATE) AS won_date,
            NULLIF(TRIM(CAST(c.business_segment AS VARCHAR)), '') AS business_segment,
            NULLIF(TRIM(CAST(c.lead_type AS VARCHAR)), '') AS lead_type,
            NULLIF(TRIM(CAST(c.lead_behaviour_profile AS VARCHAR)), '') AS lead_behaviour_profile,
            CASE
                WHEN LOWER(TRIM(CAST(c.has_company AS VARCHAR))) IN ('true','t','yes','1') THEN TRUE
                WHEN LOWER(TRIM(CAST(c.has_company AS VARCHAR))) IN ('false','f','no','0') THEN FALSE
            END AS has_company,
            CASE
                WHEN LOWER(TRIM(CAST(c.has_gtin AS VARCHAR))) IN ('true','t','yes','1') THEN TRUE
                WHEN LOWER(TRIM(CAST(c.has_gtin AS VARCHAR))) IN ('false','f','no','0') THEN FALSE
            END AS has_gtin,
            NULLIF(TRIM(CAST(c.average_stock AS VARCHAR)), '') AS average_stock,
            NULLIF(TRIM(CAST(c.business_type AS VARCHAR)), '') AS business_type,
            TRY_CAST(c.declared_product_catalog_size AS DECIMAL(12,2)) AS declared_product_catalog_size,
            TRY_CAST(c.declared_monthly_revenue AS DECIMAL(14,2)) AS declared_monthly_revenue
        FROM staging.marketing_closed_deals c
        INNER JOIN marketing.qualified_leads m
            ON m.mql_id = TRIM(CAST(c.mql_id AS VARCHAR))
        WHERE c.won_date IS NOT NULL;
        """,
    )

    counts = q(
        con,
        """
        SELECT 'customers' AS e, COUNT(*) n FROM ecommerce.customers
        UNION ALL SELECT 'orders', COUNT(*) FROM ecommerce.orders
        UNION ALL SELECT 'order_items', COUNT(*) FROM ecommerce.order_items
        UNION ALL SELECT 'products', COUNT(*) FROM ecommerce.products
        UNION ALL SELECT 'sellers', COUNT(*) FROM ecommerce.sellers
        UNION ALL SELECT 'payments', COUNT(*) FROM ecommerce.order_payments
        UNION ALL SELECT 'reviews', COUNT(*) FROM ecommerce.order_reviews
        UNION ALL SELECT 'mqls', COUNT(*) FROM marketing.qualified_leads
        UNION ALL SELECT 'closed_deals', COUNT(*) FROM marketing.closed_deals
        ORDER BY 1;
        """,
    )
    print(counts.to_string(index=False))


def populate_star(con: duckdb.DuckDBPyConnection) -> None:
    for t in [
        "fact_order_items",
        "dim_review",
        "dim_payment",
        "dim_order",
        "dim_seller",
        "dim_product",
        "dim_customer",
        "dim_date",
    ]:
        run(con, f"DROP TABLE IF EXISTS analytics.{t};")

    run(
        con,
        """
        CREATE TABLE analytics.dim_date AS
        SELECT
            CAST(strftime(d, '%Y%m%d') AS INTEGER) AS date_key,
            CAST(d AS DATE) AS full_date,
            CAST(iso_dow AS INTEGER) AS day_of_week,
            dayname(d) AS day_name,
            CAST(day(d) AS INTEGER) AS day_of_month,
            CAST(week(d) AS INTEGER) AS week_of_year,
            CAST(month(d) AS INTEGER) AS month_number,
            monthname(d) AS month_name,
            CAST(quarter(d) AS INTEGER) AS quarter,
            CAST(year(d) AS INTEGER) AS year_number,
            iso_dow IN (6, 7) AS is_weekend
        FROM (
            SELECT
                gs AS d,
                CAST(strftime(gs, '%u') AS INTEGER) AS iso_dow
            FROM generate_series(
                (SELECT MIN(CAST(order_purchase_timestamp AS DATE)) FROM ecommerce.orders),
                (SELECT MAX(CAST(order_purchase_timestamp AS DATE)) FROM ecommerce.orders),
                INTERVAL 1 DAY
            ) t(gs)
        );
        """,
    )

    run(
        con,
        """
        CREATE SEQUENCE IF NOT EXISTS analytics.seq_customer START 1;
        CREATE TABLE analytics.dim_customer AS
        SELECT
            nextval('analytics.seq_customer') AS customer_sk,
            customer_id,
            customer_unique_id,
            customer_city,
            customer_state,
            customer_zip_code_prefix AS customer_zip_prefix
        FROM ecommerce.customers;
        """,
    )

    run(
        con,
        """
        CREATE SEQUENCE IF NOT EXISTS analytics.seq_product START 1;
        CREATE TABLE analytics.dim_product AS
        SELECT
            nextval('analytics.seq_product') AS product_sk,
            p.product_id,
            p.product_category_name,
            COALESCE(t.product_category_name_english, 'untranslated') AS product_category_name_english,
            p.product_weight_g,
            p.product_photos_qty
        FROM ecommerce.products p
        LEFT JOIN ecommerce.category_translation t
            ON p.product_category_name = t.product_category_name;
        """,
    )

    run(
        con,
        """
        CREATE SEQUENCE IF NOT EXISTS analytics.seq_seller START 1;
        CREATE TABLE analytics.dim_seller AS
        SELECT
            nextval('analytics.seq_seller') AS seller_sk,
            seller_id,
            seller_city,
            seller_state,
            seller_zip_code_prefix AS seller_zip_prefix
        FROM ecommerce.sellers;
        """,
    )

    run(
        con,
        """
        CREATE SEQUENCE IF NOT EXISTS analytics.seq_order START 1;
        CREATE TABLE analytics.dim_order AS
        SELECT
            nextval('analytics.seq_order') AS order_sk,
            order_id,
            order_status,
            order_purchase_timestamp,
            order_approved_at,
            order_delivered_carrier_date,
            order_delivered_customer_date,
            order_estimated_delivery_date,
            CASE WHEN order_delivered_customer_date IS NOT NULL
                 THEN datediff('day', CAST(order_purchase_timestamp AS DATE),
                                      CAST(order_delivered_customer_date AS DATE))
            END AS delivery_days,
            CASE WHEN order_estimated_delivery_date IS NOT NULL
                 THEN datediff('day', CAST(order_purchase_timestamp AS DATE),
                                      CAST(order_estimated_delivery_date AS DATE))
            END AS estimated_delivery_days,
            CASE WHEN order_delivered_customer_date IS NOT NULL
                  AND order_estimated_delivery_date IS NOT NULL
                 THEN order_delivered_customer_date > order_estimated_delivery_date
            END AS is_late_delivery,
            CASE WHEN order_delivered_customer_date IS NOT NULL
                  AND order_estimated_delivery_date IS NOT NULL
                 THEN datediff('day', CAST(order_estimated_delivery_date AS DATE),
                                      CAST(order_delivered_customer_date AS DATE))
            END AS delay_days
        FROM ecommerce.orders;
        """,
    )

    run(
        con,
        """
        CREATE SEQUENCE IF NOT EXISTS analytics.seq_payment START 1;
        CREATE TABLE analytics.dim_payment AS
        SELECT
            nextval('analytics.seq_payment') AS payment_sk,
            order_id,
            (ARRAY_AGG(payment_type ORDER BY payment_sequential))[1] AS primary_payment_type,
            COUNT(*) AS payment_count,
            SUM(payment_value) AS total_payment_value,
            MAX(payment_installments) AS max_installments
        FROM ecommerce.order_payments
        GROUP BY order_id;
        """,
    )

    run(
        con,
        """
        CREATE SEQUENCE IF NOT EXISTS analytics.seq_review START 1;
        CREATE TABLE analytics.dim_review AS
        SELECT
            nextval('analytics.seq_review') AS review_sk,
            order_id,
            review_id,
            review_score,
            review_creation_date,
            review_comment_message IS NOT NULL AS has_comment
        FROM (
            SELECT
                r.*,
                ROW_NUMBER() OVER (
                    PARTITION BY order_id
                    ORDER BY review_creation_date DESC NULLS LAST, review_id
                ) AS rn
            FROM ecommerce.order_reviews r
        ) x
        WHERE rn = 1;
        """,
    )

    run(
        con,
        """
        CREATE SEQUENCE IF NOT EXISTS analytics.seq_fact START 1;
        CREATE TABLE analytics.fact_order_items AS
        SELECT
            nextval('analytics.seq_fact') AS fact_sk,
            oi.order_id,
            oi.order_item_id,
            CAST(strftime(o.order_purchase_timestamp, '%Y%m%d') AS INTEGER) AS date_key,
            dc.customer_sk,
            dp.product_sk,
            ds.seller_sk,
            do_.order_sk,
            dpay.payment_sk,
            drev.review_sk,
            oi.price,
            oi.freight_value,
            oi.price AS item_revenue,
            (oi.price - oi.freight_value) AS item_contribution,
            oi.shipping_limit_date
        FROM ecommerce.order_items oi
        INNER JOIN ecommerce.orders o ON oi.order_id = o.order_id
        INNER JOIN analytics.dim_customer dc ON o.customer_id = dc.customer_id
        INNER JOIN analytics.dim_product dp ON oi.product_id = dp.product_id
        INNER JOIN analytics.dim_seller ds ON oi.seller_id = ds.seller_id
        INNER JOIN analytics.dim_order do_ ON oi.order_id = do_.order_id
        LEFT JOIN analytics.dim_payment dpay ON oi.order_id = dpay.order_id
        LEFT JOIN analytics.dim_review drev ON oi.order_id = drev.order_id;
        """,
    )

    print(q(con, "SELECT COUNT(*) AS fact_rows FROM analytics.fact_order_items").to_string(index=False))


def split_sql_statements(text: str) -> list[str]:
    # Strip /* */ and -- comments, then split on semicolons
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    lines = []
    for line in text.splitlines():
        if line.strip().startswith("--"):
            continue
        lines.append(line)
    body = "\n".join(lines)
    parts = [p.strip() for p in body.split(";")]
    return [p for p in parts if p]


def adapt_pg_to_duckdb(sql: str) -> str:
    # Minor dialect tweaks for validation runs
    sql = sql.replace("::NUMERIC", "::DOUBLE")
    sql = sql.replace("::numeric", "::DOUBLE")
    return sql


def run_sql_file(con: duckdb.DuckDBPyConnection, path: Path) -> list[dict]:
    results = []
    statements = split_sql_statements(path.read_text(encoding="utf-8"))
    for i, stmt in enumerate(statements, 1):
        stmt = adapt_pg_to_duckdb(stmt)
        try:
            cur = con.execute(stmt)
            if cur.description:
                df = cur.fetchdf()
                preview = df.head(5).to_dict(orient="records")
                results.append(
                    {
                        "file": path.name,
                        "statement": i,
                        "status": "ok",
                        "rows": len(df),
                        "preview": preview,
                    }
                )
                print(f"  OK  {path.name} #{i} -> {len(df)} rows")
            else:
                results.append(
                    {"file": path.name, "statement": i, "status": "ok", "rows": 0}
                )
                print(f"  OK  {path.name} #{i} (no result set)")
        except Exception as exc:  # noqa: BLE001
            results.append(
                {
                    "file": path.name,
                    "statement": i,
                    "status": "error",
                    "error": str(exc),
                    "sql_start": stmt[:180],
                }
            )
            print(f"  ERR {path.name} #{i}: {exc}")
    return results


def collect_insights(con: duckdb.DuckDBPyConnection) -> dict:
    insights = {}
    insights["snapshot"] = q(
        con,
        """
        SELECT
            COUNT(DISTINCT o.order_id) AS total_orders,
            COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
            COUNT(DISTINCT s.seller_id) AS active_sellers,
            ROUND(SUM(f.item_revenue), 2) AS total_gmv,
            ROUND(AVG(r.review_score), 2) AS avg_review_score
        FROM analytics.fact_order_items f
        INNER JOIN analytics.dim_order o ON f.order_sk = o.order_sk
        INNER JOIN analytics.dim_customer c ON f.customer_sk = c.customer_sk
        INNER JOIN analytics.dim_seller s ON f.seller_sk = s.seller_sk
        LEFT JOIN analytics.dim_review r ON f.review_sk = r.review_sk
        WHERE o.order_status NOT IN ('canceled', 'unavailable');
        """,
    ).to_dict(orient="records")[0]

    insights["late_vs_ontime_reviews"] = q(
        con,
        """
        SELECT
            CASE WHEN is_late_delivery THEN 'Late' ELSE 'On Time' END AS status,
            ROUND(AVG(r.review_score), 2) AS avg_score,
            COUNT(*) AS n
        FROM analytics.dim_order o
        JOIN analytics.dim_review r ON o.order_id = r.order_id
        WHERE is_late_delivery IS NOT NULL
        GROUP BY 1;
        """,
    ).to_dict(orient="records")

    insights["repeat_rate"] = q(
        con,
        """
        WITH cust AS (
            SELECT c.customer_unique_id, COUNT(DISTINCT f.order_id) AS orders
            FROM analytics.fact_order_items f
            JOIN analytics.dim_customer c ON f.customer_sk = c.customer_sk
            GROUP BY 1
        )
        SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE orders > 1) / COUNT(*), 2) AS repeat_customer_pct
        FROM cust;
        """,
    ).to_dict(orient="records")[0]

    insights["top_categories"] = q(
        con,
        """
        SELECT
            p.product_category_name_english AS category,
            ROUND(SUM(f.item_revenue), 2) AS revenue
        FROM analytics.fact_order_items f
        JOIN analytics.dim_product p ON f.product_sk = p.product_sk
        GROUP BY 1
        ORDER BY revenue DESC
        LIMIT 5;
        """,
    ).to_dict(orient="records")

    insights["funnel"] = q(
        con,
        """
        SELECT
            COUNT(DISTINCT m.mql_id) AS total_mqls,
            COUNT(DISTINCT c.mql_id) AS closed_deals,
            ROUND(100.0 * COUNT(DISTINCT c.mql_id) / NULLIF(COUNT(DISTINCT m.mql_id), 0), 2)
                AS conversion_pct
        FROM marketing.qualified_leads m
        LEFT JOIN marketing.closed_deals c ON m.mql_id = c.mql_id;
        """,
    ).to_dict(orient="records")[0]

    insights["on_time_pct"] = q(
        con,
        """
        SELECT ROUND(
            100.0 * COUNT(*) FILTER (WHERE NOT is_late_delivery) / NULLIF(COUNT(*), 0), 2
        ) AS on_time_delivery_pct
        FROM analytics.dim_order
        WHERE is_late_delivery IS NOT NULL;
        """,
    ).to_dict(orient="records")[0]

    return insights


def main() -> None:
    print("Connecting…")
    con = duckdb.connect(str(ROOT / "data" / "olist_analytics.duckdb"))
    print("Building schemas…")
    build_schemas(con)
    print("Loading staging…")
    load_staging(con)
    print("Cleaning analytical layer…")
    clean_analytical(con)
    print("Populating star schema…")
    populate_star(con)

    all_results = []
    sql_dirs = [
        ROOT / "sql" / "data_validation",
        ROOT / "sql" / "analysis",
        ROOT / "sql" / "business_queries",
    ]
    for d in sql_dirs:
        for path in sorted(d.glob("*.sql")):
            print(f"\nRunning {path.relative_to(ROOT)} …")
            all_results.extend(run_sql_file(con, path))

    insights = collect_insights(con)
    (OUT / "query_run_log.json").write_text(json.dumps(all_results, indent=2, default=str))
    (OUT / "key_insights.json").write_text(json.dumps(insights, indent=2, default=str))

    errors = [r for r in all_results if r["status"] == "error"]
    print(f"\nDone. Statements OK: {len(all_results) - len(errors)} / {len(all_results)}")
    print("Insights:", json.dumps(insights, indent=2, default=str))
    if errors:
        print("\nErrors:")
        for e in errors:
            print(f"  - {e['file']}#{e['statement']}: {e['error']}")


if __name__ == "__main__":
    main()
