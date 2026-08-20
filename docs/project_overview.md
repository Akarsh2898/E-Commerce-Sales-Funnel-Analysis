# Project overview

Olist is a Brazilian e-commerce marketplace connecting sellers and customers.
This project analyzes transactional marketplace data together with the seller
acquisition marketing funnel.

## Analytical goals

- Measure GMV, contribution (price − freight proxy), and growth  
- Rank products, categories, and sellers  
- Quantify delivery SLA and its effect on reviews  
- Profile customer repeat behavior and simple RFM segments  
- Evaluate MQL → closed-deal conversion and post-acquisition seller quality  

## Design principles

1. **SQL is the source of truth** for metrics and transformations.  
2. **Star schema is physical**, not only a diagram — built in `analytics`.  
3. **Marketing stays event-based** (funnel), not over-modeled as a star.  
4. **Power BI visualizes**; it does not replace SQL analysis.  
