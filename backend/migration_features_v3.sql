-- ============================================================
-- MIGRATION v3: Full Feature Upgrade
-- Safe to run on existing food_delivery_v2 database
-- Run: mysql -u root food_delivery_v2 < migration_features_v3.sql
-- ============================================================

USE `food_delivery_v2`;

-- ── 1. LOCATION TRACKING TABLE (all roles, every 5s) ─────────
CREATE TABLE IF NOT EXISTS `location_tracking` (
  `id`        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`   INT UNSIGNED NOT NULL,
  `role`      ENUM('customer','restaurant','delivery') NOT NULL,
  `lat`       DECIMAL(10,8) NOT NULL,
  `lng`       DECIMAL(11,8) NOT NULL,
  `recorded_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `lt_user_role` (`user_id`, `role`),
  KEY `lt_recorded_at` (`recorded_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── 2. RESTAURANTS: add operator_status ──────────────────────
ALTER TABLE `restaurants`
  ADD COLUMN IF NOT EXISTS `operator_status`
      ENUM('online','busy','closed') NOT NULL DEFAULT 'online'
      AFTER `is_open`,
  ADD COLUMN IF NOT EXISTS `cuisine` VARCHAR(100) DEFAULT NULL
      AFTER `name`,
  ADD COLUMN IF NOT EXISTS `status` VARCHAR(50) DEFAULT 'approved'
      AFTER `cuisine`,
  ADD COLUMN IF NOT EXISTS `image` VARCHAR(255) DEFAULT NULL
      AFTER `image_url`,
  ADD COLUMN IF NOT EXISTS `opening_time` TIME DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `closing_time` TIME DEFAULT NULL;

-- ── 3. ORDERS: add new delivery fields + status timestamps ────
ALTER TABLE `orders`
  ADD COLUMN IF NOT EXISTS `delivery_option`
      ENUM('current','custom') NOT NULL DEFAULT 'current'
      AFTER `address_id`,
  ADD COLUMN IF NOT EXISTS `flat_no` VARCHAR(100) DEFAULT NULL
      AFTER `delivery_option`,
  ADD COLUMN IF NOT EXISTS `landmark` VARCHAR(255) DEFAULT NULL
      AFTER `flat_no`,
  ADD COLUMN IF NOT EXISTS `delivery_lat` DECIMAL(10,8) DEFAULT NULL
      AFTER `landmark`,
  ADD COLUMN IF NOT EXISTS `delivery_lng` DECIMAL(11,8) DEFAULT NULL
      AFTER `delivery_lat`,
  ADD COLUMN IF NOT EXISTS `accepted_at`   DATETIME DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `preparing_at`  DATETIME DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `ready_at`      DATETIME DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `assigned_at`   DATETIME DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `broadcast_attempts` TINYINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `broadcast_started_at` DATETIME DEFAULT NULL;

-- ── 4. DELIVERY_BOYS: broadcast + online tracking ─────────────
ALTER TABLE `delivery_boys`
  ADD COLUMN IF NOT EXISTS `is_online` TINYINT(1) NOT NULL DEFAULT 1
      AFTER `status`,
  ADD COLUMN IF NOT EXISTS `active_order_id` INT UNSIGNED DEFAULT NULL
      AFTER `is_online`;

-- ── 5. DELIVERY_REQUESTS: 30-second timer + retry ─────────────
ALTER TABLE `delivery_requests`
  ADD COLUMN IF NOT EXISTS `expires_at` DATETIME DEFAULT NULL
      AFTER `created_at`,
  ADD COLUMN IF NOT EXISTS `cancelled_reason` VARCHAR(255) DEFAULT NULL;

-- Update existing delivery_requests to have request_status column support 'missed'
ALTER TABLE `delivery_requests`
  MODIFY COLUMN `request_status`
    ENUM('pending','accepted','rejected','missed','cancelled') NOT NULL DEFAULT 'pending';

-- ── 6. ORDERS: update order_status to include all 7 steps ─────
ALTER TABLE `orders`
  MODIFY COLUMN `order_status`
    ENUM(
      'pending',
      'accepted',
      'preparing',
      'ready_for_pickup',
      'assigned',
      'reached_restaurant',
      'out_for_delivery',
      'delivered',
      'cancelled',
      'rejected'
    ) NOT NULL DEFAULT 'pending';

-- ── 7. EARNINGS: base_charge + distance_charge per delivery ───
-- delivery_boys already has total_earnings; we add per-order details to orders:
ALTER TABLE `orders`
  ADD COLUMN IF NOT EXISTS `boy_base_charge`     DECIMAL(8,2) NOT NULL DEFAULT 30.00,
  ADD COLUMN IF NOT EXISTS `boy_distance_charge` DECIMAL(8,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS `boy_tip_paid`        DECIMAL(8,2) NOT NULL DEFAULT 0.00;

-- ── 8. SETTINGS: add delivery speed for ETA calc ─────────────
INSERT IGNORE INTO `settings` (`setting_key`, `value`) VALUES
  ('delivery_avg_speed_kmh', '30'),
  ('broadcast_radius_km', '20'),
  ('broadcast_timeout_sec', '30'),
  ('broadcast_max_retries', '3'),
  ('broadcast_total_timeout_sec', '300'),
  ('restaurant_visibility_radius', '20');

-- ── 9. ADDRESSES: add extra detail fields ─────────────────────
ALTER TABLE `addresses`
  ADD COLUMN IF NOT EXISTS `flat_no`  VARCHAR(100) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `landmark` VARCHAR(255) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `label`    VARCHAR(100) DEFAULT 'Home';

-- ── Done ──────────────────────────────────────────────────────
SELECT 'Migration v3 complete' AS status;
