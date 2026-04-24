<?php
// Fix for redeclaration error: don't require index.php if we just need constants/db
define('BASEPATH', __DIR__);
require_once __DIR__ . '/helpers/Database.php';

// Mock .env loading logic since we can't easily use the one in index.php without side effects
if (file_exists(__DIR__ . '/.env')) {
    foreach (file(__DIR__ . '/.env', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        if (strpos($line, '#') === 0) continue;
        [$k, $v] = array_pad(explode('=', $line, 2), 2, '');
        $k = trim($k); $v = trim($v);
        if ($k) {
            putenv("$k=$v");
            $_ENV[$k] = $v;
        }
    }
}

$db = getDB();
if (!$db) {
    die("DB connection failed\n");
}

$res = $db->query("SELECT r.id, r.name, r.status, r.user_id, u.id as owner_id FROM restaurants r LEFT JOIN users u ON u.id = r.user_id");
if (!$res) {
    die("Query failed: " . $db->error);
}

echo "RESTAURANTS IN DB:\n";
while ($row = $res->fetch_assoc()) {
    $ownerStatus = $row['owner_id'] ? "OK" : "ORPHANED (No user with ID " . $row['user_id'] . ")";
    echo "ID: " . $row['id'] . " | Name: " . $row['name'] . " | Status: " . $row['status'] . " | UserID: " . $row['user_id'] . " | Owner: " . $ownerStatus . "\n";
}

$res = $db->query("SELECT id, name, email, role FROM users WHERE role='restaurant'");
echo "\nRESTAURANT OWNERS (Users with role='restaurant'):\n";
while ($row = $res->fetch_assoc()) {
    echo "ID: " . $row['id'] . " | Name: " . $row['name'] . " | Email: " . $row['email'] . "\n";
}
