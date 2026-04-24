-- ============================================================
-- ONLINE FOOD DELIVERY - FINAL RELEASE DATABASE SCHEMA
-- ============================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

-- 1. Create Database
CREATE DATABASE IF NOT EXISTS `food_delivery` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `food_delivery`;

-- 2. Drop existing tables for fresh start (Optional, but included for complete Point 8 delivery)
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS `delivery_tracking`, `chat_messages`, `delivery_requests`, `delivery_boys`, `order_items`, `orders`, `menu_items`, `categories`, `restaurants`, `addresses`, `users`, `coupons`, `settings`, `reviews`;
SET FOREIGN_KEY_CHECKS = 1;

-- 3. Users Table
CREATE TABLE `users` (
  `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `phone` varchar(20) NOT NULL,
  `password` varchar(255) NOT NULL,
  `role` enum('customer','restaurant','delivery_boy','admin') NOT NULL DEFAULT 'customer',
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `fcm_token` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `users_email_unique` (`email`),
  UNIQUE KEY `users_phone_unique` (`phone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. Restaurants Table
CREATE TABLE `restaurants` (
  `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int(10) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `address` text DEFAULT NULL,
  `lat` decimal(10,8) DEFAULT NULL,
  `lng` decimal(11,8) DEFAULT NULL,
  `rating_avg` decimal(3,2) NOT NULL DEFAULT 0.00,
  `rating_count` int(11) NOT NULL DEFAULT 0,
  `image_url` text DEFAULT NULL,
  `is_open` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `restaurants_user_id_foreign` (`user_id`),
  CONSTRAINT `restaurants_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. Delivery Boys Table
CREATE TABLE `delivery_boys` (
  `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int(10) UNSIGNED NOT NULL,
  `status` enum('available','busy','offline') NOT NULL DEFAULT 'available',
  `current_lat` decimal(10,8) DEFAULT NULL,
  `current_lng` decimal(11,8) DEFAULT NULL,
  `total_earnings` decimal(10,2) NOT NULL DEFAULT 0.00,
  `rating_avg` decimal(3,2) NOT NULL DEFAULT 0.00,
  `rating_count` int(11) NOT NULL DEFAULT 0,
  `vehicle_number` varchar(50) DEFAULT NULL,
  `last_seen_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `delivery_boys_user_id_foreign` (`user_id`),
  CONSTRAINT `delivery_boys_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 6. Addresses Table
CREATE TABLE `addresses` (
  `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int(10) UNSIGNED NOT NULL,
  `address_line1` varchar(255) NOT NULL,
  `address_line2` varchar(255) DEFAULT NULL,
  `city` varchar(100) NOT NULL,
  `lat` decimal(10,8) DEFAULT NULL,
  `lng` decimal(11,8) DEFAULT NULL,
  `is_default` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `addresses_user_id_foreign` (`user_id`),
  CONSTRAINT `addresses_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 8. Orders Table (Enhanced for Tracking)
CREATE TABLE `orders` (
  `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int(10) UNSIGNED NOT NULL,
  `restaurant_id` int(10) UNSIGNED NOT NULL,
  `delivery_boy_id` int(10) UNSIGNED DEFAULT NULL,
  `address_id` int(10) UNSIGNED DEFAULT NULL,
  `order_status` enum('pending','accepted','assigned','reached_restaurant','out_for_delivery','delivered','cancelled','rejected') NOT NULL DEFAULT 'pending',
  `payment_method` enum('cod','upi') NOT NULL DEFAULT 'cod',
  `payment_status` enum('pending','successful','failed','refunded') NOT NULL DEFAULT 'pending',
  `subtotal` decimal(10,2) NOT NULL,
  `tax_amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `delivery_charge` decimal(10,2) NOT NULL DEFAULT 0.00,
  `total_amount` decimal(10,2) NOT NULL,
  `tip_amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `delivery_otp` varchar(6) DEFAULT NULL,
  `coupon_code` varchar(50) DEFAULT NULL,
  `coupon_discount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `special_notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `reached_restaurant_at` datetime DEFAULT NULL,
  `picked_up_at` datetime DEFAULT NULL,
  `delivered_at` datetime DEFAULT NULL,
  `cancelled_at` datetime DEFAULT NULL,
  `cancellation_reason` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `orders_user_id_foreign` (`user_id`),
  KEY `orders_restaurant_id_foreign` (`restaurant_id`),
  KEY `orders_delivery_boy_id_foreign` (`delivery_boy_id`),
  CONSTRAINT `orders_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `orders_restaurant_id_foreign` FOREIGN KEY (`restaurant_id`) REFERENCES `restaurants` (`id`),
  CONSTRAINT `orders_delivery_boy_id_foreign` FOREIGN KEY (`delivery_boy_id`) REFERENCES `delivery_boys` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 9. Chat Messages Table
CREATE TABLE `chat_messages` (
  `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id` int(10) UNSIGNED NOT NULL,
  `sender_id` int(10) UNSIGNED NOT NULL,
  `sender_role` enum('customer','delivery_boy') NOT NULL,
  `message` text NOT NULL,
  `is_read` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `chat_messages_order_id_foreign` (`order_id`),
  CONSTRAINT `chat_messages_order_id_foreign` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 10. Delivery Tracking Table
CREATE TABLE `delivery_tracking` (
  `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id` int(10) UNSIGNED NOT NULL,
  `delivery_boy_id` int(10) UNSIGNED NOT NULL,
  `lat` decimal(10,8) NOT NULL,
  `lng` decimal(11,8) NOT NULL,
  `recorded_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `delivery_tracking_order_id_foreign` (`order_id`),
  CONSTRAINT `delivery_tracking_order_id_foreign` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 11. Delivery Requests
CREATE TABLE `delivery_requests` (
  `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id` int(10) UNSIGNED NOT NULL,
  `delivery_boy_id` int(10) UNSIGNED NOT NULL,
  `request_status` enum('pending','accepted','rejected','missed') NOT NULL DEFAULT 'pending',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  CONSTRAINT `dr_order_id_foreign` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE,
  CONSTRAINT `dr_boy_id_foreign` FOREIGN KEY (`delivery_boy_id`) REFERENCES `delivery_boys` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- DUMMY DATA FOR VERIFICATION
-- ============================================================

-- Customers
INSERT INTO `users` (id, name, email, phone, password, role) VALUES 
(1, 'John Customer', 'customer@example.com', '9876543210', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'customer');

-- Restaurants
INSERT INTO `users` (id, name, email, phone, password, role) VALUES 
(2, 'Pizza Palace', 'pizza@example.com', '9876543211', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'restaurant');
INSERT INTO `restaurants` (id, user_id, name, address, lat, lng, is_open) VALUES 
(1, 2, 'Pizza Palace Indiranagar', '12th Main, Indiranagar, Bengaluru', 12.9784, 77.6408, 1);

-- Delivery Boys
INSERT INTO `users` (id, name, email, phone, password, role) VALUES 
(301, 'Ravi Delivery', 'delivery@example.com', '9876543301', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'delivery_boy');
INSERT INTO `delivery_boys` (id, user_id, status, current_lat, current_lng, vehicle_number) VALUES 
(1, 301, 'available', 12.9716, 77.5946, 'KA-01-EF-1234');

-- Sample Address
INSERT INTO `addresses` (id, user_id, address_line1, city, lat, lng, is_default) VALUES 
(1, 1, 'HSR Layout 7th Sector', 'Bengaluru', 12.9103, 77.6450, 1);

-- Active Order for Testing Tracking
INSERT INTO `orders` (id, user_id, restaurant_id, delivery_boy_id, address_id, order_status, subtotal, delivery_charge, total_amount, delivery_otp) VALUES 
(500, 1, 1, 1, 1, 'out_for_delivery', 500.00, 40.00, 565.00, '123456');

SELECT 'Database Finalized with Enhanced Tracking and Dummy Data' AS message;

