# Retail Data Warehouse (MySQL)

Builds a MySQL data warehouse for 1,000,000 e-commerce orders: raw CSV -> staging -> data-quality checks -> star schema -> business queries.

## Pipeline

| Step | Script | Purpose |
|---|---|---|
| 1 | `01_setup_database.sql` | Create database `ecommerce_db` |
| 2 | `02_create_staging_schema.sql` | Staging table `stg_orders` (raw, mostly VARCHAR) |
| 3 | `03_load_raw_data.sql` | `LOAD DATA INFILE` of the 1M-row CSV |
| 4 | `04_data_quality_checks.sql` | 11 checks: NULLs, duplicates, invalid price/rating/shipping, key consistency |
| 5-6 | `05_create_dimension_schema.sql`, `06_create_fact_schema.sql` | `dim_location`, `dim_seller`, `dim_date`, `fact_orders` |
| 7-8 | `07_load_dimension_data.sql`, `08_load_fact_data.sql` | Load dimensions, then fact; row count must equal staging (1,000,000) |
| 9 | `09_business_analytics.sql` | Revenue by region, seller performance |

## Key finding that shaped the model

The quality checks showed the data is not consistent per entity:

- 500+ `product_id` values are assigned to 3-5 different categories and to several brands, so there is **no `dim_product`**; product attributes stay in `fact_orders`.
- 9,000 sellers have 229,498 distinct (`seller_id`, `seller_rating`) pairs, so `seller_rating` is stored in the fact table and `dim_seller` keeps only `seller_id`.

## Run

1. Download the dataset (`amazon_ecommerce_1M.csv`, not included in this repo because of its size) and place it in a folder allowed by MySQL `secure_file_priv`.
2. Run the scripts in `SQL/` in order (01 to 09) on MySQL 8.0.

## Stack

MySQL 8.0, SQL, star schema / dimensional modeling.
