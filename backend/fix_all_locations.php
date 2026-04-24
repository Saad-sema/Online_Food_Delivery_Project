<?php
// Fix locations to Valsad, Gujarat area
$env = parse_ini_file('.env');
$host = $env['DB_HOST'] ?? 'localhost';
$port = $env['DB_PORT'] ?? '3306';
$dbname = $env['DB_NAME'] ?? 'food_delivery';
$user = $env['DB_USER'] ?? 'root';
$pass = $env['DB_PASS'] ?? '';

$mysqli = new mysqli($host, $user, $pass, $dbname, (int)$port);

// 1. Update Spice Garden (Restaurant 1) to Valsad
$mysqli->query("UPDATE restaurants SET lat=20.5992, lng=72.9342 WHERE id=1");

// 2. Update Pizza Paradise (Restaurant 2) to Valsad
$mysqli->query("UPDATE restaurants SET lat=20.6050, lng=72.9400 WHERE id=2");

// 3. Update MotaTaiwad Address (Address 2) to Valsad (it was 0,0)
$mysqli->query("UPDATE addresses SET lat=20.6012, lng=72.9264 WHERE id=2");

// 4. Update the Indiranagar Address just in case they test with it
$mysqli->query("UPDATE addresses SET lat=20.5950, lng=72.9300 WHERE id=1");

echo "✅ Locations updated to Valsad for testing!\n";
echo "Spice Garden: 20.5992, 72.9342\n";
echo "MotaTaiwad: 20.6012, 72.9264\n";
?>
