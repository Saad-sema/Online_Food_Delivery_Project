<?php
require __DIR__ . '/helpers/Database.php';
$db = getDB();

echo "Running migration: Standardizing orders table schema...\n";

// Rename otp to delivery_otp
$check = $db->query("SHOW COLUMNS FROM orders LIKE 'delivery_otp'");
if ($check->num_rows === 0) {
    if ($db->query("ALTER TABLE orders CHANGE COLUMN otp delivery_otp VARCHAR(6) DEFAULT NULL")) {
        echo "Renamed otp to delivery_otp.\n";
    } else {
        echo "Error renaming otp: " . $db->error . "\n";
    }
} else {
    echo "delivery_otp column already exists.\n";
}

// Rename tax to tax_amount and ensure it's DECIMAL(10,2)
$check = $db->query("SHOW COLUMNS FROM orders LIKE 'tax_amount'");
if ($check->num_rows === 0) {
    if ($db->query("ALTER TABLE orders CHANGE COLUMN tax tax_amount DECIMAL(10,2) DEFAULT '0.00'")) {
        echo "Renamed tax to tax_amount.\n";
    } else {
        echo "Error renaming tax: " . $db->error . "\n";
    }
} else {
    echo "tax_amount column already exists.\n";
}

// Fix subtotal, delivery_charge, coupon_discount to DECIMAL(10,2) if they are DECIMAL(8,2)
$db->query("ALTER TABLE orders MODIFY COLUMN subtotal DECIMAL(10,2) NOT NULL");
$db->query("ALTER TABLE orders MODIFY COLUMN delivery_charge DECIMAL(10,2) NOT NULL DEFAULT '0.00'");
$db->query("ALTER TABLE orders MODIFY COLUMN total_amount DECIMAL(10,2) NOT NULL");
$db->query("ALTER TABLE orders MODIFY COLUMN coupon_discount DECIMAL(10,2) NOT NULL DEFAULT '0.00'");
echo "Adjusted decimal precisions for order amounts.\n";

echo "Migration complete.\n";
?>
