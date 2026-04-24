<?php
declare(strict_types=1);

class AuthController {

    // POST /api/register
    public static function register(): void {
        $data = json_decode(file_get_contents('php://input'), true) ?? [];
        $name  = trim($data['name']  ?? '');
        $phone = trim($data['phone'] ?? '');
        $email = trim($data['email'] ?? '');
        $pass  = $data['password']   ?? '';
        $role  = $data['role']       ?? 'customer';

        file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] REGISTER ATTEMPT: Email=$email, Role=$role\n", FILE_APPEND);

        try {
            if (!$name || !$phone || !$email || !$pass) {
                respondError('name, phone, email and password are required');
            }

            if (!in_array($role, ['customer', 'restaurant', 'delivery_boy'])) {
                respondError('Invalid role');
            }

            file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] REGISTER: Validating DB\n", FILE_APPEND);
            $db   = getDB();
            $stmt = $db->prepare('SELECT id FROM users WHERE email=? OR phone=?');
            $stmt->bind_param('ss', $email, $phone);
            $stmt->execute();
            if ($stmt->get_result()->num_rows > 0) {
                file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] REGISTER FAILED: Email/Phone already exists ($email)\n", FILE_APPEND);
                respondError('Email or phone already registered', 409);
            }

            file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] REGISTER: Inserting user\n", FILE_APPEND);
            $stmt = $db->prepare('INSERT INTO users (name, phone, email, password, role) VALUES (?,?,?,?,?)');
            $stmt->bind_param('sssss', $name, $phone, $email, $pass, $role);
            if (!$stmt->execute()) {
                file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] REGISTER DB ERROR: " . $db->error . "\n", FILE_APPEND);
                respondError('Registration failed', 500);
            }
            $userId = (int)$db->insert_id;
            file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] REGISTER SUCCESS: UID=$userId\n", FILE_APPEND);

            // Create role-specific profile
            if ($role === 'delivery_boy') {
                $s = $db->prepare('INSERT INTO delivery_boys (user_id) VALUES (?)');
                $s->bind_param('i', $userId);
                $s->execute();
            } elseif ($role === 'restaurant') {
                $rname = trim($data['restaurant_name'] ?? $name . "'s Restaurant");
                $addr  = trim($data['address'] ?? '');
                $s = $db->prepare('INSERT INTO restaurants (user_id, name, address) VALUES (?,?,?)');
                $s->bind_param('iss', $userId, $rname, $addr);
                $s->execute();
            }

            file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] REGISTER: Signing JWT\n", FILE_APPEND);
            $token = jwtSign(['user_id' => $userId, 'role' => $role]);
            respondSuccess(['token' => $token, 'user_id' => $userId, 'role' => $role], 'Registered successfully', 201);
        } catch (Throwable $e) {
            file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] REGISTER CRASH: " . $e->getMessage() . "\n" . $e->getTraceAsString() . "\n", FILE_APPEND);
            respondError('Internal server error', 500);
        }
    }

    // POST /api/login
    public static function login(): void {
        $data  = json_decode(file_get_contents('php://input'), true) ?? [];
        $email = trim($data['email'] ?? '');
        $pass  = $data['password'] ?? '';

        file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] LOGIN ATTEMPT: Email=$email\n", FILE_APPEND);

        try {
            if (!$email || !$pass) {
                file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] LOGIN: Missing email/pass\n", FILE_APPEND);
                respondError('email and password are required');
                return;
            }

            file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] LOGIN: Getting DB\n", FILE_APPEND);
            $db   = getDB();
            
            file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] LOGIN: Preparing query\n", FILE_APPEND);
            $stmt = $db->prepare('SELECT id, name, phone, email, password, role, is_active, fcm_token FROM users WHERE email=?');
            
            if (!$stmt) {
                file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] LOGIN PREPARE ERROR: " . $db->error . "\n", FILE_APPEND);
                respondError('Internal server error', 500);
                return;
            }

            file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] LOGIN: Binding/Executing\n", FILE_APPEND);
            $stmt->bind_param('s', $email);
            if (!$stmt->execute()) {
                 file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] LOGIN EXECUTE ERROR: " . $db->error . "\n", FILE_APPEND);
                 respondError('Internal server error', 500);
                 return;
            }

            file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] LOGIN: Fetching result\n", FILE_APPEND);
            $res  = $stmt->get_result();
            $user = $res->fetch_assoc();

            if (!$user) {
                file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] LOGIN FAILED: User not found ($email)\n", FILE_APPEND);
                respondError('Invalid credentials', 401);
                return;
            }

            file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] LOGIN: Checking password\n", FILE_APPEND);
            if ($pass !== $user['password']) {
                file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] LOGIN FAILED: Password mismatch for $email (InDB: " . $user['password'] . ")\n", FILE_APPEND);
                respondError('Invalid credentials', 401);
                return;
            }

            if (!isset($user['is_active']) || !$user['is_active']) {
                file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] LOGIN FAILED: Account disabled or inactive for $email\n", FILE_APPEND);
                respondError('Account is disabled', 403);
                return;
            }

            file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] LOGIN: Signing JWT\n", FILE_APPEND);
            $token = jwtSign(['user_id' => $user['id'], 'role' => $user['role']]);
            file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] LOGIN SUCCESS: $email (Role: " . $user['role'] . ")\n", FILE_APPEND);

            // Fetch extra profile info for delivery partners
            if ($user['role'] === 'delivery_boy') {
                $stmt2 = $db->prepare("SELECT total_earnings, rating_avg AS rating, vehicle_number, vehicle_type FROM delivery_boys WHERE user_id=?");
                $stmt2->bind_param('i', $user['id']);
                $stmt2->execute();
                $extra = $stmt2->get_result()->fetch_assoc();
                if ($extra) {
                    $user = array_merge($user, $extra);
                }
            }

            unset($user['password']);
            $user['id'] = (int)$user['id'];
            respondSuccess(['token' => $token, 'user' => $user]);
        } catch (Throwable $e) {
            file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] LOGIN CRASH: " . $e->getMessage() . "\n" . $e->getTraceAsString() . "\n", FILE_APPEND);
            respondError('Internal server error', 500);
        }
    }

    // POST /api/update-fcm-token
    public static function updateFcmToken(): void {
        $auth = getAuthUser();
        if (!$auth) respondUnauthorized();

        $data     = json_decode(file_get_contents('php://input'), true) ?? [];
        $fcmToken = trim($data['fcm_token'] ?? '');
        if (!$fcmToken) respondError('fcm_token is required');

        $db   = getDB();
        $uid  = $auth->user_id;
        $stmt = $db->prepare('UPDATE users SET fcm_token=? WHERE id=?');
        $stmt->bind_param('si', $fcmToken, $uid);
        $stmt->execute();
        respondSuccess(null, 'FCM token updated');
    }
}
