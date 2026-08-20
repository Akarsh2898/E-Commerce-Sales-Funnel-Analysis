# Schema design

## Why two modeling styles?

| Domain | Pattern | Reason |
|--------|---------|--------|
| E-commerce | Star schema (`analytics`) | Repeated transactional grain (order items); BI-friendly |
| Marketing | Event funnel (`marketing`) | Process flow (MQL → close); not a repeating fact table |

## Relational layer (`ecommerce`)

- `customers` PK `customer_id`  
- `orders` PK `order_id` → FK `customer_id`  
- `order_items` PK (`order_id`,`order_item_id`) → FKs to orders, products, sellers  
- `order_payments` PK (`order_id`,`payment_sequential`)  
- `order_reviews` PK `review_id` → FK `order_id`  
- Soft lookup: product category ↔ English translation (some untranslated categories exist)

## Star layer (`analytics`)

**Fact grain:** one row per order item.

```
                dim_date
                   │
dim_customer ─ fact_order_items ─ dim_product
                   │
              dim_seller
                   │
         dim_order / dim_payment / dim_review
```

`dim_payment` and `dim_review` are **order-grain** to avoid fan-out when an
order has multiple payment rows or duplicate reviews.

`dim_order` stores delivery KPIs (`delivery_days`, `is_late_delivery`, `delay_days`)
so SLA analysis does not recompute timestamp math everywhere.

## Marketing funnel

```
qualified_leads ──(mql_id)── closed_deals ──(seller_id)──> sellers / fact sales
```

`seller_id` is intentionally **not** a hard FK to `ecommerce.sellers` because
many closed deals never appear in the marketplace seller extract (validated).
