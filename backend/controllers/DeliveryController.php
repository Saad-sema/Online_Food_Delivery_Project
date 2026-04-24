<?php
declare(strict_types=1);

class DeliveryController {

    private static function requireDelivery(): array {
        $auth = getAuthUser();
        if (!$auth || $auth->role !== 'delivery_boy') respondForbidden('Delivery boy access only');
        $db   = getDB();
        $uid  = $auth->user_id;
        $stmt = $db->prepare("SELECT id, status, is_online, active_order_id, current_lat, current_lng FROM delivery_boys WHERE user_id=?");
        $stmt->bind_param('i', $uid);
        $stmt->execute();
        $boy = $stmt->get_result()->fetch_assoc();
        if (!$boy) respondError('Delivery boy profile not found', 404);
        return [
            'user_id'         => $uid,
            'boy_id'          => (int)$boy['id'],
            'status'          => $boy['status'],
            'is_online'       => (int)($boy['is_online'] ?? 1),
            'active_order_id' => $boy['active_order_id'],
            'lat'             => (float)($boy['current_lat'] ?? 0),
            'lng'             => (float)($boy['current_lng'] ?? 0),
            'db'              => $db,
        ];
    }

    private static function getSetting(\mysqli $db, string $key, string $default = ''): string {
        $stmt = $db->prepare("SELECT value FROM settings WHERE setting_key=?");
        $stmt->bind_param('s', $key);
        $stmt->execute();
        $r = $stmt->get_result()->fetch_assoc();
        return $r ? $r['value'] : $default;
    }

