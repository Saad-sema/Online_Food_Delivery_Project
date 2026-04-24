<?php
require __DIR__ . '/helpers/Database.php';
$db = getDB();
echo "--- COLUMNS in 'orders' table ---\n";
$res = $db->query("DESCRIBE orders");
while($row = $res->fetch_assoc()) {
    echo "Field: {$row['Field']}, Type: {$row['Type']}\n";
}
?>
