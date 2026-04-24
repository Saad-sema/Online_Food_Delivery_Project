<?php
declare(strict_types=1);

class AdminController {

    private static function requireAdmin(): object {
        $auth = getAuthUser();
        if (!$auth || $auth->role !== 'admin') respondForbidden('Admin access only');
        return $auth;
    }

    // GET /api/admin/dashboard
    public static function dashboard(): void {
        self::requireAdmin();
        $db = getDB();

        $stats = [
            'total_users'       => (int)$db->query("SELECT COUNT(*) c FROM users WHERE role='customer'")->fetch_assoc()['c'],
            'total_restaurants' => (int)$db->query("SELECT COUNT(*) c FROM restaurants")->fetch_assoc()['c'],
            'total_orders'      => (int)$db->query("SELECT COUNT(*) c FROM orders")->fetch_assoc()['c'],
            'delivered_orders'  => (int)$db->query("SELECT COUNT(*) c FROM orders WHERE order_status='delivered'")->fetch_assoc()['c'],
            'pending_orders'    => (int)$db->query("SELECT COUNT(*) c FROM orders WHERE order_status='pending'")->fetch_assoc()['c'],
            'total_revenue'     => (float)$db->query("SELECT COALESCE(SUM(total_amount),0) s FROM orders WHERE order_status='delivered'")->fetch_assoc()['s'],
            'total_delivery_boys'=> (int)$db->query("SELECT COUNT(*) c FROM delivery_boys")->fetch_assoc()['c'],
        ];

        $recent_orders = $db->query("SELECT o.id, o.order_status, o.total_amount, o.created_at,
            u.name AS customer, r.name AS restaurant
            FROM orders o JOIN users u ON u.id=o.user_id JOIN restaurants r ON r.id=o.restaurant_id
            ORDER BY o.created_at DESC LIMIT 10")->fetch_all(MYSQLI_ASSOC);

        $chart_data = $db->query("SELECT DATE(created_at) AS date, COUNT(*) AS orders, SUM(total_amount) AS revenue
            FROM orders WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
            GROUP BY DATE(created_at) ORDER BY date ASC")->fetch_all(MYSQLI_ASSOC);

        respondSuccess(['stats' => $stats, 'recent_orders' => $recent_orders, 'chart_data' => $chart_data]);
    }

    // GET /api/admin/users
    public static function listUsers(): void {
        self::requireAdmin();
        $db     = getDB();
        $page   = max(1, (int)($_GET['page'] ?? 1));
        $limit  = 20;
        $off    = ($page - 1) * $limit;
        $role   = $_GET['role'] ?? '';
        $search = '%' . ($db->real_escape_string($_GET['search'] ?? '')) . '%';

        $where = "WHERE 1";
        if ($role) $where .= " AND role='$role'";
        if ($_GET['search'] ?? '') $where .= " AND (name LIKE '$search' OR email LIKE '$search')";

        $total  = $db->query("SELECT COUNT(*) c FROM users $where")->fetch_assoc()['c'];
        $result = $db->query("SELECT id, name, phone, email, role, is_active, created_at FROM users $where ORDER BY created_at DESC LIMIT $limit OFFSET $off");
        respondSuccess(['users' => $result->fetch_all(MYSQLI_ASSOC), 'total' => (int)$total]);
    }

    // POST /api/admin/users
    public static function createUser(): void {
        self::requireAdmin();
        $data  = json_decode(file_get_contents('php://input'), true) ?? [];
        $name  = trim($data['name']   ?? '');
        $email = trim($data['email']  ?? '');
        $phone = trim($data['phone']  ?? '');
        $pass  = $data['password']    ?? 'Password@123';
        $role  = $data['role']        ?? 'customer';

        if (!$name || !$email) respondError('name and email required');

        $db   = getDB();
        $hash = password_hash($pass, PASSWORD_BCRYPT);
        $stmt = $db->prepare("INSERT INTO users (name, email, phone, password, role) VALUES (?,?,?,?,?)");
        $stmt->bind_param('sssss', $name, $email, $phone, $hash, $role);
        if (!$stmt->execute()) respondError('Email or phone already exists', 409);
        respondSuccess(['id' => $db->insert_id], 'User created', 201);
    }

    // PUT /api/admin/users/{id}
    public static function updateUser(int $id): void {
        self::requireAdmin();
        $data     = json_decode(file_get_contents('php://input'), true) ?? [];
        $db       = getDB();
        $name     = trim($data['name']      ?? '');
        $email    = trim($data['email']     ?? '');
        $phone    = trim($data['phone']     ?? '');
        $role     = $data['role']           ?? '';
        $isActive = isset($data['is_active']) ? (int)$data['is_active'] : 1;

        $stmt = $db->prepare("UPDATE users SET name=?, email=?, phone=?, role=?, is_active=? WHERE id=?");
        $stmt->bind_param('ssssii', $name, $email, $phone, $role, $isActive, $id);
        $stmt->execute();
        respondSuccess(null, 'User updated');
    }

    // DELETE /api/admin/users/{id}
    public static function deleteUser(int $id): void {
        self::requireAdmin();
        $db   = getDB();
        $auth = getAuthUser();
        if ((int)$auth->user_id === $id) respondError('Cannot delete your own account');
        $stmt = $db->prepare("DELETE FROM users WHERE id=?");
        $stmt->bind_param('i', $id);
        $stmt->execute();
        if (!$stmt->affected_rows) respondNotFound('User not found');
        respondSuccess(null, 'User deleted');
    }

    // GET /api/admin/restaurants
    public static function listRestaurants(): void {
        self::requireAdmin();
        $db = getDB();
        $result = $db->query("SELECT r.*, u.name AS owner_name, u.email AS owner_email, u.phone AS owner_phone
            FROM restaurants r JOIN users u ON u.id=r.user_id ORDER BY r.created_at DESC");
        respondSuccess($result->fetch_all(MYSQLI_ASSOC));
    }

    // POST /api/admin/restaurants/approve/{id}
    public static function approveRestaurant(int $id): void {
        self::requireAdmin();
        $data   = json_decode(file_get_contents('php://input'), true) ?? [];
        $status = in_array($data['status'] ?? 'approved', ['approved', 'suspended', 'pending']) ? $data['status'] : 'approved';
        $db     = getDB();
        $stmt   = $db->prepare("UPDATE restaurants SET status=? WHERE id=?");
        $stmt->bind_param('si', $status, $id);
        $stmt->execute();
        if (!$stmt->affected_rows) respondNotFound('Restaurant not found');

        // Notify restaurant owner
        $restFcm = $db->query("SELECT u.fcm_token FROM restaurants r JOIN users u ON u.id=r.user_id WHERE r.id=$id")->fetch_assoc();
        if ($restFcm && $restFcm['fcm_token']) {
            sendFCM($restFcm['fcm_token'], 'Restaurant Status Updated', "Your restaurant has been $status.", ['type' => 'restaurant_status']);
        }
        respondSuccess(null, "Restaurant $status");
    }

    // GET /api/admin/orders
    public static function listOrders(): void {
        self::requireAdmin();
        $db    = getDB();
        $page  = max(1, (int)($_GET['page'] ?? 1));
        $limit = 20;
        $off   = ($page - 1) * $limit;
        $status = $_GET['status'] ?? '';
        $where  = $status ? "WHERE o.order_status='$status'" : '';

        $total  = $db->query("SELECT COUNT(*) c FROM orders o $where")->fetch_assoc()['c'];
        $result = $db->query("SELECT o.id, o.order_status, o.payment_method, o.payment_status,
            o.total_amount, o.created_at, u.name AS customer, r.name AS restaurant
            FROM orders o JOIN users u ON u.id=o.user_id JOIN restaurants r ON r.id=o.restaurant_id
            $where ORDER BY o.created_at DESC LIMIT $limit OFFSET $off");
        respondSuccess(['orders' => $result->fetch_all(MYSQLI_ASSOC), 'total' => (int)$total]);
    }

    // GET /api/admin/orders/{id}
    public static function getOrder(int $id): void {
        self::requireAdmin();
        $db   = getDB();
        $stmt = $db->prepare("SELECT o.*, u.name AS customer, u.phone AS customer_phone,
            r.name AS restaurant, db2.id AS db_profile_id,
            udb.name AS delivery_boy_name, udb.phone AS delivery_boy_phone
            FROM orders o
            JOIN users u ON u.id=o.user_id
            JOIN restaurants r ON r.id=o.restaurant_id
            LEFT JOIN delivery_boys db2 ON db2.id=o.delivery_boy_id
            LEFT JOIN users udb ON udb.id=db2.user_id
            WHERE o.id=?");
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $order = $stmt->get_result()->fetch_assoc();
        if (!$order) respondNotFound('Order not found');

        $stmt2 = $db->prepare("SELECT * FROM order_items WHERE order_id=?");
        $stmt2->bind_param('i', $id);
        $stmt2->execute();
        $order['items'] = $stmt2->get_result()->fetch_all(MYSQLI_ASSOC);
        respondSuccess($order);
    }

    // PUT /api/admin/orders/{id}/status
    public static function updateOrderStatus(int $id): void {
        self::requireAdmin();
        $data   = json_decode(file_get_contents('php://input'), true) ?? [];
        $status = $data['status'] ?? '';
        $allowed = ['pending','accepted','assigned','out_for_delivery','delivered','cancelled','rejected'];
        if (!in_array($status, $allowed)) respondError('Invalid status');
        $db   = getDB();
        // Check for refund if cancelled/rejected
        if (in_array($status, ['cancelled', 'rejected'])) {
            $stmtRef = $db->prepare("SELECT payment_method, payment_status FROM orders WHERE id=?");
            $stmtRef->bind_param('i', $id);
            $stmtRef->execute();
            $order = $stmtRef->get_result()->fetch_assoc();
            if ($order && $order['payment_method'] === 'upi' && $order['payment_status'] === 'successful') {
                $db->query("UPDATE orders SET payment_status='refunded' WHERE id=$id");
            }
        }

        $stmt = $db->prepare("UPDATE orders SET order_status=? WHERE id=?");
        $stmt->bind_param('si', $status, $id);
        $stmt->execute();
        if (!$stmt->affected_rows) respondNotFound('Order not found');
        respondSuccess(null, 'Status updated');
    }

    // GET /api/admin/payments
    public static function payments(): void {
        self::requireAdmin();
        $db = getDB();
        $result = $db->query("SELECT o.id, o.payment_method, o.payment_status, o.total_amount, o.created_at,
            u.name AS customer FROM orders o JOIN users u ON u.id=o.user_id
            WHERE o.payment_status='successful' ORDER BY o.created_at DESC LIMIT 50");
        respondSuccess($result->fetch_all(MYSQLI_ASSOC));
    }

    // GET /api/admin/reports/orders
    public static function reportOrders(): void {
        self::requireAdmin();
        $db    = getDB();
        $from  = $_GET['from'] ?? date('Y-m-01');
        $to    = $_GET['to']   ?? date('Y-m-d');
        $from  = $db->real_escape_string($from);
        $to    = $db->real_escape_string($to);

        $result = $db->query("SELECT DATE(o.created_at) AS date, COUNT(*) AS total_orders,
            SUM(CASE WHEN order_status='delivered' THEN 1 ELSE 0 END) AS delivered,
            SUM(CASE WHEN order_status='cancelled' THEN 1 ELSE 0 END) AS cancelled,
            SUM(total_amount) AS gross_revenue
            FROM orders o WHERE DATE(created_at) BETWEEN '$from' AND '$to'
            GROUP BY DATE(o.created_at) ORDER BY date ASC");
        respondSuccess($result->fetch_all(MYSQLI_ASSOC));
    }

    // GET /api/admin/reports/earnings
    public static function reportEarnings(): void {
        self::requireAdmin();
        $db   = getDB();
        $from = $_GET['from'] ?? date('Y-m-01');
        $to   = $_GET['to']   ?? date('Y-m-d');
        $from = $db->real_escape_string($from);
        $to   = $db->real_escape_string($to);

        $result = $db->query("SELECT r.name AS restaurant, SUM(o.total_amount) AS revenue, COUNT(*) AS orders
            FROM orders o JOIN restaurants r ON r.id=o.restaurant_id
            WHERE order_status='delivered' AND DATE(o.created_at) BETWEEN '$from' AND '$to'
            GROUP BY r.id, r.name ORDER BY revenue DESC");
        respondSuccess($result->fetch_all(MYSQLI_ASSOC));
    }

    // GET /api/admin/coupons
    public static function listCoupons(): void {
        self::requireAdmin();
        $db = getDB();
        respondSuccess($db->query("SELECT * FROM coupons ORDER BY created_at DESC")->fetch_all(MYSQLI_ASSOC));
    }

    // POST /api/admin/coupons
    public static function createCoupon(): void {
        self::requireAdmin();
        $data = json_decode(file_get_contents('php://input'), true) ?? [];
        $code  = strtoupper(trim($data['code'] ?? ''));
        $type  = $data['discount_type']   ?? 'flat';
        $val   = (float)($data['discount_value']   ?? 0);
        $min   = (float)($data['min_order_amount'] ?? 0);
        $from  = $data['valid_from']    ?? date('Y-m-d');
        $until = $data['valid_until']   ?? date('Y-m-d', strtotime('+30 days'));
        $limit = (int)($data['usage_limit'] ?? 100);

        if (!$code || !$val) respondError('code and discount_value required');

        $db   = getDB();
        $stmt = $db->prepare("INSERT INTO coupons (code, discount_type, discount_value, min_order_amount, valid_from, valid_until, usage_limit) VALUES (?,?,?,?,?,?,?)");
        $stmt->bind_param('ssddss i', $code, $type, $val, $min, $from, $until, $limit);
        if (!$stmt->execute()) respondError('Coupon code already exists', 409);
        respondSuccess(['id' => $db->insert_id], 'Coupon created', 201);
    }

    // PUT /api/admin/coupons/{id}
    public static function updateCoupon(int $id): void {
        self::requireAdmin();
        $data    = json_decode(file_get_contents('php://input'), true) ?? [];
        $db      = getDB();
        $isActive = isset($data['is_active']) ? (int)$data['is_active'] : 1;
        $type     = $data['discount_type']    ?? 'flat';
        $val      = (float)($data['discount_value']   ?? 0);
        $min      = (float)($data['min_order_amount'] ?? 0);
        $from     = $data['valid_from']  ?? '';
        $until    = $data['valid_until'] ?? '';
        $limit    = (int)($data['usage_limit'] ?? 100);

        $stmt = $db->prepare("UPDATE coupons SET discount_type=?, discount_value=?, min_order_amount=?, valid_from=?, valid_until=?, usage_limit=?, is_active=? WHERE id=?");
        $stmt->bind_param('sddsssii', $type, $val, $min, $from, $until, $limit, $isActive, $id);
        $stmt->execute();
        respondSuccess(null, 'Coupon updated');
    }

    // DELETE /api/admin/coupons/{id}
    public static function deleteCoupon(int $id): void {
        self::requireAdmin();
        $db   = getDB();
        $stmt = $db->prepare("DELETE FROM coupons WHERE id=?");
        $stmt->bind_param('i', $id);
        $stmt->execute();
        if (!$stmt->affected_rows) respondNotFound('Coupon not found');
        respondSuccess(null, 'Coupon deleted');
    }

    // GET /api/admin/reviews
    public static function listReviews(): void {
        self::requireAdmin();
        $db = getDB();
        $result = $db->query("SELECT rv.*, u.name AS customer_name, r.name AS restaurant_name
            FROM reviews rv
            JOIN users u ON u.id=rv.user_id
            JOIN orders o ON o.id=rv.order_id
            JOIN restaurants r ON r.id=o.restaurant_id
            ORDER BY rv.created_at DESC");
        respondSuccess($result->fetch_all(MYSQLI_ASSOC));
    }

    // DELETE /api/admin/reviews/{id}
    public static function deleteReview(int $id): void {
        self::requireAdmin();
        $db   = getDB();
        $stmt = $db->prepare("DELETE FROM reviews WHERE id=?");
        $stmt->bind_param('i', $id);
        $stmt->execute();
        if (!$stmt->affected_rows) respondNotFound('Review not found');
        respondSuccess(null, 'Review deleted');
    }

    // GET /api/admin/settings
    public static function getSettings(): void {
        self::requireAdmin();
        $db     = getDB();
        $result = $db->query("SELECT setting_key, value FROM settings");
        $settings = [];
        foreach ($result->fetch_all(MYSQLI_ASSOC) as $row) {
            $settings[$row['setting_key']] = $row['value'];
        }
        respondSuccess($settings);
    }

    // PUT /api/admin/settings
    public static function updateSettings(): void {
        self::requireAdmin();
        $data = json_decode(file_get_contents('php://input'), true) ?? [];
        $db   = getDB();
        foreach ($data as $key => $value) {
            $key   = $db->real_escape_string((string)$key);
            $value = $db->real_escape_string((string)$value);
            $db->query("INSERT INTO settings (setting_key, value) VALUES ('$key', '$value') ON DUPLICATE KEY UPDATE value='$value'");
        }
        respondSuccess(null, 'Settings updated');
    }
}
