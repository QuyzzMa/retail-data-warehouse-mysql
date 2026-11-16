-- ============================================
-- 11_sp_incremental_load.sql
-- Stored Procedure nạp gia tăng: staging -> dim_* + fact_orders
-- Yêu cầu: file 10 đã chạy
--
-- Đặc điểm:
--   * Chỉ xử lý dòng staging mới (stg_row_id > watermark).
--   * Chạy trong 1 transaction: lỗi giữa chừng thì ROLLBACK,
--     watermark không đổi -> chạy lại không mất và không trùng dữ liệu.
--   * Loại dòng không hợp lệ và ghi lý do vào etl_reject_log.
--   * Đối soát cuối bước: số dòng nạp + số dòng loại phải bằng số dòng mới.
--   * Ghi nhật ký mỗi lần chạy vào etl_run_log (kể cả khi thất bại).
-- ============================================

USE ecommerce_db;

DROP PROCEDURE IF EXISTS sp_load_orders_incremental;

DELIMITER $$

CREATE PROCEDURE sp_load_orders_incremental()
BEGIN
    DECLARE v_run_id    INT;
    DECLARE v_from      BIGINT;
    DECLARE v_to        BIGINT;
    DECLARE v_extracted INT DEFAULT 0;
    DECLARE v_loaded    INT DEFAULT 0;
    DECLARE v_rejected  INT DEFAULT 0;
    DECLARE v_err       TEXT;

    -- Lỗi bất kỳ: hoàn tác, ghi log FAILED, rồi báo lỗi ra cho nơi gọi
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
        ROLLBACK;
        UPDATE etl_run_log
           SET status = 'FAILED', finished_at = NOW(), error_message = v_err
         WHERE run_id = v_run_id;
        RESIGNAL;
    END;

    -- Ghi log trước transaction để log không bị ROLLBACK cuốn đi
    INSERT INTO etl_run_log (pipeline_name, started_at, status)
    VALUES ('orders_incremental', NOW(), 'RUNNING');
    SET v_run_id = LAST_INSERT_ID();

    SELECT last_stg_row_id INTO v_from
      FROM etl_watermark WHERE pipeline_name = 'orders_incremental';
    SELECT COALESCE(MAX(stg_row_id), v_from) INTO v_to FROM stg_orders;

    START TRANSACTION;

    -- 1. Kiểm tra từng dòng mới, gán lý do nếu không hợp lệ
    DROP TEMPORARY TABLE IF EXISTS tmp_batch;
    CREATE TEMPORARY TABLE tmp_batch AS
    SELECT stg_row_id,
           CASE
               WHEN location IS NULL OR TRIM(location) = ''     THEN 'MISSING_LOCATION'   -- CSV ô trống = chuỗi rỗng, không phải NULL
               WHEN seller_id IS NULL OR TRIM(seller_id) = ''   THEN 'MISSING_SELLER'
               WHEN purchase_date IS NULL                       THEN 'MISSING_PURCHASE_DATE'
               WHEN price < 0                       THEN 'NEGATIVE_PRICE'
               WHEN final_price > price             THEN 'FINAL_PRICE_GT_PRICE'
               WHEN rating < 0 OR rating > 5        THEN 'RATING_OUT_OF_RANGE'
               WHEN shipping_time_days < 0          THEN 'NEGATIVE_SHIPPING_TIME'
               ELSE NULL
           END AS reject_reason
    FROM stg_orders
    WHERE stg_row_id > v_from AND stg_row_id <= v_to;

    SELECT COUNT(*) INTO v_extracted FROM tmp_batch;

    INSERT INTO etl_reject_log (run_id, stg_row_id, reason)
    SELECT v_run_id, stg_row_id, reject_reason
      FROM tmp_batch WHERE reject_reason IS NOT NULL;
    SET v_rejected = ROW_COUNT();

    -- 2. Dimension: chỉ thêm giá trị CHƯA có (từ các dòng hợp lệ)
    INSERT INTO dim_location (location)
    SELECT DISTINCT s.location
      FROM stg_orders s JOIN tmp_batch b ON b.stg_row_id = s.stg_row_id
     WHERE b.reject_reason IS NULL
       AND NOT EXISTS (SELECT 1 FROM dim_location d WHERE d.location = s.location);

    INSERT INTO dim_seller (seller_id)
    SELECT DISTINCT s.seller_id
      FROM stg_orders s JOIN tmp_batch b ON b.stg_row_id = s.stg_row_id
     WHERE b.reject_reason IS NULL
       AND NOT EXISTS (SELECT 1 FROM dim_seller d WHERE d.seller_id = s.seller_id);

    INSERT INTO dim_date (full_date, year, month, quarter, day_of_week)
    SELECT DISTINCT s.purchase_date, YEAR(s.purchase_date), MONTH(s.purchase_date),
                    QUARTER(s.purchase_date), DAYNAME(s.purchase_date)
      FROM stg_orders s JOIN tmp_batch b ON b.stg_row_id = s.stg_row_id
     WHERE b.reject_reason IS NULL
       AND NOT EXISTS (SELECT 1 FROM dim_date d WHERE d.full_date = s.purchase_date);

    -- 3. Fact: nạp các dòng hợp lệ (NOT EXISTS là lớp bảo vệ thứ 2 chống trùng)
    INSERT INTO fact_orders (
        location_key, seller_key, date_key,
        product_id, brand, category, subcategory,
        price, discount, final_price, rating, seller_rating,
        review_count, stock, shipping_time_days,
        device, payment_method, is_returned, delivery_status, user_id,
        stg_row_id, etl_run_id
    )
    SELECT l.location_key, sl.seller_key, d.date_key,
           so.product_id, so.brand, so.category, so.subcategory,
           so.price, so.discount, so.final_price, so.rating, so.seller_rating,
           so.review_count, so.stock, so.shipping_time_days,
           so.device, so.payment_method, so.is_returned, so.delivery_status, so.user_id,
           so.stg_row_id, v_run_id
      FROM stg_orders so
      JOIN tmp_batch    b  ON b.stg_row_id = so.stg_row_id AND b.reject_reason IS NULL
      JOIN dim_location l  ON l.location   = so.location
      JOIN dim_seller   sl ON sl.seller_id = so.seller_id
      JOIN dim_date     d  ON d.full_date  = so.purchase_date
     WHERE NOT EXISTS (SELECT 1 FROM fact_orders f WHERE f.stg_row_id = so.stg_row_id);
    SET v_loaded = ROW_COUNT();

    -- 4. Đối soát: mọi dòng mới phải hoặc vào fact, hoặc bị loại có lý do
    IF v_loaded + v_rejected <> v_extracted THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Reconciliation failed: loaded + rejected <> extracted';
    END IF;

    -- 5. Chốt: cập nhật watermark và log trong cùng transaction
    UPDATE etl_watermark
       SET last_stg_row_id = v_to, updated_at = NOW()
     WHERE pipeline_name = 'orders_incremental';

    UPDATE etl_run_log
       SET status = 'SUCCESS', finished_at = NOW(),
           from_row_id = v_from, to_row_id = v_to,
           rows_extracted = v_extracted, rows_loaded = v_loaded, rows_rejected = v_rejected
     WHERE run_id = v_run_id;

    COMMIT;
    DROP TEMPORARY TABLE IF EXISTS tmp_batch;
END$$

DELIMITER ;

-- ============================================
-- View đối soát: staging so với fact + dòng bị loại
-- Cột chenh_lech_chua_giai_thich phải = 0
-- (dòng nạp lần đầu ở file 08 không đi qua bước loại nên không có trong etl_reject_log)
-- ============================================
CREATE OR REPLACE VIEW v_reconciliation AS
SELECT
    (SELECT COUNT(*) FROM stg_orders)      AS stg_rows,
    (SELECT COUNT(*) FROM fact_orders)     AS fact_rows,
    (SELECT COUNT(*) FROM etl_reject_log)  AS rejected_rows,
    (SELECT COUNT(*) FROM stg_orders)
      - (SELECT COUNT(*) FROM fact_orders)
      - (SELECT COUNT(*) FROM etl_reject_log) AS chenh_lech_chua_giai_thich;

-- Cách dùng:
--   CALL sp_load_orders_incremental();
--   SELECT * FROM etl_run_log ORDER BY run_id DESC LIMIT 5;
--   SELECT * FROM v_reconciliation;
