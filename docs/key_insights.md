# Key business insights

Generated from the validated SQL suite on the full public Olist extract.

## Marketplace performance

- **~R$13.49M GMV** across **~98.2k** non-canceled orders, **~95k** unique customers, **~3.05k** active sellers.  
- Average review score ≈ **4.05 / 5**.  
- Top revenue categories: **health_beauty**, **watches_gifts**, **bed_bath_table**, **sports_leisure**, **computers_accessories**.

## Delivery & satisfaction

- **~91.9%** of deliverable orders arrive on or before the estimated date.  
- Late deliveries average **2.57** review score vs **4.30** for on-time — strongest operational lever for CX in this dataset.

## Customer behavior

- Only **~3.1%** of customers place more than one order in the observed window.  
- Growth is driven primarily by **new** customers each month; retention cohorts decay quickly after month 0.  
- Implication: marketplace health depends heavily on continuous acquisition and first-order experience.

## Marketing funnel

- **8,000 MQLs → 842 closed deals (~10.5% conversion)**.  
- Lead origin materially changes conversion rates — prioritize origins with both volume and close rate.  
- Closed deals that become active sellers can be attributed back to marketplace GMV (cross-domain join), enabling true acquisition ROI discussion beyond CRM-declared revenue.

## Modeling takeaway

Materializing a star schema with pre-computed delivery flags and order-level payment/review dims keeps interview demos and Power BI measures consistent with the SQL source of truth.
