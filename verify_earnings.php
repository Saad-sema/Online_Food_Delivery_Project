<?php
require_once __DIR__ . '/backend/helpers/Database.php';
require_once __DIR__ . '/backend/helpers/Response.php';
require_once __DIR__ . '/backend/controllers/RestaurantController.php';

// Mock getAuthUser
function getAuthUser() {
    return (object)['user_id' => 201, 'role' => 'restaurant'];
}

// Mock respondSuccess to just print data
function respondSuccess($data, $message = '', $code = 200) {
    echo json_encode($data, JSON_PRETTY_PRINT);
    exit;
}

// Set up $_GET
$_GET['period'] = 'week';

// Call the method
try {
    RestaurantController::earnings();
} catch (Exception $e) {
    echo "Error: " . $e->getMessage();
}
