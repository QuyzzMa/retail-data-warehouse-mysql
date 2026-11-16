-- ============================================
-- 03_load_staging_data.sql
-- Mục đích: Nạp 1 triệu dòng CSV vào stg_orders
-- Lưu ý: file CSV phải nằm trong thư mục MySQL
--        cho phép đọc (secure_file_priv)
-- ============================================

USE ecommerce_db;

-- Kiểm tra thư mục MySQL cho phép đọc file (chạy 1 lần để xác nhận)
SHOW VARIABLES LIKE 'secure_file_priv';

-- Nạp dữ liệu (đường dẫn cần khớp với secure_file_priv ở trên)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/amazon_ecommerce_1M.csv'
INTO TABLE stg_orders
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;   -- bỏ qua dòng header

-- Kiểm tra số dòng đã nạp
SELECT COUNT(*) FROM stg_orders;
