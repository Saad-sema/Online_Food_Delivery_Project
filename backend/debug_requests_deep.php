<?php
// Standalone diagnostic
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

echo "--- CHECKING COORDINATES ---\n";
echo "Restaurant #1 Coords:\n";
$rest = $db->query("SELECT id, name, lat, lng FROM restaurants WHERE id=1")->fetch_assoc();
print_r($rest);

echo "\nAddress for Order #2 Coords:\n";
$addr = $db->query("SELECT a.id, a.lat, a.lng FROM addresses a JOIN orders o ON o.address_id=a.id WHERE o.id=2")->fetch_assoc();
print_r($addr);

echo "\n--- SIMULATING DeliveryController::listRequests for Boy #1 ---\n";
$boyId = 1;
$lat = 0; $lng = 0; // Default if not provided

$stmt = $db->prepare("
    SELECT dr.id, dr.order_id, dr.request_status, dr.created_at,
        o.order_status,
        r.name AS restaurant_name, r.lat AS r_lat, r.lng AS r_lng
    FROM delivery_requests dr
    JOIN orders o ON o.id=dr.order_id
    JOIN restaurants r ON r.id=o.restaurant_id
    WHERE dr.delivery_boy_id=? AND dr.request_status='pending'
");
$stmt->bind_param('i', $boyId);
$stmt->execute();
$results = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
echo "Query Results for Boy 1:\n";
print_r($results);

if (empty($results)) {
    echo "NO PENDING REQUESTS FOUND IN QUERY. Checking why...\n";
    $raw = $db->query("SELECT * FROM delivery_requests WHERE delivery_boy_id=$boyId")->fetch_all(MYSQLI_ASSOC);
    echo "Raw requests for boy 1:\n";
    print_r($raw);
    
    $order2 = $db->query("SELECT id, order_status, restaurant_id FROM orders WHERE id=2")->fetch_assoc();
    echo "Order #2 status:\n";
    print_r($order2);
}
