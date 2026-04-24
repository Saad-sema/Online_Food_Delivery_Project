<?php
require_once 'backend/helpers/Database.php';

$db = getDB();

echo "=== MENU ITEMS IMAGE URLS ===\n";
$res = $db->query('SELECT id, name, image_url FROM menu_items WHERE image_url IS NOT NULL LIMIT 10');
while($row = $res->fetch_assoc()) {
    print_r($row);
}

echo "\n=== RESTAURANTS IMAGE URLS ===\n";
$res2 = $db->query('SELECT id, name, image_url FROM restaurants WHERE image_url IS NOT NULL LIMIT 10');
while($row = $res2->fetch_assoc()) {
    print_r($row);
}
?>
