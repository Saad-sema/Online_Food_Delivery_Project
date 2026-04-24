<?php
require __DIR__ . '/helpers/Database.php';
$db = getDB();

echo "Running migration: Creating missing tables...\n";

// 1. delivery_tracking
$db->query("CREATE TABLE IF NOT EXISTS `delivery_tracking` (
  `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id` int(10) UNSIGNED NOT NULL,
  `delivery_boy_id` int(10) UNSIGNED NOT NULL,
  `lat` decimal(10,8) NOT NULL,
  `lng` decimal(11,8) NOT NULL,
  `recorded_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `delivery_tracking_order_id_foreign` (`order_id`),
  CONSTRAINT `delivery_tracking_order_id_foreign` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
echo "Table delivery_tracking checked/created.\n";

// 2. delivery_requests
$db->query("CREATE TABLE IF NOT EXISTS `delivery_requests` (
  `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id` int(10) UNSIGNED NOT NULL,
  `delivery_boy_id` int(10) UNSIGNED NOT NULL,
  `request_status` enum('pending','accepted','rejected','missed') NOT NULL DEFAULT 'pending',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  CONSTRAINT `dr_order_id_foreign` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE,
  CONSTRAINT `dr_boy_id_foreign` FOREIGN KEY (`delivery_boy_id`) REFERENCES `delivery_boys` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
echo "Table delivery_requests checked/created.\n";

echo "Migration complete.\n";
?>
