<?php
require __DIR__ . '/helpers/Database.php';
$db = getDB();

echo "--- DELIVERY BOYS ---\n";
$res = $db->query("SELECT db.id, db.user_id, u.name, db.status, db.current_lat, db.current_lng FROM delivery_boys db JOIN users u ON u.id=db.user_id");
while($row = $res->fetch_assoc()) {
    echo "ID: {$row['id']}, UID: {$row['user_id']}, Name: {$row['name']}, Status: {$row['status']}, Lat: {$row['current_lat']}, Lng: {$row['current_lng']}\n";
}

echo "\n--- ALL ORDERS ---\n";
$res = $db->query("SELECT o.id, o.restaurant_id, o.order_status, r.name as r_name, r.lat as r_lat, r.lng as r_lng 
                   FROM orders o 
                   LEFT JOIN restaurants r ON r.id=o.restaurant_id 
                   ORDER BY o.id DESC LIMIT 10");
while($row = $res->fetch_assoc()) {
    echo "OrderID: {$row['id']}, Status: {$row['order_status']}, Restaurant: {$row['r_name']} (ID: {$row['restaurant_id']}, Lat: {$row['r_lat']}, Lng: {$row['r_lng']})\n";
}

echo "\n--- TESTING listRequests Query for BoyID 2 ---\n";
$boyId = 2;
$lat = 20.61000000;
$lng = 72.92500000;

$sql = "
    SELECT dr.id, dr.order_id, dr.request_status, dr.created_at,
        o.total_amount, o.subtotal, o.delivery_charge AS delivery_fee,
        r.name AS restaurant_name, r.address AS restaurant_address,
        r.lat AS r_lat, r.lng AS r_lng,
        a.address_line1, a.city,
        u.name AS customer_name,
        (CASE WHEN ? = 0 OR ? = 0 OR r.lat IS NULL OR r.lng IS NULL THEN 9999
         ELSE (6371 * ACOS(
            LEAST(1, GREATEST(-1, 
                COS(RADIANS(?)) * COS(RADIANS(r.lat)) *
                COS(RADIANS(r.lng) - RADIANS(?)) +
                SIN(RADIANS(?)) * SIN(RADIANS(r.lat))
            ))
        )) END) AS distance_km
    FROM delivery_requests dr
    JOIN orders o ON o.id=dr.order_id
    JOIN restaurants r ON r.id=o.restaurant_id
    LEFT JOIN addresses a ON a.id=o.address_id
    JOIN users u ON u.id=o.user_id
    WHERE dr.delivery_boy_id=? AND dr.request_status='pending'
    ORDER BY distance_km ASC";

$stmt = $db->prepare($sql);
$stmt->bind_param('dddddi', $lat, $lng, $lat, $lng, $lat, $boyId);
$stmt->execute();
$items = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
echo "Found " . count($items) . " items.\n";
foreach($items as $it) {
    echo "ReqID: {$it['id']}, OrderID: {$it['order_id']}, Dist: {$it['distance_km']} km, Rest: {$it['restaurant_name']}\n";
}

echo "\n--- TESTING activeDelivery Query for BoyID 2 ---\n";
$boyId = 2;
$sqlActive = "
    SELECT o.id, o.order_status, o.delivery_otp AS otp, o.total_amount, o.payment_method,
        r.name AS restaurant_name, r.address AS restaurant_address, r.lat AS r_lat, r.lng AS r_lng,
        u.name AS customer_name, u.phone AS customer_phone,
        a.address_line1, a.city, a.lat AS cust_lat, a.lng AS cust_lng
    FROM orders o
    JOIN restaurants r ON r.id=o.restaurant_id
    JOIN users u ON u.id=o.user_id
    LEFT JOIN addresses a ON a.id=o.address_id
    WHERE o.delivery_boy_id=? AND o.order_status IN ('assigned','reached_restaurant','out_for_delivery')
    ORDER BY o.id DESC LIMIT 1";

$stmtA = $db->prepare($sqlActive);
$stmtA->bind_param('i', $boyId);
$stmtA->execute();
$active = $stmtA->get_result()->fetch_assoc();

if ($active) {
    echo "Found active order: #" . $active['id'] . " (Status: " . $active['order_status'] . ")\n";
} else {
    echo "No active order found.\n";
}
?>
