-- ============================================
-- 02_create_staging_table.sql
-- Bảng staging chứa dữ liệu thô từ CSV
-- Nguyên tắc: đa số cột VARCHAR để tránh lỗi kiểu
--             dữ liệu khi LOAD DATA INFILE
-- ============================================

USE ecommerce_db;

CREATE TABLE stg_orders (
    user_id             VARCHAR(20),
    product_id          VARCHAR(20),
    category             VARCHAR(50),
    subcategory          VARCHAR(50),
    brand                VARCHAR(50),
    price                DECIMAL(10,2),
    discount              DECIMAL(10,2),
    final_price           DECIMAL(10,2),
    rating                DECIMAL(3,1),
    review_count          INT,
    stock                 INT,
    seller_id             VARCHAR(20),
    seller_rating         DECIMAL(3,1),
    purchase_date         DATE,
    shipping_time_days    INT,
    location               VARCHAR(50),
    device                 VARCHAR(30),
    payment_method         VARCHAR(30),
    is_returned            VARCHAR(10),   -- VARCHAR vì CSV lưu 'True'/'False' dạng chữ
    delivery_status        VARCHAR(30)
);
