-- ============================================
-- 06_create_fact_table.sql
-- Bảng Fact trung tâm của Star Schema
-- Yêu cầu: file 05 phải chạy TRƯỚC (Foreign Key
-- cần dim_location/dim_seller/dim_date đã tồn tại)
--
-- product_id, brand, category, subcategory, seller_rating
-- nằm THẲNG trong bảng này (không qua dimension riêng)
-- vì đã xác nhận không nhất quán theo entity (file 04)
-- ============================================

USE ecommerce_db;

CREATE TABLE fact_orders (
    order_key           INT AUTO_INCREMENT PRIMARY KEY,
    seller_key          INT,
    location_key        INT,
    date_key             INT,
    product_id            VARCHAR(20),
    brand                 VARCHAR(50),
    category              VARCHAR(50),
    subcategory           VARCHAR(50),
    price                 DECIMAL(10,2),
    discount               DECIMAL(10,2),
    final_price            DECIMAL(10,2),
    rating                 DECIMAL(3,1),
    seller_rating           DECIMAL(3,1),
    review_count            INT,
    stock                   INT,
    shipping_time_days      INT,
    device                  VARCHAR(30),
    payment_method          VARCHAR(30),
    is_returned             VARCHAR(10),
    delivery_status         VARCHAR(30),
    user_id                 VARCHAR(20),
    FOREIGN KEY (seller_key)   REFERENCES dim_seller(seller_key),
    FOREIGN KEY (location_key) REFERENCES dim_location(location_key),
    FOREIGN KEY (date_key)     REFERENCES dim_date(date_key)
);