    // GET /api/delivery/requests
    // Returns only THIS delivery boy's broadcast requests that haven't expired
    public static function listRequests(): void {
        $ctx   = self::requireDelivery();
        $db    = $ctx['db'];
        $boyId = $ctx['boy_id'];

        $lat = isset($_GET['lat']) ? (float)$_GET['lat'] : $ctx['lat'];
        $lng = isset($_GET['lng']) ? (float)$_GET['lng'] : $ctx['lng'];

        if (isset($_GET['lat']) && isset($_GET['lng'])) {
            $now = date('Y-m-d H:i:s');
            $db->query("UPDATE delivery_boys SET current_lat=$lat, current_lng=$lng, last_seen_at='$now' WHERE id=$boyId");
        }

        // Also check for & handle expired broadcast rounds
        self::checkAndRetryBroadcast($db);

        try {
            $stmt = $db->prepare("
                SELECT dr.id, dr.order_id, dr.request_status, dr.created_at,
                    o.total_amount, o.subtotal, o.delivery_charge AS delivery_fee,
                    r.name AS restaurant_name, r.address AS restaurant_address,
                    r.lat AS restaurant_lat, r.lng AS restaurant_lng,
                    COALESCE(o.flat_no, a.address_line1) AS customer_address,
                    COALESCE(o.delivery_lat, a.lat) AS customer_lat,
                    COALESCE(o.delivery_lng, a.lng) AS customer_lng,
                    a.city,
                    u.name AS customer_name,
                    (CASE WHEN ? = 0 OR ? = 0 OR r.lat IS NULL OR r.lng IS NULL THEN 9999
                     ELSE (6371 * ACOS(LEAST(1, GREATEST(-1,
                         COS(RADIANS(?)) * COS(RADIANS(r.lat)) *
                         COS(RADIANS(r.lng) - RADIANS(?)) +
                         SIN(RADIANS(?)) * SIN(RADIANS(r.lat))
                     )))) END) AS distance_km
                FROM delivery_requests dr
                JOIN orders o ON o.id=dr.order_id
                JOIN restaurants r ON r.id=o.restaurant_id
                LEFT JOIN addresses a ON a.id=o.address_id
                JOIN users u ON u.id=o.user_id
                WHERE dr.delivery_boy_id=? AND dr.request_status='pending'
                  AND (dr.expires_at IS NULL OR dr.expires_at > NOW())
                  AND o.delivery_boy_id IS NULL
                HAVING distance_km <= 20
                ORDER BY distance_km ASC");

            $stmt->bind_param('dddddi', $lat, $lng, $lat, $lng, $lat, $boyId);
            $stmt->execute();
            $res = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
            foreach ($res as &$row) {
                $row['restaurant_lat'] = $row['restaurant_lat'] !== null ? (float)$row['restaurant_lat'] : null;
                $row['restaurant_lng'] = $row['restaurant_lng'] !== null ? (float)$row['restaurant_lng'] : null;
                $row['customer_lat'] = $row['customer_lat'] !== null ? (float)$row['customer_lat'] : null;
                $row['customer_lng'] = $row['customer_lng'] !== null ? (float)$row['customer_lng'] : null;
            }
            respondSuccess($res);
        } catch (\Throwable $e) {
            respondError('Failed to fetch requests: ' . $e->getMessage(), 500);
        }
    }

    // POST /api/delivery/requests/{id}/accept
    // Broadcast model: first accept wins, all others auto-cancelled
    public static function acceptRequest(int $reqId): void {
        $ctx   = self::requireDelivery();
        $db    = $ctx['db'];
        $boyId = $ctx['boy_id'];

        $db->begin_transaction();
        try {
            // Check this request is still pending
            $stmt = $db->prepare("SELECT dr.id, dr.order_id FROM delivery_requests dr
                WHERE dr.id=? AND dr.delivery_boy_id=? AND dr.request_status='pending'
                FOR UPDATE");
            $stmt->bind_param('ii', $reqId, $boyId);
            $stmt->execute();
            $req = $stmt->get_result()->fetch_assoc();
            if (!$req) {
                $db->rollback();
                respondError('Request no longer available. Order may have been assigned to another delivery partner.');
            }
            $orderId = $req['order_id'];

            $stmt2 = $db->prepare("SELECT order_status FROM orders WHERE id=? FOR UPDATE");
            $stmt2->bind_param('i', $orderId);
            $stmt2->execute();
            $order = $stmt2->get_result()->fetch_assoc();
            if (!in_array($order['order_status'], ['accepted', 'preparing', 'ready_for_pickup'])) {
                $db->rollback();
                respondError('Order already assigned to another delivery partner.');
            }

            $assigned   = 'assigned';
            $stmt3 = $db->prepare("UPDATE orders SET order_status=?, delivery_boy_id=?, assigned_at=NOW() WHERE id=?");
            $stmt3->bind_param('sii', $assigned, $boyId, $orderId);
            $stmt3->execute();

            $stmt4 = $db->prepare("UPDATE delivery_boys SET status='busy', active_order_id=? WHERE id=?");
            $stmt4->bind_param('ii', $orderId, $boyId);
            $stmt4->execute();

            // Accept this request
            $acceptedStatus = 'accepted';
            $stmt5 = $db->prepare("UPDATE delivery_requests SET request_status=? WHERE id=?");
            $stmt5->bind_param('si', $acceptedStatus, $reqId);
            $stmt5->execute();

            // Cancel all other pending requests for this order
            $cancelledStatus = 'cancelled';
            $cancelReason    = 'Order assigned to another delivery partner';
            $stmt6 = $db->prepare("UPDATE delivery_requests SET request_status=?, cancelled_reason=? WHERE order_id=? AND id!=? AND request_status='pending'");
            $stmt6->bind_param('ssii', $cancelledStatus, $cancelReason, $orderId, $reqId);
            $stmt6->execute();

            $db->commit();
        } catch (\Throwable $e) {
            $db->rollback();
            respondError('Failed to accept request: ' . $e->getMessage(), 500);
        }

        // FCM: notify customer
        $custFcm = $db->query("SELECT u.fcm_token FROM orders o JOIN users u ON u.id=o.user_id WHERE o.id=$orderId")->fetch_assoc();
        if ($custFcm && $custFcm['fcm_token']) {
            sendFCM($custFcm['fcm_token'], '🛵 Delivery Boy Assigned!',
                'A delivery partner is on the way to pick up your order!',
                ['order_id' => (string)$orderId, 'type' => 'boy_assigned']);
        }

        respondSuccess(['order_id' => $orderId], 'Request accepted. Order assigned to you.');
    }

    // POST /api/delivery/requests/{id}/reject
    public static function rejectRequest(int $reqId): void {
        $ctx   = self::requireDelivery();
        $db    = $ctx['db'];
        $boyId = $ctx['boy_id'];
        $rejected = 'rejected';
        $stmt  = $db->prepare("UPDATE delivery_requests SET request_status=? WHERE id=? AND delivery_boy_id=? AND request_status='pending'");
        $stmt->bind_param('sii', $rejected, $reqId, $boyId);
        $stmt->execute();
        if (!$stmt->affected_rows) respondError('Request not found or already handled');
        respondSuccess(null, 'Request rejected');
    }

    // GET /api/delivery/active
    public static function activeDelivery(): void {
        $ctx   = self::requireDelivery();
        $db    = $ctx['db'];
        $boyId = $ctx['boy_id'];

        $stmt = $db->prepare("SELECT o.id, o.order_status, o.delivery_otp AS otp, o.total_amount, o.payment_method,
            o.flat_no, o.landmark, o.delivery_lat, o.delivery_lng,
            r.name AS restaurant_name, r.address AS restaurant_address, r.lat AS restaurant_lat, r.lng AS restaurant_lng,
            u.name AS customer_name, u.phone AS customer_phone,
            COALESCE(o.delivery_lat, a.lat) AS customer_lat, COALESCE(o.delivery_lng, a.lng) AS customer_lng,
            COALESCE(o.flat_no, a.flat_no, a.address_line1) AS delivery_address,
            a.city
            FROM orders o
            JOIN restaurants r ON r.id=o.restaurant_id
            JOIN users u ON u.id=o.user_id
            LEFT JOIN addresses a ON a.id=o.address_id
            WHERE o.delivery_boy_id=? AND o.order_status IN ('assigned','reached_restaurant','out_for_delivery')
            ORDER BY o.id DESC LIMIT 1");
        $stmt->bind_param('i', $boyId);
        $stmt->execute();
        $data = $stmt->get_result()->fetch_assoc();

        // Calculate ETA to customer
        if ($data && $data['customer_lat'] && $boyId) {
            $bLat = $ctx['lat'];
            $bLng = $ctx['lng'];
            $cLat = (float)$data['customer_lat'];
            $cLng = (float)$data['customer_lng'];
            if ($bLat && $bLng) {
                $distKm = 6371 * acos(min(1, max(-1,
                    cos(deg2rad($bLat)) * cos(deg2rad($cLat)) * cos(deg2rad($cLng) - deg2rad($bLng)) +
                    sin(deg2rad($bLat)) * sin(deg2rad($cLat))
                )));
                $speed = (float)(self::getSetting($db, 'delivery_avg_speed_kmh', '30'));
                $data['eta_minutes'] = max(1, (int)round($distKm / $speed * 60));
                $data['distance_km'] = round($distKm, 2);
            }
        }

        if ($data) {
            $data['restaurant_lat'] = $data['restaurant_lat'] !== null ? (float)$data['restaurant_lat'] : null;
            $data['restaurant_lng'] = $data['restaurant_lng'] !== null ? (float)$data['restaurant_lng'] : null;
            $data['customer_lat'] = $data['customer_lat'] !== null ? (float)$data['customer_lat'] : null;
            $data['customer_lng'] = $data['customer_lng'] !== null ? (float)$data['customer_lng'] : null;
            $data['delivery_lat'] = $data['delivery_lat'] !== null ? (float)$data['delivery_lat'] : null;
            $data['delivery_lng'] = $data['delivery_lng'] !== null ? (float)$data['delivery_lng'] : null;
        }

        respondSuccess($data);
    }

    // POST /api/delivery/orders/{order_id}/reached-restaurant
    public static function reachedRestaurant(int $orderId): void {
        $ctx   = self::requireDelivery();
        $db    = $ctx['db'];
        $boyId = $ctx['boy_id'];
        $now   = date('Y-m-d H:i:s');

        $stmt = $db->prepare("UPDATE orders SET order_status='reached_restaurant', reached_restaurant_at=NOW() WHERE id=? AND delivery_boy_id=? AND order_status='assigned'");
        $stmt->bind_param('ii', $orderId, $boyId);
        $stmt->execute();
        if (!$stmt->affected_rows) respondError('Cannot update. Order not in assigned state.');

        $custFcm = $db->query("SELECT u.fcm_token FROM orders o JOIN users u ON u.id=o.user_id WHERE o.id=$orderId")->fetch_assoc();
        if ($custFcm && $custFcm['fcm_token']) {
            sendFCM($custFcm['fcm_token'], '🏪 Delivery Partner at Restaurant',
                "Your delivery partner has reached the restaurant for order #$orderId",
                ['order_id' => (string)$orderId, 'type' => 'reached_restaurant']);
        }
        respondSuccess(null, 'Status updated: reached restaurant');
    }

    // POST /api/delivery/orders/{order_id}/start  → out_for_delivery
    public static function startDelivery(int $orderId): void {
        $ctx   = self::requireDelivery();
        $db    = $ctx['db'];
        $boyId = $ctx['boy_id'];

        $stmt = $db->prepare("UPDATE orders SET order_status='out_for_delivery', picked_up_at=NOW() WHERE id=? AND delivery_boy_id=? AND order_status IN ('assigned','reached_restaurant','ready_for_pickup')");
        $stmt->bind_param('ii', $orderId, $boyId);
        $stmt->execute();
        if (!$stmt->affected_rows) respondError('Cannot start delivery. Order not in correct state.');

        $custFcm = $db->query("SELECT u.fcm_token FROM orders o JOIN users u ON u.id=o.user_id WHERE o.id=$orderId")->fetch_assoc();
        if ($custFcm && $custFcm['fcm_token']) {
            sendFCM($custFcm['fcm_token'], '🛵 Out for Delivery!',
                "Your order #$orderId has been picked up and is on the way!",
                ['order_id' => (string)$orderId, 'type' => 'out_for_delivery']);
        }
        respondSuccess(null, 'Delivery started');
    }

    // POST /api/delivery/orders/{order_id}/verify-otp
    public static function verifyOtp(int $orderId): void {
        $ctx   = self::requireDelivery();
        $data  = json_decode(file_get_contents('php://input'), true) ?? [];
        $otp   = trim($data['otp'] ?? '');
        $db    = $ctx['db'];
        $boyId = $ctx['boy_id'];
        if (!$otp) respondError('OTP is required');

        $stmt = $db->prepare("SELECT id, delivery_otp AS otp, payment_method, user_id, delivery_charge, tip_amount FROM orders WHERE id=? AND delivery_boy_id=? AND order_status='out_for_delivery'");
        $stmt->bind_param('ii', $orderId, $boyId);
        $stmt->execute();
        $order = $stmt->get_result()->fetch_assoc();
        if (!$order) respondError('Active order not found');
        if ($order['otp'] !== $otp) respondError('Invalid OTP. Please try again.', 400);

        $db->begin_transaction();
        try {
            $now = date('Y-m-d H:i:s');
            $stmt2 = $db->prepare("UPDATE orders SET order_status='delivered', payment_status='successful', delivered_at=? WHERE id=?");
            $stmt2->bind_param('si', $now, $orderId);
            $stmt2->execute();

            $stmt3 = $db->prepare("UPDATE delivery_boys SET status='available', active_order_id=NULL WHERE id=?");
            $stmt3->bind_param('i', $boyId);
            $stmt3->execute();

            // Calculate earnings: base 30 + distance charge + tip
            $baseCharge = (float)(self::getSetting($db, 'delivery_base_charge', '30'));
            $tipAmt     = (float)($order['tip_amount'] ?? 0);
            $totalEarn  = $baseCharge + $tipAmt;

            $stmt4 = $db->prepare("UPDATE orders SET boy_base_charge=? WHERE id=?");
            $stmt4->bind_param('di', $baseCharge, $orderId);
            $stmt4->execute();

            $stmt5 = $db->prepare("UPDATE delivery_boys SET total_earnings=total_earnings+? WHERE id=?");
            $stmt5->bind_param('di', $totalEarn, $boyId);
            $stmt5->execute();

            $db->commit();
        } catch (\Throwable $e) {
            $db->rollback();
            respondError('Failed to verify OTP: ' . $e->getMessage(), 500);
        }

        $custFcm = $db->query("SELECT fcm_token FROM users WHERE id=" . (int)$order['user_id'])->fetch_assoc();
        if ($custFcm && $custFcm['fcm_token']) {
            sendFCM($custFcm['fcm_token'], '🎉 Order Delivered!',
                "Your order #$orderId has been delivered. Enjoy your meal!",
                ['order_id' => (string)$orderId, 'type' => 'delivered']);
        }
        respondSuccess(['earnings' => 30.0 + (float)$order['tip_amount']], 'Order delivered successfully');
    }

    // POST /api/delivery/location
    public static function updateLocation(): void {
        $ctx  = self::requireDelivery();
        $data = json_decode(file_get_contents('php://input'), true) ?? [];
        $lat  = (float)($data['lat'] ?? 0);
        $lng  = (float)($data['lng'] ?? 0);
        $db   = $ctx['db'];
        $bid  = $ctx['boy_id'];
        $uid  = $ctx['user_id'];
        $now  = date('Y-m-d H:i:s');

        $stmt = $db->prepare("UPDATE delivery_boys SET current_lat=?, current_lng=?, last_seen_at=? WHERE id=?");
        $stmt->bind_param('ddsi', $lat, $lng, $now, $bid);
        $stmt->execute();

        // Insert into location_tracking
        $trackRole = 'delivery';
        $stmt2 = $db->prepare("INSERT INTO location_tracking (user_id, role, lat, lng, recorded_at) VALUES (?,?,?,?,?)");
        $stmt2->bind_param('isdds', $uid, $trackRole, $lat, $lng, $now);
        $stmt2->execute();

        // Log GPS history only during active order
        $activeOrderStmt = $db->prepare("SELECT id FROM orders WHERE delivery_boy_id=? AND order_status IN ('assigned','reached_restaurant','out_for_delivery') LIMIT 1");
        $activeOrderStmt->bind_param('i', $bid);
        $activeOrderStmt->execute();
        $activeOrder = $activeOrderStmt->get_result()->fetch_assoc();

        if ($activeOrder) {
            $oid = $activeOrder['id'];
            $trackStmt = $db->prepare("INSERT INTO delivery_tracking (order_id, delivery_boy_id, lat, lng, recorded_at) VALUES (?,?,?,?,?)");
            $trackStmt->bind_param('iidds', $oid, $bid, $lat, $lng, $now);
            $trackStmt->execute();
        }

        respondSuccess(null, 'Location updated');
    }

    // GET /api/delivery/history
    public static function history(): void {
        $ctx   = self::requireDelivery();
        $db    = $ctx['db'];
        $boyId = $ctx['boy_id'];
        $stmt  = $db->prepare("SELECT o.id, o.order_status, o.total_amount, o.delivery_charge AS delivery_fee,
            o.tip_amount, o.boy_base_charge, o.boy_distance_charge, o.created_at, o.delivered_at,
            r.name AS restaurant_name, u.name AS customer_name
            FROM orders o JOIN restaurants r ON r.id=o.restaurant_id JOIN users u ON u.id=o.user_id
            WHERE o.delivery_boy_id=? AND o.order_status IN ('delivered','cancelled')
            ORDER BY o.created_at DESC LIMIT 50");
        $stmt->bind_param('i', $boyId);
        $stmt->execute();
        respondSuccess($stmt->get_result()->fetch_all(MYSQLI_ASSOC));
    }

    // GET /api/delivery/earnings
    public static function earnings(): void {
        $ctx   = self::requireDelivery();
        $db    = $ctx['db'];
        $boyId = $ctx['boy_id'];

        $boy = $db->query("SELECT total_earnings FROM delivery_boys WHERE id=$boyId")->fetch_assoc();
        $totalEarned = (float)($boy['total_earnings'] ?? 0);

        $stats = $db->query("SELECT COUNT(*) AS total_deliveries,
            SUM(tip_amount) AS total_tips,
            SUM(boy_base_charge) AS total_base,
            SUM(boy_distance_charge) AS total_distance,
            SUM(CASE WHEN DATE(delivered_at)=CURDATE() THEN (boy_base_charge+boy_distance_charge+tip_amount) ELSE 0 END) AS today_earnings
            FROM orders WHERE delivery_boy_id=$boyId AND order_status='delivered'")->fetch_assoc();

        $count = (int)($stats['total_deliveries'] ?? 0);
        $avg   = $count > 0 ? $totalEarned / $count : 0;

        $weekly = $db->query("SELECT DATE(delivered_at) AS date,
            COUNT(*) AS deliveries,
            SUM(boy_base_charge + boy_distance_charge + tip_amount) AS earnings
            FROM orders WHERE delivery_boy_id=$boyId AND order_status='delivered'
            AND delivered_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
            GROUP BY DATE(delivered_at) ORDER BY date ASC")->fetch_all(MYSQLI_ASSOC);

        respondSuccess([
            'total_earnings'     => $totalEarned,
            'today_earnings'     => (float)($stats['today_earnings'] ?? 0),
            'total_deliveries'   => $count,
            'avg_per_delivery'   => $avg,
            'total_tips'         => (float)($stats['total_tips'] ?? 0),
            'total_base_charge'  => (float)($stats['total_base'] ?? 0),
            'total_distance_charge' => (float)($stats['total_distance'] ?? 0),
            'weekly'             => $weekly,
            'monthly'            => $db->query("SELECT DATE_FORMAT(delivered_at,'%Y-%m') AS month, COUNT(*) AS deliveries,
                SUM(boy_base_charge + boy_distance_charge + tip_amount) AS earnings
                FROM orders WHERE delivery_boy_id=$boyId AND order_status='delivered'
                GROUP BY month ORDER BY month DESC LIMIT 12")->fetch_all(MYSQLI_ASSOC)
        ]);
    }

    // PUT/POST /api/delivery/status
    public static function updateStatus(): void {
        $ctx  = self::requireDelivery();
        $data = json_decode(file_get_contents('php://input'), true) ?? [];
        $status = $data['status'] ?? '';
        if (!in_array($status, ['available', 'offline', 'unavailable'])) respondError('Invalid status value');
        $isOnline = ($status === 'available') ? 1 : 0;
        $db  = $ctx['db'];
        $bid = $ctx['boy_id'];
        $stmt = $db->prepare("UPDATE delivery_boys SET status=?, is_online=? WHERE id=?");
        $stmt->bind_param('sii', $status, $isOnline, $bid);
        $stmt->execute();
        respondSuccess(null, "Status set to $status");
    }

    // Broadcast retry/auto-cancel removed — requests are now persistent (no expiry).
    // New delivery boys coming online will need to be re-broadcast separately if needed.
    private static function checkAndRetryBroadcast(\mysqli $db): void {
        // No-op: requests do not expire, so no retry or auto-cancel is needed.
    }
}
