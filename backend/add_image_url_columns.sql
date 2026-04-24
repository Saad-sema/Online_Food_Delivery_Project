-- =========================================================
-- Migration: Add image_url columns to restaurants & menu_items
-- Run this in your MySQL / phpMyAdmin
-- =========================================================

-- Add image_url to restaurants table
ALTER TABLE `restaurants`
  ADD COLUMN IF NOT EXISTS `image_url` VARCHAR(500) NULL DEFAULT NULL
  AFTER `status`;

-- Add image_url to menu_items table
ALTER TABLE `menu_items`
  ADD COLUMN IF NOT EXISTS `image_url` VARCHAR(500) NULL DEFAULT NULL
  AFTER `is_available`;

-- Verify columns were added
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('restaurants', 'menu_items')
  AND COLUMN_NAME = 'image_url';
