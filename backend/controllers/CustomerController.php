<?php
declare(strict_types=1);

class CustomerController {

    private static function requireAuth(): object {
        $auth = getAuthUser();
        if (!$auth) respondUnauthorized();
        return $auth;
    }

    private static function getSetting(\mysqli $db, string $key, string $default = ''): string {
        $stmt = $db->prepare("SELECT value FROM settings WHERE setting_key=?");
        $stmt->bind_param('s', $key);
        $stmt->execute();
        $r = $stmt->get_result()->fetch_assoc();
        return $r ? $r['value'] : $default;
    }

    // GET /api/customer/home
    public static function home(): void {
        $auth   = self::requireAuth();
        $db     = getDB();
        $lat    = isset($_GET['lat']) ? (float)$_GET['lat'] : null;
        $lng    = isset($_GET['lng']) ? (float)$_GET['lng'] : null;
        $radius = (float)(self::getSetting($db, 'restaurant_visibility_radius', '20'));

        $distanceSelect = "";
        $having         = "";
        if ($lat !== null && $lng !== null) {
            $distanceSelect = ", (6371 * acos(LEAST(1, GREATEST(-1,
                cos(radians($lat)) * cos(radians(r.lat)) * cos(radians(r.lng) - radians($lng)) +
                sin(radians($lat)) * sin(radians(r.lat)))))) AS distance";
            $having = "HAVING distance <= $radius";
        }

        // Exclude closed restaurants
        $result = $db->query("SELECT r.id, r.name, r.image, r.image_url, r.cuisine, r.rating_avg, r.address, r.operator_status $distanceSelect
            FROM restaurants r
            WHERE r.status='approved' AND COALESCE(r.operator_status,'online') != 'closed'
            $having
            ORDER BY r.rating_avg DESC LIMIT 6");
        $restaurants = $result->fetch_all(MYSQLI_ASSOC);

        $result2 = $db->query("SELECT DISTINCT cuisine FROM restaurants WHERE status='approved' AND cuisine IS NOT NULL AND COALESCE(operator_status,'online') != 'closed'");
        $cuisines = array_column($result2->fetch_all(MYSQLI_ASSOC), 'cuisine');

        respondSuccess(['restaurants' => $restaurants, 'cuisines' => $cuisines]);
    }

    // GET /api/restaurants
    public static function listRestaurants(): void {
        self::requireAuth();
        $db    = getDB();
        $page  = max(1, (int)($_GET['page'] ?? 1));
        $limit = 12;
        $off   = ($page - 1) * $limit;
        $search  = '%' . ($db->real_escape_string($_GET['search']  ?? '')) . '%';
        $cuisine = $db->real_escape_string($_GET['cuisine'] ?? '');
        $citySearch = $db->real_escape_string($_GET['city'] ?? '');

        $lat = isset($_GET['lat']) ? (float)$_GET['lat'] : null;
        $lng = isset($_GET['lng']) ? (float)$_GET['lng'] : null;
        $radius = (float)(self::getSetting($db, 'restaurant_visibility_radius', '20'));

        $where = "WHERE r.status='approved' AND COALESCE(r.operator_status,'online') != 'closed'";
        $distanceSelect = "";
        $having = "";

        if ($lat !== null && $lng !== null) {
            $distanceSelect = ", (6371 * acos(LEAST(1, GREATEST(-1,
                cos(radians($lat)) * cos(radians(r.lat)) * cos(radians(r.lng) - radians($lng)) +
                sin(radians($lat)) * sin(radians(r.lat)))))) AS distance";
            $having = "HAVING distance <= $radius";
        }

        if ($_GET['search'] ?? '') $where .= " AND r.name LIKE '$search'";
        if ($cuisine)              $where .= " AND r.cuisine='$cuisine'";
        // City-based manual search (no GPS required)
        if ($citySearch)           $where .= " AND r.address LIKE '%" . $citySearch . "%'";

        if ($having) {
            $totalQuery = "SELECT COUNT(*) as c FROM (SELECT r.id $distanceSelect FROM restaurants r $where $having) AS tmp";
        } else {
            $totalQuery = "SELECT COUNT(*) AS c FROM restaurants r $where";
        }
        $total = $db->query($totalQuery)->fetch_assoc()['c'];

        $orderBy = $having ? "distance ASC, r.rating_avg DESC" : "r.rating_avg DESC";
        $result  = $db->query("SELECT r.id, r.name, r.image, r.image_url, r.cuisine, r.rating_avg, r.rating_count, r.address, r.opening_time, r.closing_time, r.operator_status $distanceSelect
            FROM restaurants r $where $having ORDER BY $orderBy LIMIT $limit OFFSET $off");

        $restaurants = $result->fetch_all(MYSQLI_ASSOC);
        foreach ($restaurants as &$r) {
            if (isset($r['distance'])) $r['distance'] = (float)$r['distance'];
        }

        respondSuccess([
            'restaurants' => $restaurants,
            'page'        => $page,
            'total'       => (int)$total,
            'pages'       => (int)ceil((int)$total / $limit),
        ]);
    }

    // GET /api/restaurants/{id}
    public static function getRestaurant(int $id): void {
        self::requireAuth();
        $db = getDB();
        try {
            $stmt = $db->prepare("SELECT r.*, u.phone AS owner_phone FROM restaurants r JOIN users u ON u.id=r.user_id WHERE r.id=?");
            $stmt->bind_param('i', $id);
            $stmt->execute();
            $restaurant = $stmt->get_result()->fetch_assoc();
            if (!$restaurant) respondNotFound('Restaurant not found');

            $stmtCat = $db->prepare("SELECT id, name FROM categories WHERE restaurant_id=? ORDER BY sort_order, id");
            $stmtCat->bind_param('i', $id);
            $stmtCat->execute();
            $categories = $stmtCat->get_result()->fetch_all(MYSQLI_ASSOC);

            foreach ($categories as &$cat) {
                $cid = (int)$cat['id'];
                $stmtItem = $db->prepare("SELECT id, name, description, price, image, image_url, is_veg, is_available FROM menu_items WHERE category_id=? AND restaurant_id=? AND is_available=1");
                $stmtItem->bind_param('ii', $cid, $id);
                $stmtItem->execute();
                $cat['items'] = $stmtItem->get_result()->fetch_all(MYSQLI_ASSOC);
            }
            unset($cat);

            $stmtRev = $db->prepare("SELECT rv.rating, rv.comment, rv.created_at, u.name AS reviewer
                FROM reviews rv JOIN orders o ON o.id=rv.order_id JOIN users u ON u.id=rv.user_id
                WHERE o.restaurant_id=? AND rv.review_for='restaurant' LIMIT 10");
            $stmtRev->bind_param('i', $id);
            $stmtRev->execute();
            $reviews = $stmtRev->get_result()->fetch_all(MYSQLI_ASSOC);

            $restaurant['categories'] = $categories;
            $restaurant['reviews']    = $reviews;
            
            $restaurant['lat'] = $restaurant['lat'] ? (float)$restaurant['lat'] : null;
            $restaurant['lng'] = $restaurant['lng'] ? (float)$restaurant['lng'] : null;

            respondSuccess($restaurant);
        } catch (\Throwable $e) {
            respondError('Server error: ' . $e->getMessage(), 500);
        }
    }

    // GET /api/cart
    public static function getCart(): void {
        self::requireAuth();
        respondSuccess(['message' => 'Cart is managed client-side.']);
    }
    public static function addToCart(): void    { respondSuccess(null, 'Cart managed client-side'); }
    public static function updateCart(): void   { respondSuccess(null, 'Cart managed client-side'); }
    public static function removeFromCart(): void { respondSuccess(null, 'Cart managed client-side'); }

    // POST /api/cart/apply-coupon
    public static function applyCoupon(): void {
        self::requireAuth();
        $data   = json_decode(file_get_contents('php://input'), true) ?? [];
        $code   = strtoupper(trim($data['code'] ?? ''));
        $amount = (float)($data['subtotal'] ?? 0);
        if (!$code) respondError('coupon code required');

        $db   = getDB();
        $today = date('Y-m-d');
        $stmt = $db->prepare("SELECT * FROM coupons WHERE code=? AND is_active=1
            AND valid_from<=? AND valid_until>=? AND used_count<usage_limit");
        $stmt->bind_param('sss', $code, $today, $today);
        $stmt->execute();
        $coupon = $stmt->get_result()->fetch_assoc();
        if (!$coupon) respondError('Invalid or expired coupon', 404);
        if ($amount < $coupon['min_order_amount']) {
            respondError('Minimum order amount ₹' . $coupon['min_order_amount'] . ' required');
        }

        $discount = $coupon['discount_type'] === 'percent'
            ? round($amount * $coupon['discount_value'] / 100, 2)
            : $coupon['discount_value'];
        $discount = min($discount, $amount);

        respondSuccess([
            'discount'      => $discount,
            'discount_type' => $coupon['discount_type'],
            'code'          => $coupon['code'],
            'message'       => 'Coupon applied! You save ₹' . $discount,
        ]);
    }

    // POST /api/orders/place
    // Enhanced: delivery_option (current/custom), flat_no, landmark, delivery_lat, delivery_lng
    public static function placeOrder(): void {
        $auth = self::requireAuth();
        $data = json_decode(file_get_contents('php://input'), true) ?? [];

        $restaurantId   = (int)($data['restaurant_id']  ?? 0);
        $paymentMethod  = $data['payment_method']        ?? 'cod';
        $items          = $data['items']                 ?? [];
        $couponCode     = strtoupper(trim($data['coupon_code'] ?? ''));
        $specialNotes   = trim($data['special_notes']    ?? '');
        $tipAmount      = (float)($data['tip_amount']    ?? 0);
        $deliveryOption = $data['delivery_option']       ?? 'current'; // 'current' or 'custom'
        $flatNo         = trim($data['flat_no']          ?? '');
        $landmark       = trim($data['landmark']         ?? '');
        $deliveryLat    = (float)($data['delivery_lat']  ?? 0);
        $deliveryLng    = (float)($data['delivery_lng']  ?? 0);
        $addressId      = (int)($data['address_id']      ?? 0);

        if (!$restaurantId || empty($items)) respondError('restaurant_id and items are required');
        if (!in_array($paymentMethod, ['cod', 'upi'])) respondError('Invalid payment method');
        if (!in_array($deliveryOption, ['current', 'custom'])) respondError('delivery_option must be current or custom');

        $db = getDB();

        // Validate restaurant is not closed
        $stmt = $db->prepare("SELECT id FROM restaurants WHERE id=? AND status='approved' AND COALESCE(operator_status,'online') != 'closed'");
        $stmt->bind_param('i', $restaurantId);
        $stmt->execute();
        if (!$stmt->get_result()->num_rows) respondError('Restaurant not available');

        // For current location option: auto-create address from GPS
        if ($deliveryOption === 'current' && $addressId === 0 && $deliveryLat != 0) {
            $uid = $auth->user_id;
            $addrLine = $flatNo ?: "GPS Location";
            $addrCity = trim($data['city'] ?? 'Unknown');
            $stmtA = $db->prepare("INSERT INTO addresses (user_id, address_line1, city, lat, lng, flat_no, landmark, is_default) VALUES (?,?,?,?,?,?,?,0)");
            $stmtA->bind_param('issddss', $uid, $addrLine, $addrCity, $deliveryLat, $deliveryLng, $flatNo, $landmark);
            $stmtA->execute();
            $addressId = (int)$db->insert_id;
            $stmtA->close();
        }

        // Validate and collect item prices
        $subtotal      = 0.0;
        $validatedItems = [];
        foreach ($items as $item) {
            $itemId = (int)($item['id'] ?? 0);
            $qty    = max(1, (int)($item['quantity'] ?? 1));
            $stmt2  = $db->prepare("SELECT id, name, price FROM menu_items WHERE id=? AND restaurant_id=? AND is_available=1");
            $stmt2->bind_param('ii', $itemId, $restaurantId);
            $stmt2->execute();
            $mi = $stmt2->get_result()->fetch_assoc();
            if (!$mi) respondError("Item ID $itemId not found or unavailable");
            $subtotal += $mi['price'] * $qty;
            $validatedItems[] = ['id' => $itemId, 'name' => $mi['name'], 'price' => $mi['price'], 'quantity' => $qty];
        }

        // Apply coupon
        $couponDiscount = 0.0;
        if ($couponCode) {
            $today = date('Y-m-d');
            $stmt3 = $db->prepare("SELECT * FROM coupons WHERE code=? AND is_active=1
                AND valid_from<=? AND valid_until>=? AND used_count<usage_limit FOR UPDATE");
            $stmt3->bind_param('sss', $couponCode, $today, $today);
            $stmt3->execute();
            $coupon = $stmt3->get_result()->fetch_assoc();
            if ($coupon && $subtotal >= $coupon['min_order_amount']) {
                $couponDiscount = $coupon['discount_type'] === 'percent'
                    ? round($subtotal * $coupon['discount_value'] / 100, 2)
                    : $coupon['discount_value'];
                $couponDiscount = min($couponDiscount, $subtotal);
            }
        }

        // Charges
        $deliveryCharge = (float)(self::getSetting($db, 'delivery_charge', '40'));
        $taxPct         = (float)(self::getSetting($db, 'tax_percent', '5'));
        $taxable        = $subtotal - $couponDiscount;
        $tax            = round($taxable * $taxPct / 100, 2);
        $total          = $taxable + $tax + $deliveryCharge + $tipAmount;

        $otp           = str_pad((string)rand(100000, 999999), 6, '0', STR_PAD_LEFT);
        $paymentStatus = $paymentMethod === 'upi' ? 'successful' : 'pending';
        $userId        = $auth->user_id;

        $db->begin_transaction();
        try {
            $stmt4 = $db->prepare("INSERT INTO orders
                (user_id, restaurant_id, address_id, payment_method, payment_status, order_status,
                 delivery_otp, subtotal, delivery_charge, tax_amount, total_amount, tip_amount,
                 coupon_code, coupon_discount, special_notes,
                 delivery_option, flat_no, landmark, delivery_lat, delivery_lng)
                VALUES (?,?,?,?,?,'pending',?,?,?,?,?,?,?,?,?,?,?,?,?,?)");
            $stmt4->bind_param('iiisssdddddsdssssdd',
                $userId, $restaurantId, $addressId,
                $paymentMethod, $paymentStatus, $otp,
                $subtotal, $deliveryCharge, $tax, $total, $tipAmount,
                $couponCode, $couponDiscount, $specialNotes,
                $deliveryOption, $flatNo, $landmark, $deliveryLat, $deliveryLng);
            $stmt4->execute();
            $orderId = (int)$db->insert_id;

            foreach ($validatedItems as $vi) {
                $stmt5 = $db->prepare("INSERT INTO order_items (order_id, menu_item_id, quantity, price, name) VALUES (?,?,?,?,?)");
                $stmt5->bind_param('iiids', $orderId, $vi['id'], $vi['quantity'], $vi['price'], $vi['name']);
                $stmt5->execute();
            }

            if ($couponCode && $couponDiscount > 0) {
                $db->query("UPDATE coupons SET used_count=used_count+1 WHERE code='$couponCode'");
            }

            $db->commit();
        } catch (\Throwable $e) {
            $db->rollback();
            respondError('Failed to place order: ' . $e->getMessage(), 500);
        }

        // Notify restaurant
        $restFcm = $db->query("SELECT u.fcm_token FROM restaurants r JOIN users u ON u.id=r.user_id WHERE r.id=$restaurantId")->fetch_assoc();
        if ($restFcm && $restFcm['fcm_token']) {
            sendFCM($restFcm['fcm_token'], '🔔 New Order!', "Order #$orderId received. ₹$total", ['order_id' => (string)$orderId, 'type' => 'new_order']);
        }

        respondSuccess([
            'order_id'       => $orderId,
            'delivery_otp'   => $otp,
            'total_amount'   => $total,
            'payment_status' => $paymentStatus,
        ], 'Order placed successfully', 201);
    }

    // GET /api/orders
    public static function listOrders(): void {
        $auth = self::requireAuth();
        $db   = getDB();
        $uid  = $auth->user_id;
        $stmt = $db->prepare("SELECT o.id, o.order_status, o.payment_status, o.payment_method,
            o.total_amount, o.created_at, r.name AS restaurant_name, r.image AS restaurant_image, r.image_url AS restaurant_image_url
            FROM orders o JOIN restaurants r ON r.id=o.restaurant_id
            WHERE o.user_id=? ORDER BY o.created_at DESC");
        $stmt->bind_param('i', $uid);
        $stmt->execute();
        respondSuccess($stmt->get_result()->fetch_all(MYSQLI_ASSOC));
    }

    // GET /api/refunds
    public static function listRefunds(): void {
        $auth = self::requireAuth();
        $db   = getDB();
        $uid  = $auth->user_id;
        $stmt = $db->prepare("SELECT o.id, o.order_status, o.payment_status, o.payment_method,
            o.total_amount, o.created_at, o.cancelled_at, r.name AS restaurant_name, r.image_url AS restaurant_image_url
            FROM orders o JOIN restaurants r ON r.id=o.restaurant_id
            WHERE o.user_id=? AND o.payment_status='refunded' 
            ORDER BY o.created_at DESC");
        $stmt->bind_param('i', $uid);
        $stmt->execute();
        respondSuccess($stmt->get_result()->fetch_all(MYSQLI_ASSOC));
    }

    // GET /api/orders/{id}
    public static function getOrder(int $id): void {
        $auth = self::requireAuth();
        $db   = getDB();
        $uid  = $auth->user_id;
        $stmt = $db->prepare("SELECT o.*, r.name AS restaurant_name, r.address AS restaurant_address,
            r.lat AS r_lat, r.lng AS r_lng
            FROM orders o JOIN restaurants r ON r.id=o.restaurant_id
            WHERE o.id=? AND o.user_id=?");
        $stmt->bind_param('ii', $id, $uid);
        $stmt->execute();
        $order = $stmt->get_result()->fetch_assoc();
        if (!$order) respondNotFound('Order not found');

        $stmt2 = $db->prepare("SELECT * FROM order_items WHERE order_id=?");
        $stmt2->bind_param('i', $id);
        $stmt2->execute();
        $order['items'] = $stmt2->get_result()->fetch_all(MYSQLI_ASSOC);
        
        $order['delivery_charge'] = $order['delivery_charge'] !== null ? (float)$order['delivery_charge'] : 0.0;
        $order['subtotal'] = (float)$order['subtotal'];
        $order['tax_amount'] = (float)$order['tax_amount'];
        $order['total_amount'] = (float)$order['total_amount'];
        $order['coupon_discount'] = (float)$order['coupon_discount'];

        respondSuccess($order);
    }

    // POST /api/orders/{id}/cancel
    public static function cancelOrder(int $id): void {
        $auth = self::requireAuth();
        $db   = getDB();
        $uid  = $auth->user_id;
        $data = json_decode(file_get_contents('php://input'), true) ?? [];
        $reason = trim($data['reason'] ?? 'Cancelled by customer');

        $stmt = $db->prepare("SELECT order_status, delivery_boy_id FROM orders WHERE id=? AND user_id=?");
        $stmt->bind_param('ii', $id, $uid);
        $stmt->execute();
        $order = $stmt->get_result()->fetch_assoc();
        if (!$order) respondNotFound('Order not found');

        // Block cancellation once picked up
        $nonCancellable = ['out_for_delivery', 'delivered', 'cancelled'];
        if (in_array($order['order_status'], $nonCancellable)) {
            respondError('Cancellation not allowed once the order has been picked up.');
        }

        $db->begin_transaction();
        try {
            // If paid online (successful), mark for refund
            $paymentUpdate = "";
            $stmt3 = $db->prepare("SELECT payment_method, payment_status FROM orders WHERE id=?");
            $stmt3->bind_param('i', $id);
            $stmt3->execute();
            $orderData = $stmt3->get_result()->fetch_assoc();
            
            if ($orderData && $orderData['payment_method'] === 'upi' && $orderData['payment_status'] === 'successful') {
                $paymentUpdate = ", payment_status='refunded'";
            }

            $status = 'cancelled';
            $now    = date('Y-m-d H:i:s');
            $db->query("UPDATE orders SET order_status='$status', cancelled_at='$now', cancellation_reason='$reason' $paymentUpdate WHERE id=$id");

            if ($order['delivery_boy_id']) {
                $bid = (int)$order['delivery_boy_id'];
                $db->query("UPDATE delivery_boys SET status='available', active_order_id=NULL WHERE id=$bid");
            }
            // Cancel any pending delivery requests for this order
            $db->query("UPDATE delivery_requests SET request_status='cancelled', cancelled_reason='Order cancelled by customer' WHERE order_id=$id AND request_status='pending'");
            $db->commit();
        } catch (\Throwable $e) {
            $db->rollback();
            respondError('Failed to cancel order: ' . $e->getMessage(), 500);
        }
        respondSuccess(null, 'Order cancelled successfully');
    }

    // GET /api/orders/{id}/track
    // Enhanced: 7-step timeline, ETA, live delivery boy position
    public static function trackOrder(int $id): void {
        $auth = self::requireAuth();
        $db   = getDB();
        $uid  = $auth->user_id;
        $stmt = $db->prepare("
            SELECT o.order_status, o.delivery_boy_id,
                   o.created_at, o.accepted_at, o.preparing_at, o.ready_at,
                   o.reached_restaurant_at, o.picked_up_at, o.delivered_at,
                   db.current_lat AS boy_lat, db.current_lng AS boy_lng, db.last_seen_at,
                   r.lat AS restaurant_lat, r.lng AS restaurant_lng, r.name AS restaurant_name,
                   COALESCE(o.delivery_lat, a.lat) AS customer_lat,
                   COALESCE(o.delivery_lng, a.lng) AS customer_lng,
                   COALESCE(o.flat_no, a.flat_no) AS flat_no,
                   COALESCE(o.landmark, a.landmark) AS landmark,
                   a.address_line1, a.city,
                   u.name AS delivery_boy_name, u.phone AS delivery_boy_phone
            FROM orders o
            LEFT JOIN delivery_boys db ON db.id=o.delivery_boy_id
            LEFT JOIN users u ON u.id=db.user_id
            LEFT JOIN restaurants r ON r.id=o.restaurant_id
            LEFT JOIN addresses a ON a.id=o.address_id
            WHERE o.id=? AND o.user_id=?");
        $stmt->bind_param('ii', $id, $uid);
        $stmt->execute();
        $track = $stmt->get_result()->fetch_assoc();
        if (!$track) respondNotFound('Order not found');

        // ETA calculation
        $eta = null;
        if ($track['customer_lat'] !== null && $track['boy_lat'] !== null) {
            $boyLat  = (float)$track['boy_lat'];
            $boyLng  = (float)$track['boy_lng'];
            $cLat    = (float)$track['customer_lat'];
            $cLng    = (float)$track['customer_lng'];
            $distKm  = 6371 * acos(min(1, max(-1,
                cos(deg2rad($boyLat)) * cos(deg2rad($cLat)) * cos(deg2rad($cLng) - deg2rad($boyLng)) +
                sin(deg2rad($boyLat)) * sin(deg2rad($cLat))
            )));
            $speedKmh = (float)(self::getSetting($db, 'delivery_avg_speed_kmh', '30'));
            $eta = max(1, (int)round($distKm / $speedKmh * 60));
        }

        $track['eta_minutes'] = $eta;

        // Build 7-step timeline
        $track['timeline'] = [
            ['step' => 'Order Placed',        'done' => true,                                            'time' => $track['created_at']],
            ['step' => 'Restaurant Accepted',  'done' => !empty($track['accepted_at']),                   'time' => $track['accepted_at']],
            ['step' => 'Preparing Food',       'done' => !empty($track['preparing_at']),                  'time' => $track['preparing_at']],
            ['step' => 'Ready for Pickup',     'done' => !empty($track['ready_at']),                      'time' => $track['ready_at']],
            ['step' => 'Agent at Restaurant', 'done' => !empty($track['reached_restaurant_at']),           'time' => $track['reached_restaurant_at']],
            ['step' => 'Picked Up',            'done' => !empty($track['picked_up_at']),                  'time' => $track['picked_up_at']],
            ['step' => 'Delivered',            'done' => $track['order_status'] === 'delivered',           'time' => $track['delivered_at']],
        ];

        $track['boy_lat'] = $track['boy_lat'] !== null ? (float)$track['boy_lat'] : null;
        $track['boy_lng'] = $track['boy_lng'] !== null ? (float)$track['boy_lng'] : null;
        $track['restaurant_lat'] = $track['restaurant_lat'] !== null ? (float)$track['restaurant_lat'] : null;
        $track['restaurant_lng'] = $track['restaurant_lng'] !== null ? (float)$track['restaurant_lng'] : null;
        $track['customer_lat'] = $track['customer_lat'] !== null ? (float)$track['customer_lat'] : null;
        $track['customer_lng'] = $track['customer_lng'] !== null ? (float)$track['customer_lng'] : null;

        respondSuccess($track);
    }

    // POST /api/orders/{id}/tip
    public static function addTip(int $id): void {
        $auth = self::requireAuth();
        $db   = getDB();
        $uid  = $auth->user_id;
        $data = json_decode(file_get_contents('php://input'), true) ?? [];
        $tip  = (float)($data['tip_amount'] ?? 0);
        if ($tip <= 0) respondError('tip_amount must be positive');

        $stmt = $db->prepare("SELECT delivery_boy_id, order_status FROM orders WHERE id=? AND user_id=?");
        $stmt->bind_param('ii', $id, $uid);
        $stmt->execute();
        $order = $stmt->get_result()->fetch_assoc();
        if (!$order) respondNotFound('Order not found');
        if (!in_array($order['order_status'], ['delivered', 'out_for_delivery'])) {
            respondError('Tip can only be added during or after delivery');
        }

        $db->query("UPDATE orders SET tip_amount=tip_amount+$tip, total_amount=total_amount+$tip, boy_tip_paid=boy_tip_paid+$tip WHERE id=$id");

        // Update delivery boy earnings
        if ($order['delivery_boy_id']) {
            $bid = (int)$order['delivery_boy_id'];
            $db->query("UPDATE delivery_boys SET total_earnings=total_earnings+$tip WHERE id=$bid");
        }
        respondSuccess(null, "Tip of ₹$tip added. Thank you!");
    }

    // POST /api/reviews
    public static function postReview(): void {
        $auth = self::requireAuth();
        $data = json_decode(file_get_contents('php://input'), true) ?? [];
        $orderId   = (int)($data['order_id']   ?? 0);
        $rating    = (int)($data['rating']     ?? 0);
        $comment   = trim($data['comment']     ?? '');
        $reviewFor = $data['review_for']       ?? '';

        if (!$orderId || $rating < 1 || $rating > 5 || !in_array($reviewFor, ['restaurant', 'delivery_boy'])) {
            respondError('order_id, rating (1-5), and review_for (restaurant|delivery_boy) are required');
        }

        $db  = getDB();
        $uid = $auth->user_id;
        $stmt = $db->prepare("SELECT id, restaurant_id, delivery_boy_id FROM orders WHERE id=? AND user_id=? AND order_status='delivered'");
        $stmt->bind_param('ii', $orderId, $uid);
        $stmt->execute();
        $order = $stmt->get_result()->fetch_assoc();
        if (!$order) respondError('Order not found or not delivered yet');

        $stmt2 = $db->prepare("INSERT INTO reviews (order_id, user_id, rating, comment, review_for) VALUES (?,?,?,?,?)
            ON DUPLICATE KEY UPDATE rating=VALUES(rating), comment=VALUES(comment)");
        $stmt2->bind_param('iiiss', $orderId, $uid, $rating, $comment, $reviewFor);
        $stmt2->execute();

        if ($reviewFor === 'restaurant') {
            $rid = $order['restaurant_id'];
            $db->query("UPDATE restaurants SET rating_avg=(SELECT AVG(r.rating) FROM reviews r JOIN orders o ON o.id=r.order_id WHERE o.restaurant_id=$rid AND r.review_for='restaurant'),
                rating_count=(SELECT COUNT(*) FROM reviews r JOIN orders o ON o.id=r.order_id WHERE o.restaurant_id=$rid AND r.review_for='restaurant') WHERE id=$rid");
        } elseif ($order['delivery_boy_id']) {
            $dbid = $order['delivery_boy_id'];
            $db->query("UPDATE delivery_boys SET rating_avg=(SELECT AVG(r.rating) FROM reviews r JOIN orders o ON o.id=r.order_id WHERE o.delivery_boy_id=$dbid AND r.review_for='delivery_boy'),
                rating_count=(SELECT COUNT(*) FROM reviews r JOIN orders o ON o.id=r.order_id WHERE o.delivery_boy_id=$dbid AND r.review_for='delivery_boy') WHERE id=$dbid");
        }
        respondSuccess(null, 'Review submitted');
    }

    // GET /api/addresses
    public static function listAddresses(): void {
        $auth = self::requireAuth();
        $db   = getDB();
        $uid  = $auth->user_id;
        $stmt = $db->prepare("SELECT * FROM addresses WHERE user_id=? ORDER BY is_default DESC");
        $stmt->bind_param('i', $uid);
        $stmt->execute();
        respondSuccess($stmt->get_result()->fetch_all(MYSQLI_ASSOC));
    }

    // POST /api/addresses
    public static function addAddress(): void {
        $auth = self::requireAuth();
        $data = json_decode(file_get_contents('php://input'), true) ?? [];
        $uid  = $auth->user_id;
        $line1  = trim($data['address_line1'] ?? '');
        $line2  = trim($data['address_line2'] ?? '');
        $city   = trim($data['city'] ?? '');
        $lat    = (float)($data['lat'] ?? 0);
        $lng    = (float)($data['lng'] ?? 0);
        $isDef  = !empty($data['is_default']) ? 1 : 0;
        $flatNo = trim($data['flat_no'] ?? '');
        $lmark  = trim($data['landmark'] ?? '');
        $label  = trim($data['label'] ?? 'Home');

        if (!$line1 || !$city) respondError('address_line1 and city are required');

        $db = getDB();
        if ($isDef) $db->query("UPDATE addresses SET is_default=0 WHERE user_id=$uid");

        $stmt = $db->prepare("INSERT INTO addresses (user_id, address_line1, address_line2, city, lat, lng, is_default, flat_no, landmark, label) VALUES (?,?,?,?,?,?,?,?,?,?)");
        $stmt->bind_param('isssddiuss', $uid, $line1, $line2, $city, $lat, $lng, $isDef, $flatNo, $lmark, $label);
        // fix bind types (flat_no and landmark are strings)
        $stmt->close();
        $stmt2 = $db->prepare("INSERT INTO addresses (user_id, address_line1, address_line2, city, lat, lng, is_default, flat_no, landmark, label) VALUES (?,?,?,?,?,?,?,?,?,?)");
        $stmt2->bind_param('isssddisss', $uid, $line1, $line2, $city, $lat, $lng, $isDef, $flatNo, $lmark, $label);
        $stmt2->execute();
        respondSuccess(['id' => $db->insert_id], 'Address added', 201);
    }

    // PUT /api/addresses/{id}
    public static function updateAddress(int $id): void {
        $auth = self::requireAuth();
        $data = json_decode(file_get_contents('php://input'), true) ?? [];
        $uid  = $auth->user_id;
        $db   = getDB();

        $stmt = $db->prepare("SELECT id FROM addresses WHERE id=? AND user_id=?");
        $stmt->bind_param('ii', $id, $uid);
        $stmt->execute();
        if (!$stmt->get_result()->num_rows) respondNotFound('Address not found');

        $line1  = trim($data['address_line1'] ?? '');
        $line2  = trim($data['address_line2'] ?? '');
        $city   = trim($data['city'] ?? '');
        $lat    = (float)($data['lat'] ?? 0);
        $lng    = (float)($data['lng'] ?? 0);
        $isDef  = !empty($data['is_default']) ? 1 : 0;
        $flatNo = trim($data['flat_no'] ?? '');
        $lmark  = trim($data['landmark'] ?? '');
        $label  = trim($data['label'] ?? 'Home');

        if ($isDef) $db->query("UPDATE addresses SET is_default=0 WHERE user_id=$uid");

        $stmt2 = $db->prepare("UPDATE addresses SET address_line1=?, address_line2=?, city=?, lat=?, lng=?, is_default=?, flat_no=?, landmark=?, label=? WHERE id=?");
        $stmt2->bind_param('sssddiissi', $line1, $line2, $city, $lat, $lng, $isDef, $flatNo, $lmark, $label, $id);
        // fix types
        $stmt2->close();
        $stmt3 = $db->prepare("UPDATE addresses SET address_line1=?, address_line2=?, city=?, lat=?, lng=?, is_default=?, flat_no=?, landmark=?, label=? WHERE id=?");
        $stmt3->bind_param('sssddiissi', $line1, $line2, $city, $lat, $lng, $isDef, $flatNo, $lmark, $label, $id);
        // Actually let's do it cleanly:
        $stmt3->close();
        $sql = "UPDATE addresses SET address_line1=?, address_line2=?, city=?, lat=?, lng=?, is_default=?, flat_no=?, landmark=?, label=? WHERE id=?";
        $s4 = $db->prepare($sql);
        $s4->bind_param('sssddisssi', $line1, $line2, $city, $lat, $lng, $isDef, $flatNo, $lmark, $label, $id);
        $s4->execute();
        respondSuccess(null, 'Address updated');
    }

    // DELETE /api/addresses/{id}
    public static function deleteAddress(int $id): void {
        $auth = self::requireAuth();
        $uid  = $auth->user_id;
        $db   = getDB();
        $stmt = $db->prepare("DELETE FROM addresses WHERE id=? AND user_id=?");
        $stmt->bind_param('ii', $id, $uid);
        $stmt->execute();
        if (!$stmt->affected_rows) respondNotFound('Address not found');
        respondSuccess(null, 'Address deleted');
    }

    // GET /api/profile
    public static function getProfile(): void {
        $auth = self::requireAuth();
        $db   = getDB();
        $uid  = $auth->user_id;
        $stmt = $db->prepare("SELECT id, name, phone, email, role, created_at FROM users WHERE id=?");
        $stmt->bind_param('i', $uid);
        $stmt->execute();
        respondSuccess($stmt->get_result()->fetch_assoc());
    }

    // PUT /api/profile
    public static function updateProfile(): void {
        $auth = self::requireAuth();
        $data = json_decode(file_get_contents('php://input'), true) ?? [];
        $uid  = $auth->user_id;
        $db   = getDB();
        $name  = trim($data['name']  ?? '');
        $phone = trim($data['phone'] ?? '');
        if (!$name) respondError('name is required');
        $stmt = $db->prepare("UPDATE users SET name=?, phone=? WHERE id=?");
        $stmt->bind_param('ssi', $name, $phone, $uid);
        $stmt->execute();
        if (!empty($data['password'])) {
            $hash  = password_hash($data['password'], PASSWORD_BCRYPT);
            $stmt2 = $db->prepare("UPDATE users SET password=? WHERE id=?");
            $stmt2->bind_param('si', $hash, $uid);
            $stmt2->execute();
        }
        respondSuccess(null, 'Profile updated');
    }

    // GET /api/chat/{order_id}
    public static function getMessages(int $orderId): void {
        $auth = self::requireAuth();
        $db   = getDB();
        $uid  = $auth->user_id;
        $stmt = $db->prepare("
            SELECT cm.id, cm.sender_id, cm.sender_role, cm.message, cm.is_read, cm.created_at,
                   u.name AS sender_name
            FROM chat_messages cm
            JOIN users u ON u.id=cm.sender_id
            JOIN orders o ON o.id=cm.order_id
            WHERE cm.order_id=?
              AND (o.user_id=?
                   OR o.delivery_boy_id IN (SELECT id FROM delivery_boys WHERE user_id=?)
                   OR o.restaurant_id IN (SELECT id FROM restaurants WHERE user_id=?))
            ORDER BY cm.created_at ASC");
        $stmt->bind_param('iiii', $orderId, $uid, $uid, $uid);
        $stmt->execute();
        $messages = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $db->query("UPDATE chat_messages SET is_read=1 WHERE order_id=$orderId AND sender_id!=$uid AND is_read=0");
        respondSuccess($messages);
    }

    // POST /api/chat/{order_id}
    public static function sendMessage(int $orderId): void {
        $auth    = self::requireAuth();
        $data    = json_decode(file_get_contents('php://input'), true) ?? [];
        $message = trim($data['message'] ?? '');
        if (!$message) respondError('message is required');

        $db   = getDB();
        $uid  = $auth->user_id;
        $role = $auth->role;

        $senderRole = match($role) {
            'delivery_boy' => 'delivery_boy',
            'restaurant'   => 'delivery_boy', // reusing enum; chat_messages sender_role could be extended
            default        => 'customer'
        };

        $stmt = $db->prepare("INSERT INTO chat_messages (order_id, sender_id, sender_role, message) VALUES (?,?,?,?)");
        $stmt->bind_param('iiss', $orderId, $uid, $senderRole, $message);
        $stmt->execute();

        // Notify recipient via FCM
        $notifyStmt = $db->prepare("SELECT o.user_id, o.delivery_boy_id FROM orders o WHERE o.id=?");
        $notifyStmt->bind_param('i', $orderId);
        $notifyStmt->execute();
        $orderInfo = $notifyStmt->get_result()->fetch_assoc();
        if ($orderInfo) {
            $recipientId = ($role === 'customer') ? null : (int)$orderInfo['user_id'];
            if ($role !== 'customer' && $recipientId) {
                $fcmRow = $db->query("SELECT fcm_token FROM users WHERE id=$recipientId")->fetch_assoc();
                if ($fcmRow && $fcmRow['fcm_token']) {
                    sendFCM($fcmRow['fcm_token'], '💬 New Message', $message, ['order_id' => (string)$orderId, 'type' => 'chat']);
                }
            } elseif ($role === 'customer' && $orderInfo['delivery_boy_id']) {
                $dboyUid = $db->query("SELECT user_id FROM delivery_boys WHERE id=" . (int)$orderInfo['delivery_boy_id'])->fetch_assoc();
                if ($dboyUid) {
                    $fcmRow = $db->query("SELECT fcm_token FROM users WHERE id=" . (int)$dboyUid['user_id'])->fetch_assoc();
                    if ($fcmRow && $fcmRow['fcm_token']) {
                        sendFCM($fcmRow['fcm_token'], '💬 New Message', $message, ['order_id' => (string)$orderId, 'type' => 'chat']);
                    }
                }
            }
        }

        respondSuccess(['id' => $db->insert_id], 'Message sent', 201);
    }
}
