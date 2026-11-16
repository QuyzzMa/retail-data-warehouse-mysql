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
| 10 | `10_incremental_load_setup.sql` | Run once: `stg_row_id`, watermark, run log and reject log tables |
| 11 | `11_sp_incremental_load.sql` | Stored procedure `sp_load_orders_incremental()` and reconciliation view |

## Key finding that shaped the model

The quality checks showed the data is not consistent per entity:

- 500+ `product_id` values are assigned to 3-5 different categories and to several brands, so there is **no `dim_product`**; product attributes stay in `fact_orders`.
- 9,000 sellers have 229,498 distinct (`seller_id`, `seller_rating`) pairs, so `seller_rating` is stored in the fact table and `dim_seller` keeps only `seller_id`.

## Incremental load

`CALL sp_load_orders_incremental();` loads only the staging rows that arrived since the last run:

- A watermark (`etl_watermark`) remembers the last processed `stg_row_id`, so old rows are never loaded twice and new rows are not skipped.
- Invalid rows (missing location/seller/date, negative price, final price above price, rating outside 0-5, negative shipping time) are rejected with a reason in `etl_reject_log`.
- Everything runs in one transaction. On error it rolls back, the watermark does not move, and the failure is written to `etl_run_log`; running it again is safe.
- After loading, `loaded + rejected = extracted` is checked, and `v_reconciliation` shows `stg_rows - fact_rows - rejected_rows = 0`.

Tested on a 20,000-row sample plus two new batches (including bad rows): rejected rows logged with reasons, a second run with no new data loaded nothing, a forced failure rolled back cleanly, and the retry succeeded with zero unexplained difference.

Data lineage and column descriptions: [`Documentation/Data_Dictionary.md`](Documentation/Data_Dictionary.md).

## Run

1. Download the dataset (`amazon_ecommerce_1M.csv`, not included in this repo because of its size) and place it in a folder allowed by MySQL `secure_file_priv`.
2. Run the scripts in `SQL/` in order (01 to 11) on MySQL 8.0. To add new data later, load it into `stg_orders` (see the comment at the end of script 10) and call the procedure.

## Stack

MySQL 8.0, SQL, star schema / dimensional modeling.
