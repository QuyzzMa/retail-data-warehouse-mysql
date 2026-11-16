-- ============================================
-- 08_load_fact_table.sql
-- Nạp dữ liệu vào fact_orders, JOIN với 3 bảng dim
-- để lấy đúng surrogate key
-- Yêu cầu: file 07 phải chạy XONG HOÀN TOÀN trước
-- (fact_orders cần các dim key đã tồn tại)
-- ============================================

USE ecommerce_db;

INSERT INTO fact_orders (
    location_key, seller_key, date_key,
    product_id, brand, category, subcategory,
    price, discount, final_price, rating, seller_rating,
    review_count, stock, shipping_time_days,
    device, payment_method, is_returned, delivery_status, user_id
)
SELECT
    l.location_key,
    s.seller_key,
    d.date_key,
    so.product_id, so.brand, so.category, so.subcategory,
    so.price, so.discount, so.final_price, so.rating, so.seller_rating,
    so.review_count, so.stock, so.shipping_time_days,
    so.device, so.payment_method, so.is_returned, so.delivery_status, so.user_id
FROM stg_orders so
JOIN dim_location l ON so.location = l.location
JOIN dim_seller   s ON so.seller_id = s.seller_id
JOIN dim_date     d ON so.purchase_date = d.full_date;

-- Kiểm tra: kỳ vọng đúng 1,000,000 (khớp với stg_orders)
-- Nếu ra ít hơn: có dòng bị INNER JOIN loại bỏ -> kiểm tra
-- riêng từng JOIN để cô lập bảng dim nào bị thiếu dữ liệu:
--   SELECT COUNT(*) FROM stg_orders so JOIN dim_location l ON so.location = l.location;
--   SELECT COUNT(*) FROM stg_orders so JOIN dim_seller   s ON so.seller_id = s.seller_id;
--   SELECT COUNT(*) FROM stg_orders so JOIN dim_date     d ON so.purchase_date = d.full_date;
SELECT COUNT(*) FROM fact_orders;
