# Data directory

## Download datasets

1. **E-commerce:** https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce  
2. **Marketing funnel:** https://www.kaggle.com/datasets/olistbr/marketing-funnel-olist  

Place these files into `data/raw/`:

```
olist_customers_dataset.csv
olist_orders_dataset.csv
olist_order_items_dataset.csv
olist_products_dataset.csv
olist_sellers_dataset.csv
olist_order_payments_dataset.csv
olist_order_reviews_dataset.csv
olist_geolocation_dataset.csv
product_category_name_translation.csv
olist_marketing_qualified_leads_dataset.csv
olist_marketing_closed_deals_dataset.csv   # aka olist_closed_deals_dataset.csv
```

### Quick download via Python

```bash
pip install kagglehub
python -c "import kagglehub, shutil, pathlib; \
p=pathlib.Path('data/raw'); p.mkdir(parents=True, exist_ok=True); \
e=kagglehub.dataset_download('olistbr/brazilian-ecommerce'); \
m=kagglehub.dataset_download('olistbr/marketing-funnel-olist'); \
[shutil.copy(x, p) for x in pathlib.Path(e).glob('*.csv')]; \
[shutil.copy(x, p) for x in pathlib.Path(m).glob('*.csv')]; \
src=p/'olist_closed_deals_dataset.csv'; \
(src.rename(p/'olist_marketing_closed_deals_dataset.csv') if src.exists() and not (p/'olist_marketing_closed_deals_dataset.csv').exists() else None)"
```

Raw CSVs and local DuckDB files are gitignored.
