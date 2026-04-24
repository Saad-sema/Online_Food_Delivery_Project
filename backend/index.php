<?php
declare(strict_types=1);

// ── Bootstrap ────────────────────────────────────────────────
define('BASEPATH', __DIR__);

if (file_exists(__DIR__ . '/.env')) {
    foreach (file(__DIR__ . '/.env', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        if (strpos($line, '#') === 0) continue;
        [$k, $v] = array_pad(explode('=', $line, 2), 2, '');
        $_ENV[trim($k)] = trim($v);
    }
}

if (file_exists(__DIR__ . '/vendor/autoload.php')) {
    require __DIR__ . '/vendor/autoload.php';
}

require __DIR__ . '/helpers/Database.php';
require __DIR__ . '/helpers/Response.php';
require __DIR__ . '/helpers/JWT.php';
require __DIR__ . '/helpers/FCM.php';
require __DIR__ . '/controllers/AuthController.php';
require __DIR__ . '/controllers/CustomerController.php';
require __DIR__ . '/controllers/RestaurantController.php';
require __DIR__ . '/controllers/DeliveryController.php';
require __DIR__ . '/controllers/AdminController.php';
require __DIR__ . '/controllers/TrackingController.php';

// ── CORS Headers ─────────────────────────────────────────────
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// ── Routing ──────────────────────────────────────────────────
$method = $_SERVER['REQUEST_METHOD'];
$requestUri = $_SERVER['REQUEST_URI'] ?? '';
$uri = parse_url($requestUri, PHP_URL_PATH);
$uri = preg_replace('#/+#', '/', $uri);

file_put_contents(__DIR__ . '/debug.log', "[" . date('Y-m-d H:i:s') . "] $method $requestUri -> PATH: $uri\n", FILE_APPEND);

if (strpos($uri, 'index.php') !== false) {
    $parts = explode('index.php', $uri);
    $uri   = end($parts);
}
$uri = '/' . ltrim($uri, '/');
$uri = rtrim($uri, '/');

file_put_contents(__DIR__ . '/debug.log', "[" . date('Y-m-d H:i:s') . "] RESOLVED URI: $uri\n", FILE_APPEND);

function matchRoute(string $pattern, string $uri, array &$params = []): bool {
    $regex = preg_replace('#\{(\w+)\}#', '([^/]+)', $pattern);
    $regex = '#^' . $regex . '$#';
    if (preg_match($regex, $uri, $m)) {
        preg_match_all('#\{(\w+)\}#', $pattern, $names);
        foreach ($names[1] as $i => $name) {
            $params[$name] = $m[$i + 1];
        }
        return true;
    }
    return false;
}

$p = []; // route params

// ── Public Routes ─────────────────────────────────────────────
if      ($method === 'POST' && $uri === '/api/register')         { AuthController::register(); }
elseif  ($method === 'POST' && $uri === '/api/login')            { AuthController::login(); }
elseif  ($method === 'POST' && $uri === '/api/update-fcm-token') { AuthController::updateFcmToken(); }

// ── Tracking & Geocoding ──────────────────────────────────────
elseif ($method === 'POST' && $uri === '/api/location/update')   { TrackingController::updateLocation(); }
elseif ($method === 'GET'  && $uri === '/api/geocode/reverse')    { TrackingController::reverseGeocode(); }

// ── Customer Routes ───────────────────────────────────────────
elseif ($method === 'GET'  && $uri === '/api/customer/home')             { CustomerController::home(); }
elseif ($method === 'GET'  && $uri === '/api/restaurants')               { CustomerController::listRestaurants(); }
elseif ($method === 'GET'  && matchRoute('/api/restaurants/{id}', $uri, $p)) { CustomerController::getRestaurant((int)$p['id']); }
elseif ($method === 'GET'  && $uri === '/api/cart')                      { CustomerController::getCart(); }
elseif ($method === 'POST' && $uri === '/api/cart/add')                  { CustomerController::addToCart(); }
elseif ($method === 'POST' && $uri === '/api/cart/update')               { CustomerController::updateCart(); }
elseif ($method === 'POST' && $uri === '/api/cart/remove')               { CustomerController::removeFromCart(); }
elseif ($method === 'POST' && $uri === '/api/cart/apply-coupon')         { CustomerController::applyCoupon(); }
elseif ($method === 'POST' && $uri === '/api/orders/place')              { CustomerController::placeOrder(); }
elseif ($method === 'GET'  && $uri === '/api/orders')                    { CustomerController::listOrders(); }
elseif ($method === 'GET'  && matchRoute('/api/orders/{id}', $uri, $p))          { CustomerController::getOrder((int)$p['id']); }
elseif ($method === 'POST' && matchRoute('/api/orders/{id}/cancel', $uri, $p))   { CustomerController::cancelOrder((int)$p['id']); }
elseif ($method === 'GET'  && $uri === '/api/refunds')                    { CustomerController::listRefunds(); }
elseif ($method === 'GET'  && matchRoute('/api/orders/{id}/track', $uri, $p))    { CustomerController::trackOrder((int)$p['id']); }
elseif ($method === 'POST' && matchRoute('/api/orders/{id}/tip', $uri, $p))      { CustomerController::addTip((int)$p['id']); }
elseif ($method === 'POST' && $uri === '/api/reviews')                   { CustomerController::postReview(); }
elseif ($method === 'GET'  && $uri === '/api/addresses')                 { CustomerController::listAddresses(); }
elseif ($method === 'POST' && $uri === '/api/addresses')                 { CustomerController::addAddress(); }
elseif ($method === 'PUT'  && matchRoute('/api/addresses/{id}', $uri, $p))       { CustomerController::updateAddress((int)$p['id']); }
elseif ($method === 'DELETE' && matchRoute('/api/addresses/{id}', $uri, $p))     { CustomerController::deleteAddress((int)$p['id']); }
elseif ($method === 'GET'  && $uri === '/api/profile')                   { CustomerController::getProfile(); }
elseif ($method === 'PUT'  && $uri === '/api/profile')                   { CustomerController::updateProfile(); }

// Chat (shared across customer, restaurant, delivery boy)
elseif ($method === 'GET'  && matchRoute('/api/chat/{order_id}', $uri, $p))      { CustomerController::getMessages((int)$p['order_id']); }
elseif ($method === 'POST' && matchRoute('/api/chat/{order_id}', $uri, $p))      { CustomerController::sendMessage((int)$p['order_id']); }

// ── Restaurant Routes ─────────────────────────────────────────
elseif ($method === 'GET'  && $uri === '/api/restaurant/orders')                                  { RestaurantController::listOrders(); }
elseif ($method === 'GET'  && matchRoute('/api/restaurant/orders/{id}', $uri, $p))                { RestaurantController::getOrder((int)$p['id']); }
elseif ($method === 'POST' && matchRoute('/api/restaurant/orders/{id}/accept', $uri, $p))         { RestaurantController::acceptOrder((int)$p['id']); }
elseif ($method === 'POST' && matchRoute('/api/restaurant/orders/{id}/reject', $uri, $p))         { RestaurantController::rejectOrder((int)$p['id']); }
elseif ($method === 'POST' && matchRoute('/api/restaurant/orders/{id}/preparing', $uri, $p))      { RestaurantController::preparingOrder((int)$p['id']); }
elseif ($method === 'POST' && matchRoute('/api/restaurant/orders/{id}/ready', $uri, $p))          { RestaurantController::readyOrder((int)$p['id']); }
elseif ($method === 'POST' && $uri === '/api/restaurant/operator-status')                         { RestaurantController::updateOperatorStatus(); }
elseif ($method === 'GET'  && $uri === '/api/restaurant/menu')                                    { RestaurantController::getMenu(); }
elseif ($method === 'POST' && $uri === '/api/restaurant/menu/category')                           { RestaurantController::addCategory(); }
elseif ($method === 'PUT'  && matchRoute('/api/restaurant/menu/category/{id}', $uri, $p))         { RestaurantController::updateCategory((int)$p['id']); }
elseif ($method === 'DELETE' && matchRoute('/api/restaurant/menu/category/{id}', $uri, $p))       { RestaurantController::deleteCategory((int)$p['id']); }
elseif ($method === 'POST' && $uri === '/api/restaurant/menu/item')                               { RestaurantController::addItem(); }
elseif ($method === 'PUT'  && matchRoute('/api/restaurant/menu/item/{id}', $uri, $p))             { RestaurantController::updateItem((int)$p['id']); }
elseif ($method === 'DELETE' && matchRoute('/api/restaurant/menu/item/{id}', $uri, $p))           { RestaurantController::deleteItem((int)$p['id']); }
elseif ($method === 'POST' && matchRoute('/api/restaurant/menu/item/{id}/upload', $uri, $p))      { RestaurantController::uploadMenuItemImage((int)$p['id']); }
elseif ($method === 'GET'  && $uri === '/api/restaurant/earnings')                                { RestaurantController::earnings(); }
elseif ($method === 'GET'  && $uri === '/api/restaurant/profile')                                 { RestaurantController::getProfile(); }
elseif ($method === 'PUT'  && $uri === '/api/restaurant/profile')                                 { RestaurantController::updateProfile(); }
elseif ($method === 'POST' && $uri === '/api/restaurant/upload')                                  { RestaurantController::uploadRestaurantImage(); }

// ── Delivery Boy Routes ───────────────────────────────────────
elseif ($method === 'GET'  && $uri === '/api/delivery/requests')                                          { DeliveryController::listRequests(); }
elseif ($method === 'POST' && matchRoute('/api/delivery/requests/{id}/accept', $uri, $p))                 { DeliveryController::acceptRequest((int)$p['id']); }
elseif ($method === 'POST' && matchRoute('/api/delivery/requests/{id}/reject', $uri, $p))                 { DeliveryController::rejectRequest((int)$p['id']); }
elseif ($method === 'GET'  && $uri === '/api/delivery/active')                                            { DeliveryController::activeDelivery(); }
elseif ($method === 'POST' && matchRoute('/api/delivery/orders/{id}/reached-restaurant', $uri, $p))       { DeliveryController::reachedRestaurant((int)$p['id']); }
elseif ($method === 'POST' && matchRoute('/api/delivery/orders/{id}/start', $uri, $p))                    { DeliveryController::startDelivery((int)$p['id']); }
elseif ($method === 'POST' && matchRoute('/api/delivery/orders/{id}/verify-otp', $uri, $p))               { DeliveryController::verifyOtp((int)$p['id']); }
elseif ($method === 'POST' && $uri === '/api/delivery/location')                                          { DeliveryController::updateLocation(); }
elseif ($method === 'GET'  && $uri === '/api/delivery/history')                                           { DeliveryController::history(); }
elseif ($method === 'GET'  && $uri === '/api/delivery/earnings')                                          { DeliveryController::earnings(); }
elseif (($method === 'PUT' || $method === 'POST') && $uri === '/api/delivery/status')                     { DeliveryController::updateStatus(); }

// ── Admin Routes ──────────────────────────────────────────────
elseif ($method === 'GET'  && $uri === '/api/admin/dashboard')                           { AdminController::dashboard(); }
elseif ($method === 'GET'  && $uri === '/api/admin/users')                               { AdminController::listUsers(); }
elseif ($method === 'POST' && $uri === '/api/admin/users')                               { AdminController::createUser(); }
elseif ($method === 'PUT'  && matchRoute('/api/admin/users/{id}', $uri, $p))             { AdminController::updateUser((int)$p['id']); }
elseif ($method === 'DELETE' && matchRoute('/api/admin/users/{id}', $uri, $p))           { AdminController::deleteUser((int)$p['id']); }
elseif ($method === 'GET'  && $uri === '/api/admin/restaurants')                         { AdminController::listRestaurants(); }
elseif ($method === 'POST' && matchRoute('/api/admin/restaurants/approve/{id}', $uri, $p)) { AdminController::approveRestaurant((int)$p['id']); }
elseif ($method === 'GET'  && $uri === '/api/admin/orders')                              { AdminController::listOrders(); }
elseif ($method === 'GET'  && matchRoute('/api/admin/orders/{id}', $uri, $p))            { AdminController::getOrder((int)$p['id']); }
elseif ($method === 'PUT'  && matchRoute('/api/admin/orders/{id}/status', $uri, $p))     { AdminController::updateOrderStatus((int)$p['id']); }
elseif ($method === 'GET'  && $uri === '/api/admin/payments')                            { AdminController::payments(); }
elseif ($method === 'GET'  && $uri === '/api/admin/reports/orders')                      { AdminController::reportOrders(); }
elseif ($method === 'GET'  && $uri === '/api/admin/reports/earnings')                    { AdminController::reportEarnings(); }
elseif ($method === 'GET'  && $uri === '/api/admin/coupons')                             { AdminController::listCoupons(); }
elseif ($method === 'POST' && $uri === '/api/admin/coupons')                             { AdminController::createCoupon(); }
elseif ($method === 'PUT'  && matchRoute('/api/admin/coupons/{id}', $uri, $p))           { AdminController::updateCoupon((int)$p['id']); }
elseif ($method === 'DELETE' && matchRoute('/api/admin/coupons/{id}', $uri, $p))         { AdminController::deleteCoupon((int)$p['id']); }
elseif ($method === 'GET'  && $uri === '/api/admin/settings')                            { AdminController::getSettings(); }
elseif ($method === 'PUT'  && $uri === '/api/admin/settings')                            { AdminController::updateSettings(); }
elseif ($method === 'GET'  && $uri === '/api/admin/reviews')                             { AdminController::listReviews(); }
elseif ($method === 'DELETE' && matchRoute('/api/admin/reviews/{id}', $uri, $p))         { AdminController::deleteReview((int)$p['id']); }

// ── 404 ───────────────────────────────────────────────────────
else {
    respondNotFound('Endpoint not found');
}
