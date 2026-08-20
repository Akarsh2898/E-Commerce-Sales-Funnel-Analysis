# SQL execution order

Run scripts in this sequence against database `olist_analytics`:

1. `schema/01_create_database.sql` (as superuser; creates DB)
2. `schema/02_create_staging_tables.sql`
3. `schema/03_create_analytical_tables.sql`
4. `schema/04_create_star_schema.sql`
5. `load/01b_psql_client_copy.sql`  (edit paths first)
6. `data_cleaning/01_clean_and_load_analytical.sql`
7. `data_cleaning/02_populate_star_schema.sql`
8. `data_validation/*.sql`
9. `analysis/*.sql`
10. `business_queries/*.sql`

Optional local check without PostgreSQL:

```bash
python scripts/validate_pipeline.py
```
