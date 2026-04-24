<?php
declare(strict_types=1);
/**
 * Database Connection Helper
 * Returns a global MySQLi connection (singleton pattern).
 */

function getDB(): mysqli {
    static $db = null;
    if ($db !== null) return $db;

    $host = $_ENV['DB_HOST'] ?? 'localhost';
    $port = (int)($_ENV['DB_PORT'] ?? 3307);
    $name = $_ENV['DB_NAME'] ?? 'food_delivery';
    $user = $_ENV['DB_USER'] ?? 'root';
    $pass = $_ENV['DB_PASS'] ?? '';

    $db = new mysqli($host, $user, $pass, $name, $port);

    if ($db->connect_errno) {
        http_response_code(503);
        die(json_encode(['success' => false, 'message' => 'Database connection failed']));
    }

    $db->set_charset('utf8mb4');
    return $db;
}
