# Data Dictionary & Data Lineage

Database: `ecommerce_db` (MySQL 8.0).

## 1. Data lineage

```
amazon_ecommerce_1M.csv
        |  LOAD DATA INFILE (03_load_raw_data.sql)
        v
stg_orders  (Staging: dữ liệu thô, thêm stg_row_id)
        |  Kiểm tra chất lượng (04) / lọc dòng lỗi (11)
        |  INSERT ... SELECT DISTINCT / sp_load_orders_incremental (07, 08, 11)
        v
dim_location    dim_seller    dim_date        <- dimension
              \       |       /
               fact_orders                    <- fact (Core)
                    |
        09_business_analytics.sql             <- truy vấn phân tích

Giám sát: etl_watermark, etl_run_log, etl_reject_log, v_reconciliation
```

| Đích | Nguồn | Quy tắc biến đổi |
|---|---|---|
| `dim_location.location` | `stg_orders.location` | `SELECT DISTINCT`, bỏ NULL/rỗng |
| `dim_seller.seller_id` | `stg_orders.seller_id` | `SELECT DISTINCT`, bỏ NULL/rỗng |
| `dim_date.*` | `stg_orders.purchase_date` | `DISTINCT`; `year`, `month`, `quarter`, `day_of_week` tính từ ngày |
| `fact_orders.*` | `stg_orders` + 3 dimension | JOIN lấy surrogate key; các cột đo lường giữ nguyên |
| `fact_orders.stg_row_id`, `etl_run_id` | `stg_orders.stg_row_id`, `etl_run_log.run_id` | Chỉ có ở dòng nạp qua procedure (dòng nạp lần đầu = NULL) |

## 2. Staging

### `stg_orders`
Dữ liệu thô từ CSV, 1 dòng = 1 đơn hàng.

| Cột | Kiểu | Mô tả |
|---|---|---|
| `stg_row_id` | BIGINT, PK, tự tăng | Số thứ tự dòng staging, dùng làm watermark nạp gia tăng (thêm ở file 10) |
| `user_id` | VARCHAR(20) | Mã khách hàng |
| `product_id` | VARCHAR(20) | Mã sản phẩm (không ổn định theo category/brand) |
| `category`, `subcategory` | VARCHAR(50) | Danh mục, danh mục con |
| `brand` | VARCHAR(50) | Thương hiệu |
| `price` | DECIMAL(10,2) | Giá niêm yết |
| `discount` | DECIMAL(10,2) | Mức giảm giá |
| `final_price` | DECIMAL(10,2) | Giá sau giảm (doanh thu của đơn) |
| `rating` | DECIMAL(3,1) | Điểm đánh giá 0-5 (có thể NULL) |
| `review_count` | INT | Số lượt đánh giá |
| `stock` | INT | Tồn kho |
| `seller_id` | VARCHAR(20) | Mã nhà bán hàng |
| `seller_rating` | DECIMAL(3,1) | Điểm nhà bán hàng (không cố định theo seller) |
| `purchase_date` | DATE | Ngày mua |
| `shipping_time_days` | INT | Số ngày giao hàng |
| `location` | VARCHAR(50) | Thành phố |
| `device` | VARCHAR(30) | Thiết bị mua |
| `payment_method` | VARCHAR(30) | Phương thức thanh toán |
| `is_returned` | VARCHAR(10) | `True`/`False` dạng chữ |
| `delivery_status` | VARCHAR(30) | Trạng thái giao hàng |

## 3. Dimension

| Bảng | Cột | Kiểu | Mô tả |
|---|---|---|---|
| `dim_location` | `location_key` (PK) | INT, tự tăng | Surrogate key |
| | `location` | VARCHAR(50) | Tên thành phố |
| `dim_seller` | `seller_key` (PK) | INT, tự tăng | Surrogate key |
| | `seller_id` | VARCHAR(20) | Mã nhà bán hàng |
| `dim_date` | `date_key` (PK) | INT, tự tăng | Surrogate key |
| | `full_date` | DATE | Ngày |
| | `year`, `month`, `quarter` | INT | Năm, tháng, quý |
| | `day_of_week` | VARCHAR(10) | Thứ trong tuần |

Không có `dim_product`: `product_id` bị gán nhiều category/brand nên giữ trong fact.

## 4. Fact

### `fact_orders`
Grain: 1 dòng = 1 đơn hàng.

| Cột | Kiểu | Mô tả |
|---|---|---|
| `order_key` | INT, PK, tự tăng | Khóa dòng |
| `seller_key`, `location_key`, `date_key` | INT, FK | Khóa sang 3 dimension |
| `product_id`, `brand`, `category`, `subcategory` | VARCHAR | Thuộc tính sản phẩm (giữ trong fact) |
| `price`, `discount`, `final_price` | DECIMAL(10,2) | Giá, giảm giá, giá cuối |
| `rating`, `seller_rating` | DECIMAL(3,1) | Điểm đánh giá |
| `review_count`, `stock`, `shipping_time_days` | INT | Số đo |
| `device`, `payment_method`, `is_returned`, `delivery_status`, `user_id` | VARCHAR | Thuộc tính đơn hàng |
| `stg_row_id` | BIGINT, UNIQUE | Dòng staging nguồn (lineage), chống trùng |
| `etl_run_id` | INT | Lần chạy ETL đã nạp dòng này |

## 5. Bảng giám sát ETL

| Bảng / View | Mục đích |
|---|---|
| `etl_watermark` | `stg_row_id` lớn nhất đã xử lý, mỗi pipeline 1 dòng |
| `etl_run_log` | Mỗi lần chạy: thời gian, trạng thái (RUNNING/SUCCESS/FAILED), khoảng dòng, số dòng nạp/loại, thông báo lỗi |
| `etl_reject_log` | Dòng bị loại và lý do |
| `v_reconciliation` | Đối soát `stg_rows - fact_rows - rejected_rows`, phải bằng 0 |

Lý do loại dòng: `MISSING_LOCATION`, `MISSING_SELLER`, `MISSING_PURCHASE_DATE`, `NEGATIVE_PRICE`, `FINAL_PRICE_GT_PRICE`, `RATING_OUT_OF_RANGE`, `NEGATIVE_SHIPPING_TIME`.
