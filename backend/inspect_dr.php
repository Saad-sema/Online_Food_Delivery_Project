<?php
require __DIR__ . '/helpers/Database.php';
$db = getDB();

echo "--- COLUMNS in delivery_requests ---\n";
$res = $db->query("DESCRIBE delivery_requests");
while($row = $res->fetch_assoc()) {
    echo "Field: {$row['Field']}, Type: {$row['Type']}, Key: {$row['Key']}\n";
}

echo "\n--- ALL ROWS in delivery_requests ---\n";
$res = $db->query("SELECT * FROM delivery_requests LIMIT 10");
while($row = $res->fetch_assoc()) {
    echo json_encode($row) . "\n";
}
?>
