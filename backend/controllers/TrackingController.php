<?php
declare(strict_types=1);

class TrackingController {

    // POST /api/location/update
    // Body: { lat: float, lng: float }
    public static function updateLocation(): void {
        $auth = getAuthUser();
        if (!$auth) respondUnauthorized();

        $data = json_decode(file_get_contents('php://input'), true) ?? [];
        $lat  = isset($data['lat']) ? (float)$data['lat'] : null;
        $lng  = isset($data['lng']) ? (float)$data['lng'] : null;

        if ($lat === null || $lng === null) {
            respondError('lat and lng are required');
        }

        $db   = getDB();
        $uid  = $auth->user_id;
        $role = $auth->role;
        $now  = date('Y-m-d H:i:s');

        $trackRole = match($role) {
            'customer'     => 'customer',
            'restaurant'   => 'restaurant',
            'delivery_boy' => 'delivery',
            default        => 'customer'
        };

        // Insert into location_tracking
        $stmt = $db->prepare(
            "INSERT INTO location_tracking (user_id, role, lat, lng, recorded_at) VALUES (?,?,?,?,?)"
        );
        $stmt->bind_param('isdds', $uid, $trackRole, $lat, $lng, $now);
        $stmt->execute();
        $stmt->close();

        // Update role-specific table with latest position
        if ($role === 'delivery_boy') {
            $db->query("UPDATE delivery_boys SET current_lat=$lat, current_lng=$lng, last_seen_at='$now' WHERE user_id=$uid");
        } elseif ($role === 'restaurant') {
            $db->query("UPDATE restaurants SET lat=$lat, lng=$lng WHERE user_id=$uid");
        }

        respondSuccess(null, 'Location updated');
    }

    // GET /api/geocode/reverse?lat=X&lng=Y
    // Nominatim OSM – free, no API key
    public static function reverseGeocode(): void {
        $auth = getAuthUser();
        if (!$auth) respondUnauthorized();

        $lat = isset($_GET['lat']) ? (float)$_GET['lat'] : null;
        $lng = isset($_GET['lng']) ? (float)$_GET['lng'] : null;

        if ($lat === null || $lng === null) {
            respondError('lat and lng query params are required');
        }

        $url = "https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&zoom=18&addressdetails=1";

        $ctx = stream_context_create([
            'http' => [
                'header'  => "User-Agent: FoodDeliveryApp/1.0\r\n",
                'timeout' => 5,
            ]
        ]);

        $raw = @file_get_contents($url, false, $ctx);
        if ($raw === false) {
            respondError('Geocoding service unavailable. Please enter address manually.');
        }

        $geo = json_decode($raw, true);
        if (!$geo || isset($geo['error'])) {
            respondError('Location not found. Please enter address manually.');
        }

        $addr    = $geo['address'] ?? [];
        $display = $geo['display_name'] ?? '';

        $parts = array_filter([
            $addr['house_number'] ?? '',
            $addr['road'] ?? $addr['pedestrian'] ?? $addr['footway'] ?? '',
            $addr['suburb'] ?? $addr['neighbourhood'] ?? '',
        ]);
        $shortAddress = implode(', ', $parts) ?: (explode(',', $display)[0] ?? $display);

        $city  = $addr['city'] ?? $addr['town'] ?? $addr['village'] ?? $addr['county'] ?? '';
        $state = $addr['state'] ?? '';

        respondSuccess([
            'address'      => $shortAddress,
            'city'         => $city,
            'state'        => $state,
            'display_name' => $display,
            'lat'          => $lat,
            'lng'          => $lng,
        ]);
    }
}
