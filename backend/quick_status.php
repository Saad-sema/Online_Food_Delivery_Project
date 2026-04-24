<?php
require __DIR__ . '/helpers/Database.php';
$db = getDB();

echo "--- DELIVERY BOY STATUS ---\n";
$res = $db->query("SELECT db.id, u.name, db.status FROM delivery_boys db JOIN users u ON u.id=db.user_id");
while($row = $res->fetch_assoc()) {
    echo "ID: {$row['id']}, Name: {$row['name']}, Status: {$row['status']}\n";
}

echo "\n--- PENDING DELIVERY REQUESTS (raw) ---\n";
$res = $db->query("SELECT dr.id, dr.order_id, dr.delivery_boy_id, dr.request_status FROM delivery_requests WHERE request_status='pending'");
while($row = $res->fetch_assoc()) {
    echo "ReqID: {$row['id']}, OrderID: {$row['order_id']}, BoyID: {$row['delivery_boy_id']}, Status: {$row['request_status']}\n";
}
?>
