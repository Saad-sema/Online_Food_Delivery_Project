<?php
require __DIR__ . '/helpers/Database.php';
$db = getDB();

echo "Running backfill: Creating delivery requests for orphan accepted orders...\n";

// Find orders that are accepted but have no requests
$res = $db->query("SELECT id FROM orders WHERE order_status='accepted' AND id NOT IN (SELECT order_id FROM delivery_requests)");
$orphanOrders = [];
while($row = $res->fetch_assoc()) {
    $orphanOrders[] = (int)$row['id'];
}

if (empty($orphanOrders)) {
    echo "No orphan accepted orders found.\n";
} else {
    echo "Found " . count($orphanOrders) . " orphan orders: " . implode(', ', $orphanOrders) . "\n";
    
    // Find available delivery boys
    $resBoys = $db->query("SELECT id FROM delivery_boys WHERE status='available'");
    $boys = [];
    while($row = $resBoys->fetch_assoc()) {
        $boys[] = (int)$row['id'];
    }
    
    if (empty($boys)) {
        echo "No available delivery boys found to assign requests to.\n";
    } else {
        foreach ($orphanOrders as $oid) {
            foreach ($boys as $bid) {
                $db->query("INSERT IGNORE INTO delivery_requests (order_id, delivery_boy_id, request_status) VALUES ($oid, $bid, 'pending')");
            }
            echo "Backfilled requests for Order #$oid\n";
        }
    }
}

echo "Backfill complete.\n";
?>
