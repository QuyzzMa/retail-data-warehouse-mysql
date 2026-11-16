-- ============================================
-- 04_data_quality_checks.sql
-- Kiểm tra chất lượng dữ liệu staging trước khi
-- chuyển sang tầng warehouse
-- ============================================

USE ecommerce_db;

-- 1. Đếm NULL ở user_id
SELECT COUNT(*) FROM stg_orders WHERE user_id IS NULL;

-- 2. Đếm NULL ở rating
SELECT COUNT(*) FROM stg_orders WHERE rating IS NULL;

-- 3. Kiểm tra các giá trị delivery_status (phát hiện lỗi chính tả/không nhất quán)
SELECT DISTINCT delivery_status FROM stg_orders;

-- 4. Kiểm tra dòng trùng lặp hoàn toàn (toàn bộ 20 cột giống hệt nhau)
SELECT user_id, product_id, category, subcategory, brand, price, discount,
       final_price, rating, review_count, stock, seller_id, seller_rating,
       purchase_date, shipping_time_days, location, device, payment_method,
       is_returned, delivery_status,
       COUNT(*) AS so_lan_xuat_hien
FROM stg_orders
GROUP BY user_id, product_id, category, subcategory, brand, price, discount,
         final_price, rating, review_count, stock, seller_id, seller_rating,
         purchase_date, shipping_time_days, location, device, payment_method,
         is_returned, delivery_status
HAVING so_lan_xuat_hien > 1;

-- 5. Kiểm tra price âm hoặc final_price > price (vô lý)
SELECT COUNT(*) FROM stg_orders WHERE price < 0 OR final_price > price;

-- 6. Kiểm tra rating ngoài khoảng hợp lệ (0-5)
SELECT COUNT(*) FROM stg_orders WHERE rating < 0 OR rating > 5;

-- 7. Kiểm tra shipping_time_days âm
SELECT COUNT(*) FROM stg_orders WHERE shipping_time_days < 0;

-- 8. [QUAN TRỌNG] Kiểm tra product_id có bị gán nhiều category khác nhau không
--    -> Kết quả: 500+ product_id bị gán 3-5 category khác nhau
--    -> Kết luận: category thuộc về ĐƠN HÀNG, không phải sản phẩm
SELECT product_id, COUNT(DISTINCT category) AS so_category_khac_nhau
FROM stg_orders
GROUP BY product_id
HAVING so_category_khac_nhau > 1;

-- 9. [QUAN TRỌNG] Kiểm tra product_id có bị gán nhiều brand khác nhau không
--    -> Kết quả: 500+ dòng -> brand cũng không nhất quán theo product_id
--    -> Kết luận: bỏ hẳn dim_product, đưa product_id/brand vào fact_orders
SELECT product_id, COUNT(DISTINCT brand) AS so_brand_khac_nhau
FROM stg_orders
GROUP BY product_id
HAVING so_brand_khac_nhau > 1;

-- 10. [QUAN TRỌNG] Kiểm tra seller_id có bị gán nhiều seller_rating khác nhau không
--     -> Kết quả: 9,000 seller_id nhưng 229,498 cặp (seller_id, seller_rating) khác nhau
--     -> Kết luận: seller_rating không cố định theo seller -> đưa vào fact_orders,
--        dim_seller chỉ giữ lại seller_id
SELECT COUNT(DISTINCT seller_id) AS so_seller_khac_nhau,
       COUNT(DISTINCT seller_id, seller_rating) AS so_cap_seller_rating_khac_nhau
FROM stg_orders;

-- 11. Kiểm tra NULL ở 3 cột dùng để JOIN sang các bảng dim (bắt buộc trước khi JOIN)
SELECT
    SUM(CASE WHEN location IS NULL THEN 1 ELSE 0 END) AS null_location,
    SUM(CASE WHEN seller_id IS NULL THEN 1 ELSE 0 END) AS null_seller_id,
    SUM(CASE WHEN purchase_date IS NULL THEN 1 ELSE 0 END) AS null_purchase_date
FROM stg_orders;
