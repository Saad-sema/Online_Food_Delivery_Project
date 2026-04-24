<?php
require __DIR__ . '/helpers/Database.php';
$db = getDB();

echo "--- DELIVERY BOYS ---\n";
$res = $db->query("SELECT id, user_id, status FROM delivery_boys");
while($row = $res->fetch_assoc()) {
    echo "ID: {$row['id']}, UID: {$row['user_id']}, Status: {$row['status']}\n";
}

echo "\n--- PENDING DELIVERY REQUESTS ---\n";
$res = $db->query("SELECT id, order_id, delivery_boy_id, request_status FROM delivery_requests WHERE request_status='pending'");
while($row = $res->fetch_assoc()) {
    echo "ReqID: {$row['id']}, OrderID: {$row['order_id']}, BoyID: {$row['delivery_boy_id']}, Status: {$row['request_status']}\n";
}

echo "\n--- ACCEPTED ORDERS (NOT ASSIGNED TO BOY) ---\n";
$res = $db->query("SELECT id, restaurant_id, user_id, order_status FROM orders WHERE order_status='accepted' AND delivery_boy_id IS NULL");
while($row = $res->fetch_assoc()) {
    $rid = $row['restaurant_id'];
    $uid = $row['user_id'];
    $rCheck = $db->query("SELECT name FROM restaurants WHERE id=$rid")->fetch_assoc();
    $uCheck = $db->query("SELECT name FROM users WHERE id=$uid")->fetch_assoc();
    echo "OrderID: {$row['id']}, RestID: $rid (" . ($rCheck['name'] ?? 'MISSING') . "), CustID: $uid (" . ($uCheck['name'] ?? 'MISSING') . "), Status: {$row['order_status']}\n";
}
?>
