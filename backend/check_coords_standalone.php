<?php
// Standalone check
$env = parse_ini_file('.env');
$host = $env['DB_HOST'] ?? 'localhost';
$port = $env['DB_PORT'] ?? '3306';
$dbname = $env['DB_NAME'] ?? 'food_delivery';
$user = $env['DB_USER'] ?? 'root';
$pass = $env['DB_PASS'] ?? '';

$mysqli = new mysqli($host, $user, $pass, $dbname, (int)$port);
if ($mysqli->connect_error) {
    die("Connection failed: " . $mysqli->connect_error);
}

echo "--- RESTAURANTS ---\n";
$res = $mysqli->query("SELECT id, name, lat, lng FROM restaurants");
while($row = $res->fetch_assoc()) {
    echo "ID: {$row['id']} | Name: {$row['name']} | Lat: {$row['lat']} | Lng: {$row['lng']}\n";
}

echo "\n--- DELIVERY BOYS ---\n";
$res = $mysqli->query("SELECT id, current_lat, current_lng FROM delivery_boys");
while($row = $res->fetch_assoc()) {
    echo "ID: {$row['id']} | Lat: {$row['current_lat']} | Lng: {$row['current_lng']}\n";
}

echo "\n--- ADDRESSES ---\n";
$res = $mysqli->query("SELECT id, lat, lng, address_line1 FROM addresses");
while($row = $res->fetch_assoc()) {
    echo "ID: {$row['id']} | Lat: {$row['lat']} | Lng: {$row['lng']} | Addr: {$row['address_line1']}\n";
}
?>
