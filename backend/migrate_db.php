<?php
require __DIR__ . '/helpers/Database.php';

$db = getDB();

echo "Running migration: Adding vehicle columns to delivery_boys...\n";

// Add vehicle_number if missing
$check = $db->query("SHOW COLUMNS FROM delivery_boys LIKE 'vehicle_number'");
if ($check->num_rows === 0) {
    if ($db->query("ALTER TABLE delivery_boys ADD COLUMN vehicle_number VARCHAR(50) DEFAULT NULL AFTER rating_count")) {
        echo "Added vehicle_number column.\n";
    } else {
        echo "Error adding vehicle_number: " . $db->error . "\n";
    }
} else {
    echo "vehicle_number column already exists.\n";
}

// Add vehicle_type if missing
$check = $db->query("SHOW COLUMNS FROM delivery_boys LIKE 'vehicle_type'");
if ($check->num_rows === 0) {
    if ($db->query("ALTER TABLE delivery_boys ADD COLUMN vehicle_type VARCHAR(50) DEFAULT NULL AFTER vehicle_number")) {
        echo "Added vehicle_type column.\n";
    } else {
        echo "Error adding vehicle_type: " . $db->error . "\n";
    }
} else {
    echo "vehicle_type column already exists.\n";
}

echo "Migration complete.\n";
?>
