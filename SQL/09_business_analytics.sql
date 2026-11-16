-- ============================================
-- 09_analytics_queries.sql
-- Câu hỏi kinh doanh từ Business Context
-- ============================================

USE ecommerce_db;

-- "Khu vực nào mang lại hiệu quả kinh doanh cao nhất?"
SELECT
    l.location,
    SUM(f.final_price) AS tong_doanh_thu,
    COUNT(*) AS so_don_hang
FROM fact_orders f
JOIN dim_location l ON f.location_key = l.location_key
GROUP BY l.location
ORDER BY tong_doanh_thu DESC;

-- "Nhà bán hàng nào đang hoạt động hiệu quả nhất?"
-- (đang luyện tập cùng mentor -- điền tiếp theo khuôn mẫu trên)
SELECT
    s.seller_id,
    SUM(f.final_price) AS tong_doanh_thu,
    AVG(f.seller_rating) AS rating_trung_binh
FROM fact_orders f
JOIN dim_seller s ON f.seller_key = s.seller_key
GROUP BY s.seller_id
ORDER BY tong_doanh_thu DESC;

USE ecommerce_db;

SELECT
    s.seller_id,
    SUM(f.final_price) AS tong_doanh_thu,
    AVG(f.seller_rating) AS rating_trung_binh,
    COUNT(f.order_key) AS so_don_hang
FROM dim_seller s
LEFT JOIN fact_orders f ON s.seller_key = f.seller_key
GROUP BY s.seller_id
ORDER BY tong_doanh_thu DESC;

SELECT
    s.seller_id,
    COUNT(f.order_key) AS so_don_hang
FROM dim_seller s
LEFT JOIN fact_orders f ON s.seller_key = f.seller_key
GROUP BY s.seller_id
HAVING so_don_hang = 0;

SELECT COUNT(DISTINCT seller_key) FROM fact_orders;
