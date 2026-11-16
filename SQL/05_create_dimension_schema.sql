-- ============================================
-- 05_create_dimension_tables.sql
-- Các bảng Dimension của Star Schema
-- LƯU Ý: KHÔNG có dim_product -- đã bỏ vì category,
-- brand đều không nhất quán theo product_id (xem
-- file 04, mục 8 và 9). product_id/brand được đưa
-- thẳng vào fact_orders.
-- ============================================

USE ecommerce_db;

-- Bảng địa điểm (chỉ ~5 thành phố khác nhau)
CREATE TABLE dim_location (
    location_key INT AUTO_INCREMENT PRIMARY KEY,
    location     VARCHAR(50)
);

-- Bảng ngày tháng
CREATE TABLE dim_date (
    date_key    INT AUTO_INCREMENT PRIMARY KEY,
    full_date   DATE,
    year        INT,
    month       INT,
    quarter     INT,
    day_of_week VARCHAR(10)
);

-- Bảng người bán
-- LƯU Ý: KHÔNG có seller_rating -- đã bỏ vì không cố định
-- theo seller_id (xem file 04, mục 10). seller_rating được
-- đưa thẳng vào fact_orders.
CREATE TABLE dim_seller (
    seller_key INT AUTO_INCREMENT PRIMARY KEY,
    seller_id  VARCHAR(20)
);
