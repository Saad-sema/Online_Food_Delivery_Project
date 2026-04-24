<?php
session_start();
define('DB_HOST', 'localhost');
define('DB_PORT', 3307);
define('DB_NAME', 'food_delivery');
define('DB_USER', 'root');
define('DB_PASS', '');
define('API_URL', 'http://localhost:8000/api');

function db(): mysqli {
    static $c = null;
    if ($c) return $c;
    $c = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME, DB_PORT);
    if ($c->connect_errno) die('DB error: ' . $c->connect_error);
    $c->set_charset('utf8mb4');
    return $c;
}

function requireLogin(): void {
    if (empty($_SESSION['admin_id'])) {
        header('Location: login.php');
        exit;
    }
}

function flash(string $msg, string $type = 'success'): void {
    $_SESSION['flash'] = ['msg' => $msg, 'type' => $type];
}

function getFlash(): ?array {
    $f = $_SESSION['flash'] ?? null;
    unset($_SESSION['flash']);
    return $f;
}
