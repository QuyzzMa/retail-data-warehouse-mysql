-- ============================================
-- 10_incremental_load_setup.sql
-- Chuẩn bị nạp dữ liệu gia tăng (incremental load)
-- Yêu cầu: file 01-08 đã chạy xong (fact_orders đã có đủ dữ liệu)
-- CHẠY 1 LẦN DUY NHẤT trên database đã dựng xong
--
-- Ý tưởng:
--   * Mỗi dòng staging có 1 khóa tăng dần (stg_row_id).
--   * Bảng etl_watermark nhớ stg_row_id lớn nhất đã được xử lý.
--   * Mỗi lần chạy chỉ xử lý các dòng có stg_row_id > watermark
--     -> không nạp lại dòng cũ (không trùng) và không bỏ sót dòng mới.
-- ============================================

USE ecommerce_db;

-- 1. Khóa tăng dần cho bảng staging
ALTER TABLE stg_orders
    ADD COLUMN stg_row_id BIGINT NOT NULL AUTO_INCREMENT,
    ADD PRIMARY KEY (stg_row_id);

-- 2. Fact lưu lại dòng staging nguồn và lần chạy ETL đã nạp nó (phục vụ data lineage)
--    Các dòng nạp lần đầu (file 08) có 2 cột này = NULL.
ALTER TABLE fact_orders
    ADD COLUMN stg_row_id BIGINT NULL,
    ADD COLUMN etl_run_id INT NULL,
    ADD UNIQUE KEY uq_fact_stg_row_id (stg_row_id);

-- 3. Watermark: vị trí đã xử lý đến đâu
CREATE TABLE etl_watermark (
    pipeline_name    VARCHAR(50) PRIMARY KEY,
    last_stg_row_id  BIGINT      NOT NULL DEFAULT 0,
    updated_at       DATETIME    NOT NULL
);

-- 4. Nhật ký mỗi lần chạy (thành công / thất bại, số dòng)
CREATE TABLE etl_run_log (
    run_id          INT AUTO_INCREMENT PRIMARY KEY,
    pipeline_name   VARCHAR(50) NOT NULL,
    started_at      DATETIME    NOT NULL,
    finished_at     DATETIME    NULL,
    status          VARCHAR(10) NOT NULL,      -- RUNNING / SUCCESS / FAILED
    from_row_id     BIGINT      NULL,          -- watermark trước khi chạy
    to_row_id       BIGINT      NULL,          -- watermark sau khi chạy
    rows_extracted  INT         NULL,          -- số dòng staging mới
    rows_loaded     INT         NULL,          -- số dòng vào fact_orders
    rows_rejected   INT         NULL,          -- số dòng bị loại
    error_message   TEXT        NULL
);

-- 5. Dòng bị loại kèm lý do (để đối soát và xử lý sai lệch)
CREATE TABLE etl_reject_log (
    reject_id    INT AUTO_INCREMENT PRIMARY KEY,
    run_id       INT         NOT NULL,
    stg_row_id   BIGINT      NOT NULL,
    reason       VARCHAR(40) NOT NULL,
    FOREIGN KEY (run_id) REFERENCES etl_run_log(run_id)
);

-- 6. Đặt watermark = toàn bộ staging hiện có (vì file 08 đã nạp hết vào fact)
INSERT INTO etl_watermark (pipeline_name, last_stg_row_id, updated_at)
SELECT 'orders_incremental', COALESCE(MAX(stg_row_id), 0), NOW()
FROM stg_orders;

-- Kiểm tra
SELECT * FROM etl_watermark;

-- ============================================
-- Cách nạp 1 đợt dữ liệu mới vào staging (ví dụ file mới.csv):
-- PHẢI liệt kê cột, vì stg_orders giờ có thêm cột stg_row_id tự tăng
--
-- LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/new_batch.csv'
-- INTO TABLE stg_orders
-- FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS
-- (user_id, product_id, category, subcategory, brand, price, discount,
--  final_price, rating, review_count, stock, seller_id, seller_rating,
--  purchase_date, shipping_time_days, location, device, payment_method,
--  is_returned, delivery_status);
--
-- Sau đó chạy: CALL sp_load_orders_incremental();   (file 11)
-- ============================================
