-- ============================================
-- 07_load_dimension_tables.sql
-- Nạp dữ liệu vào các bảng dimension bằng
-- INSERT INTO ... SELECT DISTINCT
-- Yêu cầu: file 06 phải chạy xong trước
-- ============================================

USE ecommerce_db;

-- dim_location (kỳ vọng: 5 dòng)
INSERT INTO dim_location (location)
SELECT DISTINCT location
FROM stg_orders
WHERE location IS NOT NULL;

-- dim_seller (kỳ vọng: 9,000 dòng)
-- CHÚ Ý: chỉ SELECT DISTINCT 1 cột seller_id, KHÔNG kèm
-- seller_rating -- nếu kèm sẽ ra gần 230,000 dòng sai
-- (vì seller_rating không cố định theo seller_id)
INSERT INTO dim_seller (seller_id)
SELECT DISTINCT seller_id
FROM stg_orders
WHERE seller_id IS NOT NULL;

-- dim_date (kỳ vọng: 731 dòng)
-- Dùng hàm tách ngày: YEAR, MONTH, QUARTER, DAYNAME
-- Chỉ cần DISTINCT trên purchase_date vì 4 cột còn lại
-- luôn được TÍNH RA từ purchase_date (deterministic),
-- không thể có 2 giá trị khác nhau cho cùng 1 ngày.
INSERT INTO dim_date (full_date, year, month, quarter, day_of_week)
SELECT DISTINCT
    purchase_date,
    YEAR(purchase_date),
    MONTH(purchase_date),
    QUARTER(purchase_date),
    DAYNAME(purchase_date)
FROM stg_orders
WHERE purchase_date IS NOT NULL;

-- Kiểm tra sau khi nạp xong (chạy để xác nhận, không phải đoán)
SELECT COUNT(*) FROM dim_location;  -- kỳ vọng 5
SELECT COUNT(*) FROM dim_seller;    -- kỳ vọng 9000
SELECT COUNT(*) FROM dim_date;      -- kỳ vọng 731
