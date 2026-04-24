-- =========================================================
-- Migration: Add reviews, tips, and radius features
-- =========================================================

-- 1. Create reviews table if not exists (consolidating existing logic)
CREATE TABLE IF NOT EXISTS `reviews` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `order_id` INT UNSIGNED NOT NULL,
  `user_id` INT UNSIGNED NOT NULL,
  `rating` TINYINT UNSIGNED NOT NULL,
  `comment` TEXT NULL,
  `review_for` ENUM('restaurant', 'delivery_boy') NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `order_user_review` (`order_id`, `user_id`, `review_for`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. Add tip_amount to orders
ALTER TABLE `orders`
  ADD COLUMN IF NOT EXISTS `tip_amount` DECIMAL(10,2) NOT NULL DEFAULT 0.00
  AFTER `total_amount`;

-- 3. Ensure rating columns exist in restaurants if not already there (rating_avg is already there, but let's be sure about precision)
ALTER TABLE `restaurants`
  MODIFY COLUMN `rating_avg` DECIMAL(3,2) NOT NULL DEFAULT 0.00,
  MODIFY COLUMN `rating_count` INT UNSIGNED NOT NULL DEFAULT 0;

-- 4. Add rating columns to delivery_boys
ALTER TABLE `delivery_boys`
  ADD COLUMN IF NOT EXISTS `rating_avg` DECIMAL(3,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS `rating_count` INT UNSIGNED NOT NULL DEFAULT 0;

-- 5. Add visibility radius setting
INSERT IGNORE INTO `settings` (`setting_key`, `value`) VALUES ('restaurant_visibility_radius', '15');

-- 6. Ensure image_url exists
ALTER TABLE `restaurants`
  ADD COLUMN IF NOT EXISTS `image_url` VARCHAR(500) NULL DEFAULT NULL
  AFTER `status`;

-- Sync existing image data if any (optional helper)
-- UPDATE restaurants SET image_url = CONCAT('http://localhost:8000/uploads/restaurants/', image) WHERE image IS NOT NULL AND image_url IS NULL;
