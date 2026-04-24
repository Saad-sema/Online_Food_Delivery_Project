<?php
define('BASEPATH', __DIR__);
require_once __DIR__ . '/helpers/Database.php';

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
if (!$db) die("DB connection failed\n");

$sqlFile = __DIR__ . '/migration_2026.sql';
if (!file_exists($sqlFile)) die("Migration file not found\n");

$commands = file_get_contents($sqlFile);
if ($db->multi_query($commands)) {
    do {
        if ($result = $db->store_result()) {
            $result->free();
        }
    } while ($db->more_results() && $db->next_result());
    echo "Migration successful!\n";
} else {
    echo "Migration failed: " . $db->error . "\n";
}
