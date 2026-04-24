<?php
declare(strict_types=1);

class RestaurantController {

    private static function requireRestaurant(): array {
        $auth = getAuthUser();
        if (!$auth || $auth->role !== 'restaurant') respondForbidden('Restaurant access only');
        $db   = getDB();
        $uid  = $auth->user_id;
        $stmt = $db->prepare("SELECT id FROM restaurants WHERE user_id=?");
        $stmt->bind_param('i', $uid);
        $stmt->execute();
        $rest = $stmt->get_result()->fetch_assoc();
        if (!$rest) respondError('Restaurant profile not found', 404);
        return ['user_id' => $uid, 'restaurant_id' => (int)$rest['id'], 'db' => $db];
    }

    private static function getSetting(\mysqli $db, string $key, string $default = ''): string {
        $stmt = $db->prepare("SELECT value FROM settings WHERE setting_key=?");
        $stmt->bind_param('s', $key);
        $stmt->execute();
        $r = $stmt->get_result()->fetch_assoc();
        return $r ? $r['value'] : $default;
    }

    // GET /api/restaurant/orders
    public static function listOrders(): void {
        $ctx  = self::requireRestaurant();
        $db   = $ctx['db'];
        $rid  = $ctx['restaurant_id'];
        $status = $_GET['status'] ?? null;
        $where = $status ? "AND o.order_status='$status'" : '';

        $stmt = $db->prepare("SELECT o.id, o.order_status, o.payment_method, o.payment_status,
            o.total_amount, o.created_at, u.name AS customer_name, u.phone AS customer_phone
            FROM orders o JOIN users u ON u.id=o.user_id
            WHERE o.restaurant_id=? $where ORDER BY o.created_at DESC LIMIT 50");
        $stmt->bind_param('i', $rid);
        $stmt->execute();
        respondSuccess($stmt->get_result()->fetch_all(MYSQLI_ASSOC));
    }

    // GET /api/restaurant/orders/{id}
    public static function getOrder(int $id): void {
        $ctx = self::requireRestaurant();
        $db  = $ctx['db'];
        $rid = $ctx['restaurant_id'];

        $stmt = $db->prepare("SELECT o.*, u.name AS customer_name, u.phone AS customer_phone,
            a.address_line1, a.city, a.flat_no, a.landmark
            FROM orders o JOIN users u ON u.id=o.user_id LEFT JOIN addresses a ON a.id=o.address_id
            WHERE o.id=? AND o.restaurant_id=?");
        $stmt->bind_param('ii', $id, $rid);
        $stmt->execute();
        $order = $stmt->get_result()->fetch_assoc();
        if (!$order) respondNotFound('Order not found');

        $stmt2 = $db->prepare("SELECT * FROM order_items WHERE order_id=?");
        $stmt2->bind_param('i', $id);
        $stmt2->execute();
        $order['items'] = $stmt2->get_result()->fetch_all(MYSQLI_ASSOC);
        respondSuccess($order);
    }

    // POST /api/restaurant/orders/{id}/accept
    // Enhanced: broadcast only to delivery boys within radius, sets 30s timer
    public static function acceptOrder(int $id): void {
        $ctx = self::requireRestaurant();
        $db  = $ctx['db'];
        $rid = $ctx['restaurant_id'];

        $stmt = $db->prepare("SELECT order_status, user_id FROM orders WHERE id=? AND restaurant_id=?");
        $stmt->bind_param('ii', $id, $rid);
        $stmt->execute();
        $order = $stmt->get_result()->fetch_assoc();
        if (!$order) respondNotFound('Order not found');
        if ($order['order_status'] !== 'pending') respondError('Order cannot be accepted');

        $now = date('Y-m-d H:i:s');
        $accepted = 'accepted';
        $stmt2 = $db->prepare("UPDATE orders SET order_status=?, accepted_at=NOW(), broadcast_started_at=NOW(), broadcast_attempts=1 WHERE id=?");
        $stmt2->bind_param('si', $accepted, $id);
        $stmt2->execute();

        // Broadcast to delivery boys within 20km radius
        $stmt_r = $db->prepare("SELECT lat, lng FROM restaurants WHERE id=?");
        $stmt_r->bind_param('i', $rid);
        $stmt_r->execute();
        $r_data = $stmt_r->get_result()->fetch_assoc();
        $rLat = (float)($r_data['lat'] ?? 0);
        $rLng = (float)($r_data['lng'] ?? 0);
        
        self::broadcastToNearbyBoys($db, $id, $rLat, $rLng, 20.0, 'NULL');

        // Notify customer
        $custFcm = $db->query("SELECT fcm_token FROM users WHERE id=" . (int)$order['user_id'])->fetch_assoc();
        if ($custFcm && $custFcm['fcm_token']) {
            sendFCM($custFcm['fcm_token'], 'Order Accepted! 🍽️',
                "Your order #$id has been accepted and is being prepared.",
                ['order_id' => (string)$id, 'type' => 'order_accepted']);
        }

        respondSuccess(null, 'Order accepted and broadcasted to nearby delivery boys');
    }

    // POST /api/restaurant/orders/{id}/preparing
    public static function preparingOrder(int $id): void {
        $ctx = self::requireRestaurant();
        $db  = $ctx['db'];
        $rid = $ctx['restaurant_id'];
        $now = date('Y-m-d H:i:s');

        $stmt = $db->prepare("UPDATE orders SET order_status='preparing', preparing_at=NOW() WHERE id=? AND restaurant_id=? AND order_status='accepted'");
        $stmt->bind_param('ii', $id, $rid);
        $stmt->execute();
        if (!$stmt->affected_rows) respondError('Order not in accepted state');

        $custFcm = $db->query("SELECT u.fcm_token FROM orders o JOIN users u ON u.id=o.user_id WHERE o.id=$id")->fetch_assoc();
        if ($custFcm && $custFcm['fcm_token']) {
            sendFCM($custFcm['fcm_token'], 'Food is Being Prepared 👨‍🍳',
                "The restaurant has started preparing your order #$id",
                ['order_id' => (string)$id, 'type' => 'preparing']);
        }
        respondSuccess(null, 'Order marked as preparing');
    }

    // POST /api/restaurant/orders/{id}/reject
    public static function rejectOrder(int $id): void {
        $ctx  = self::requireRestaurant();
        $db   = $ctx['db'];
        $rid  = $ctx['restaurant_id'];

        $stmt = $db->prepare("SELECT order_status, payment_status, payment_method, user_id FROM orders WHERE id=? AND restaurant_id=?");
        $stmt->bind_param('ii', $id, $rid);
        $stmt->execute();
        $order = $stmt->get_result()->fetch_assoc();
        if (!$order) respondNotFound('Order not found');
        if (!in_array($order['order_status'], ['pending'])) respondError('Order cannot be rejected');

        // If paid online, mark for refund
        $paymentUpdate = '';
        if ($order['payment_method'] === 'upi' && $order['payment_status'] === 'successful') {
            $paymentUpdate = ", payment_status='refunded'";
        }

        $status = 'rejected';
        $db->query("UPDATE orders SET order_status='rejected'$paymentUpdate WHERE id=$id");

        $custFcm = $db->query("SELECT fcm_token FROM users WHERE id=" . (int)$order['user_id'])->fetch_assoc();
        if ($custFcm && $custFcm['fcm_token']) {
            $msg = $paymentUpdate
                ? "Your order #$id was rejected. A refund has been initiated."
                : "Sorry, your order #$id was rejected by the restaurant.";
            sendFCM($custFcm['fcm_token'], 'Order Rejected', $msg,
                ['order_id' => (string)$id, 'type' => 'order_rejected']);
        }
        respondSuccess(null, 'Order rejected');
    }

    // POST /api/restaurant/orders/{id}/ready
    public static function readyOrder(int $id): void {
        $ctx = self::requireRestaurant();
        $db  = $ctx['db'];
        $rid = $ctx['restaurant_id'];
        $now = date('Y-m-d H:i:s');

        $stmt = $db->prepare("UPDATE orders SET order_status='ready_for_pickup', ready_at=NOW() WHERE id=? AND restaurant_id=? AND order_status IN ('accepted','preparing')");
        $stmt->bind_param('ii', $id, $rid);
        $stmt->execute();
        if (!$stmt->affected_rows) respondError('Order not in correct state for ready');

        // Notify delivery boy if assigned
        $delivery = $db->query("SELECT u.fcm_token FROM orders o JOIN delivery_boys db ON db.id=o.delivery_boy_id JOIN users u ON u.id=db.user_id WHERE o.id=$id AND o.delivery_boy_id IS NOT NULL")->fetch_assoc();
        if ($delivery && $delivery['fcm_token']) {
            sendFCM($delivery['fcm_token'], 'Order Ready for Pickup! 📦',
                "Order #$id is packed and ready. Head to the restaurant!",
                ['order_id' => (string)$id, 'type' => 'ready_for_pickup']);
        }
        respondSuccess(null, 'Order marked ready for pickup');
    }

    // POST /api/restaurant/operator-status
    // Body: { status: "online" | "busy" | "closed" }
    public static function updateOperatorStatus(): void {
        $ctx    = self::requireRestaurant();
        $data   = json_decode(file_get_contents('php://input'), true) ?? [];
        $status = $data['status'] ?? '';
        if (!in_array($status, ['online', 'busy', 'closed'])) {
            respondError('status must be one of: online, busy, closed');
        }
        $db  = $ctx['db'];
        $rid = $ctx['restaurant_id'];
        $db->query("UPDATE restaurants SET operator_status='$status' WHERE id=$rid");
        respondSuccess(null, "Restaurant status set to $status");
    }

    // GET /api/restaurant/menu
    public static function getMenu(): void {
        $ctx = self::requireRestaurant();
        $db  = $ctx['db'];
        $rid = $ctx['restaurant_id'];

        $stmt = $db->prepare("SELECT * FROM categories WHERE restaurant_id=? ORDER BY sort_order");
        $stmt->bind_param('i', $rid);
        $stmt->execute();
        $categories = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

        foreach ($categories as &$cat) {
            $cid   = $cat['id'];
            $stmt2 = $db->prepare("SELECT * FROM menu_items WHERE category_id=? AND restaurant_id=?");
            $stmt2->bind_param('ii', $cid, $rid);
            $stmt2->execute();
            $cat['items'] = $stmt2->get_result()->fetch_all(MYSQLI_ASSOC);
        }
        respondSuccess($categories);
    }

    // POST /api/restaurant/menu/category
    public static function addCategory(): void {
        $ctx  = self::requireRestaurant();
        $data = json_decode(file_get_contents('php://input'), true) ?? [];
        $name = trim($data['name'] ?? '');
        if (!$name) respondError('name is required');
        $rid  = $ctx['restaurant_id'];
        $db   = $ctx['db'];
        $stmt = $db->prepare("INSERT INTO categories (restaurant_id, name) VALUES (?,?)");
        $stmt->bind_param('is', $rid, $name);
        $stmt->execute();
        respondSuccess(['id' => $db->insert_id], 'Category added', 201);
    }

    // PUT /api/restaurant/menu/category/{id}
    public static function updateCategory(int $id): void {
        $ctx  = self::requireRestaurant();
        $data = json_decode(file_get_contents('php://input'), true) ?? [];
        $name = trim($data['name'] ?? '');
        if (!$name) respondError('name is required');
        $rid  = $ctx['restaurant_id'];
        $db   = $ctx['db'];
        $stmt = $db->prepare("UPDATE categories SET name=? WHERE id=? AND restaurant_id=?");
        $stmt->bind_param('sii', $name, $id, $rid);
        $stmt->execute();
        if (!$stmt->affected_rows) respondNotFound('Category not found');
        respondSuccess(null, 'Category updated');
    }

    // DELETE /api/restaurant/menu/category/{id}
    public static function deleteCategory(int $id): void {
        $ctx  = self::requireRestaurant();
        $rid  = $ctx['restaurant_id'];
        $db   = $ctx['db'];
        $stmt = $db->prepare("DELETE FROM categories WHERE id=? AND restaurant_id=?");
        $stmt->bind_param('ii', $id, $rid);
        $stmt->execute();
        if (!$stmt->affected_rows) respondNotFound('Category not found');
        respondSuccess(null, 'Category deleted');
    }

    // POST /api/restaurant/upload
    public static function uploadRestaurantImage(): void {
        $ctx = self::requireRestaurant();
        $rid = $ctx['restaurant_id'];
        $db  = $ctx['db'];

        if (empty($_FILES['image'])) respondError('No image uploaded');
        $file = $_FILES['image'];
        $ext  = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
        $allowed = ['jpg','jpeg','png','webp'];
        if (!in_array($ext, $allowed)) respondError('Invalid image type');
        if ($file['size'] > 5 * 1024 * 1024) respondError('Image too large (max 5MB)');

        $dir = BASEPATH . '/uploads/restaurants/';
        if (!is_dir($dir)) mkdir($dir, 0755, true);
        $filename = 'rest_' . $rid . '_' . time() . '.' . $ext;
        if (!move_uploaded_file($file['tmp_name'], $dir . $filename)) respondError('Failed to save image');

        $baseUrlPath = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https' : 'http') .
            '://' . $_SERVER['HTTP_HOST'] .
            rtrim(dirname(str_replace('/index.php', '', $_SERVER['SCRIPT_NAME'])), '/') .
            '/backend/uploads/restaurants/' . $filename;

        $stmt = $db->prepare("UPDATE restaurants SET image_url=? WHERE id=?");
        $stmt->bind_param('si', $baseUrlPath, $rid);
        $stmt->execute();
        respondSuccess(['image_url' => $baseUrlPath], 'Restaurant image uploaded');
    }

    // POST /api/restaurant/menu/item/{id}/upload
    public static function uploadMenuItemImage(int $id): void {
        $ctx = self::requireRestaurant();
        $rid = $ctx['restaurant_id'];
        $db  = $ctx['db'];

        if (empty($_FILES['image'])) respondError('No image uploaded');
        $file = $_FILES['image'];
        $ext  = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
        $allowed = ['jpg','jpeg','png','webp'];
        if (!in_array($ext, $allowed)) respondError('Invalid image type');
        if ($file['size'] > 5 * 1024 * 1024) respondError('Image too large (max 5MB)');

        $check = $db->prepare("SELECT id FROM menu_items WHERE id=? AND restaurant_id=?");
        $check->bind_param('ii', $id, $rid);
        $check->execute();
        if (!$check->get_result()->fetch_assoc()) respondNotFound('Menu item not found');

        $dir = BASEPATH . '/uploads/menu/';
        if (!is_dir($dir)) mkdir($dir, 0755, true);
        $filename = 'item_' . $id . '_' . time() . '.' . $ext;
        if (!move_uploaded_file($file['tmp_name'], $dir . $filename)) respondError('Failed to save image');

        $baseUrlPath = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https' : 'http') .
            '://' . $_SERVER['HTTP_HOST'] .
            rtrim(dirname(str_replace('/index.php', '', $_SERVER['SCRIPT_NAME'])), '/') .
            '/backend/uploads/menu/' . $filename;

        $stmt = $db->prepare("UPDATE menu_items SET image_url=? WHERE id=? AND restaurant_id=?");
        $stmt->bind_param('sii', $baseUrlPath, $id, $rid);
        $stmt->execute();
        respondSuccess(['image_url' => $baseUrlPath], 'Menu item image uploaded');
    }

    // POST /api/restaurant/menu/item
    public static function addItem(): void {
        $ctx  = self::requireRestaurant();
        $data = json_decode(file_get_contents('php://input'), true) ?? [];
        $rid  = $ctx['restaurant_id'];
        $db   = $ctx['db'];

        $name     = trim($data['name']  ?? '');
        $price    = (float)($data['price'] ?? 0);
        $catId    = (int)($data['category_id'] ?? 0) ?: null;
        $desc     = trim($data['description'] ?? '');
        $isVeg    = !empty($data['is_veg']) ? 1 : 0;
        $isAvail  = !empty($data['is_available']) ? 1 : 0;
        $imageUrl = trim($data['image_url'] ?? '');

        if (!$name || $price <= 0) respondError('name and price are required');

        $stmt = $db->prepare("INSERT INTO menu_items (restaurant_id, category_id, name, description, price, is_veg, is_available, image_url) VALUES (?,?,?,?,?,?,?,?)");
        $stmt->bind_param('iissdiss', $rid, $catId, $name, $desc, $price, $isVeg, $isAvail, $imageUrl);
        $stmt->execute();
        respondSuccess(['id' => $db->insert_id], 'Item added', 201);
    }

    // PUT /api/restaurant/menu/item/{id}
    public static function updateItem(int $id): void {
        $ctx  = self::requireRestaurant();
        $data = json_decode(file_get_contents('php://input'), true) ?? [];
        $rid  = $ctx['restaurant_id'];
        $db   = $ctx['db'];

        $name     = trim($data['name']  ?? '');
        $price    = (float)($data['price'] ?? 0);
        $catId    = (int)($data['category_id'] ?? 0) ?: null;
        $desc     = trim($data['description'] ?? '');
        $isVeg    = !empty($data['is_veg']) ? 1 : 0;
        $isAvail  = isset($data['is_available']) ? (!empty($data['is_available']) ? 1 : 0) : 1;
        $imageUrl = trim($data['image_url'] ?? '');

        $stmt = $db->prepare("UPDATE menu_items SET name=?, description=?, price=?, category_id=?, is_veg=?, is_available=?, image_url=? WHERE id=? AND restaurant_id=?");
        $stmt->bind_param('ssdiiisii', $name, $desc, $price, $catId, $isVeg, $isAvail, $imageUrl, $id, $rid);
        $stmt->execute();
        respondSuccess(null, 'Item updated');
    }

    // DELETE /api/restaurant/menu/item/{id}
    public static function deleteItem(int $id): void {
        $ctx  = self::requireRestaurant();
        $rid  = $ctx['restaurant_id'];
        $db   = $ctx['db'];
        $stmt = $db->prepare("DELETE FROM menu_items WHERE id=? AND restaurant_id=?");
        $stmt->bind_param('ii', $id, $rid);
        $stmt->execute();
        if (!$stmt->affected_rows) respondNotFound('Item not found');
        respondSuccess(null, 'Item deleted');
    }

    // GET /api/restaurant/earnings
    public static function earnings(): void {
        $ctx = self::requireRestaurant();
        $db  = $ctx['db'];
        $rid = $ctx['restaurant_id'];
        $period = $_GET['period'] ?? 'week';

        $where = "restaurant_id=$rid";
        if ($period === 'today') {
            $where .= " AND DATE(created_at) = CURDATE()";
        } elseif ($period === 'week') {
            $where .= " AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)";
        } elseif ($period === 'month') {
            $where .= " AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)";
        }

        $stats = $db->query("SELECT
            COUNT(*) AS total_orders,
            SUM(CASE WHEN order_status='delivered' THEN 1 ELSE 0 END) AS completed_orders,
            SUM(CASE WHEN order_status='delivered' THEN total_amount ELSE 0 END) AS total_revenue,
            AVG(CASE WHEN order_status='delivered' THEN total_amount ELSE NULL END) AS avg_order
            FROM orders WHERE $where")->fetch_assoc();

        $chartData = $db->query("SELECT DATE(created_at) as d, SUM(total_amount) as r
            FROM orders WHERE restaurant_id=$rid AND order_status='delivered'
            AND created_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
            GROUP BY DATE(created_at) ORDER BY d ASC")->fetch_all(MYSQLI_ASSOC);

        $recent = $db->query("SELECT id, total_amount, created_at, order_status
            FROM orders WHERE restaurant_id=$rid
            ORDER BY created_at DESC LIMIT 10")->fetch_all(MYSQLI_ASSOC);

        respondSuccess([
            'total_orders'     => (int)($stats['total_orders'] ?? 0),
            'total_revenue'    => (float)($stats['total_revenue'] ?? 0),
            'avg_order'        => (float)($stats['avg_order'] ?? 0),
            'completed_orders' => (int)($stats['completed_orders'] ?? 0),
            'recent'           => $recent,
            'chart'            => $chartData
        ]);
    }

    // GET /api/restaurant/profile
    public static function getProfile(): void {
        $ctx = self::requireRestaurant();
        $db  = $ctx['db'];
        $rid = $ctx['restaurant_id'];

        $stmt = $db->prepare("SELECT r.*, u.name AS owner_name, u.phone AS owner_phone, u.email AS owner_email
            FROM restaurants r JOIN users u ON u.id=r.user_id WHERE r.id=?");
        $stmt->bind_param('i', $rid);
        $stmt->execute();
        $profile = $stmt->get_result()->fetch_assoc();
        if (!$profile) respondNotFound('Profile not found');

        $profile['lat'] = $profile['lat'] ? (float)$profile['lat'] : null;
        $profile['lng'] = $profile['lng'] ? (float)$profile['lng'] : null;

        respondSuccess($profile);
    }

    // PUT /api/restaurant/profile
    public static function updateProfile(): void {
        $ctx  = self::requireRestaurant();
        $data = json_decode(file_get_contents('php://input'), true) ?? [];
        $db   = $ctx['db'];
        $rid  = $ctx['restaurant_id'];

        if (empty($data)) respondError('No data provided');

        $allowedFields = ['name', 'address', 'cuisine', 'opening_time', 'closing_time', 'lat', 'lng', 'status', 'image_url', 'operator_status'];
        $updates = [];
        $params = [];
        $types = "";

        foreach ($allowedFields as $field) {
            if (isset($data[$field])) {
                $updates[] = "$field=?";
                $val = $data[$field];
                if (in_array($field, ['lat', 'lng'])) {
                    $params[] = (float)$val;
                    $types .= "d";
                } else {
                    $params[] = is_string($val) ? trim($val) : $val;
                    $types .= "s";
                }
            }
        }

        if (empty($updates)) respondError('No valid fields provided');

        $sql = "UPDATE restaurants SET " . implode(", ", $updates) . " WHERE id=?";
        $params[] = $rid;
        $types .= "i";

        $stmt = $db->prepare($sql);
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        respondSuccess(null, 'Profile updated');
    }

    // Broadcast delivery request to delivery boys within a specific radius
    public static function broadcastToNearbyBoys(\mysqli $db, int $orderId, float $rLat, float $rLng, float $radius, string $expiresAtExpr = 'NULL'): void {
        $sql = "SELECT db.id, u.fcm_token,
                (6371 * ACOS(LEAST(1, GREATEST(-1,
                    COS(RADIANS(?)) * COS(RADIANS(db.current_lat)) *
                    COS(RADIANS(db.current_lng) - RADIANS(?)) +
                    SIN(RADIANS(?)) * SIN(RADIANS(db.current_lat))
                )))) AS distance_km
                FROM delivery_boys db
                JOIN users u ON u.id=db.user_id
                WHERE db.status='available' AND db.is_online=1 AND db.active_order_id IS NULL
                HAVING distance_km <= ?";
        
        $stmt = $db->prepare($sql);
        $stmt->bind_param('dddd', $rLat, $rLng, $rLat, $radius);
        $stmt->execute();
        $boys = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

        foreach ($boys as $boy) {
            $boyId = (int)$boy['id'];
            $db->query("INSERT IGNORE INTO delivery_requests (order_id, delivery_boy_id, expires_at) VALUES ($orderId, $boyId, $expiresAtExpr)");

            if ($boy['fcm_token']) {
                sendFCM($boy['fcm_token'], '🛵 New Delivery Request!',
                    "New order #$orderId is waiting for a delivery partner within your range. Tap to accept!",
                    ['order_id' => (string)$orderId, 'type' => 'delivery_request']);
            }
        }
    }
}
