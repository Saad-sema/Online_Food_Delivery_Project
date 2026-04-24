<?php
require __DIR__ . '/helpers/Database.php';
$db = getDB();
echo "--- TABLES ---\n";
$res = $db->query("SHOW TABLES");
while($row = $res->fetch_array()) {
    echo $row[0] . "\n";
}
?>
