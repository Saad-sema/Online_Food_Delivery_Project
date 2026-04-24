<?php
// Full Restoration and Request Re-Broadcast
if (file_exists(__DIR__ . '/.env')) {
    foreach (file(__DIR__ . '/.env', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        if (strpos($line, '#') === 0) continue;
        [$k, $v] = array_pad(explode('=', $line, 2), 2, '');
        $_ENV[trim($k)] = trim($v);
    }
}

function getDB() {
    $host = $_ENV['DB_HOST'] ?? 'localhost';
    $port = (int)($_ENV['DB_PORT'] ?? 3307);
    $name = $_ENV['DB_NAME'] ?? 'food_delivery';
    $user = $_ENV['DB_USER'] ?? 'root';
    $pass = $_ENV['DB_PASS'] ?? '';
    return new mysqli($host, $user, $pass, $name, $port);
}

$db = getDB();

echo "1. Repairing Orders Table...\n";
$db->query("ALTER TABLE orders MODIFY COLUMN order_status ENUM('pending','accepted','rejected','assigned','reached_restaurant','out_for_delivery','delivered','cancelled') NOT NULL DEFAULT 'pending'");
$db->query("UPDATE orders SET delivery_boy_id = NULL WHERE order_status = 'accepted'");

echo "2. Repairing Delivery Boys Table...\n";
$db->query("UPDATE delivery_boys SET status = 'available' WHERE status != 'available'");
// Set default coordinates if empty to avoid any distance math issues
$db->query("UPDATE delivery_boys SET current_lat = 20.62147, current_lng = 72.92465 WHERE current_lat IS NULL OR current_lat = 0");

echo "3. Re-creating Delivery Requests Tables (just in case)...\n";
$db->query("CREATE TABLE IF NOT EXISTS delivery_requests (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id INT UNSIGNED NOT NULL,
    delivery_boy_id INT UNSIGNED NOT NULL,
    request_status ENUM('pending','accepted','rejected','expired','cancelled') NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB");

$db->query("CREATE TABLE IF NOT EXISTS delivery_tracking (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id INT UNSIGNED NOT NULL,
    delivery_boy_id INT UNSIGNED NOT NULL,
    lat DECIMAL(10,8) NOT NULL,
    lng DECIMAL(11,8) NOT NULL,
    recorded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB");

echo "4. Clearing and Re-broadcasting all 'accepted' orders...\n";
$db->query("TRUNCATE TABLE delivery_requests");

$acceptedOrders = $db->query("SELECT id FROM orders WHERE order_status = 'accepted'");
$boys = $db->query("SELECT id FROM delivery_boys WHERE status = 'available'");

$boyIds = [];
while($b = $boys->fetch_assoc()) $boyIds[] = $b['id'];

$count = 0;
while($o = $acceptedOrders->fetch_assoc()) {
    foreach($boyIds as $bid) {
        $db->query("INSERT INTO delivery_requests (order_id, delivery_boy_id, request_status) VALUES ({$o['id']}, $bid, 'pending')");
        $count++;
    }
}

echo "Broadcasted $count requests to " . count($boyIds) . " delivery boys.\n";

echo "DONE. Please check the app now.\n";
