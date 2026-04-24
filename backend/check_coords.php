<?php
require_once 'helpers/functions.php'; // Assuming this provides getDB()

$db = getDB();

echo "--- RESTAURANTS ---\n";
$res = $db->query("SELECT id, name, lat, lng FROM restaurants");
while($row = $res->fetch_assoc()) {
    echo "ID: {$row['id']} | Name: {$row['name']} | Lat: {$row['lat']} | Lng: {$row['lng']}\n";
}

echo "\n--- DELIVERY BOYS ---\n";
$res = $db->query("SELECT id, current_lat, current_lng FROM delivery_boys");
while($row = $res->fetch_assoc()) {
    echo "ID: {$row['id']} | Lat: {$row['current_lat']} | Lng: {$row['current_lng']}\n";
}

echo "\n--- ADDRESSES ---\n";
$res = $db->query("SELECT id, lat, lng, address_line1 FROM addresses");
while($row = $res->fetch_assoc()) {
    echo "ID: {$row['id']} | Lat: {$row['lat']} | Lng: {$row['lng']} | Addr: {$row['address_line1']}\n";
}
?>
