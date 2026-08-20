# Power BI — visualization layer only

This folder documents the BI presentation layer. **All metrics are defined in PostgreSQL SQL** (`analytics` star schema + marketing tables). Power BI is used to communicate insights, not to perform core transformations.

## Suggested dashboard pages

1. **Executive** — GMV, orders, customers, on-time %, avg review  
2. **Revenue** — monthly trend, MoM growth, category Pareto  
3. **Sellers & products** — top sellers, risk sellers (high GMV / low review)  
4. **Delivery & CX** — late vs on-time review impact by state  
5. **Marketing funnel** — MQL → close conversion by origin; attributed GMV  

## Connect Power BI to PostgreSQL

1. Get Data → PostgreSQL database → `olist_analytics`  
2. Import schemas: `analytics`, `marketing`  
3. Relationships should already match the star (fact → dims on surrogate keys)  
4. Prefer SQL views/measures from `sql/business_queries` as the metric contract  

## Dashboard file

Due to size limits, the `.pbix` may be hosted externally:

See [dashboard_link.md](dashboard_link.md)

## Screenshots

Add PNG exports under `power_bi/screenshots/` when available:

- `screenshots/ecommerce/Summary.png`  
- `screenshots/marketing/Funnel.png`  
