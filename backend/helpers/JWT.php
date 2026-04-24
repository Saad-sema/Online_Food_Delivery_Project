<?php
declare(strict_types=1);

/**
 * JWT Helper – Standalone Implementation
 * (No Composer required)
 */

function jwtSign(array $payload): string {
    $secret = $_ENV['JWT_SECRET'] ?? 'change_me';
    $expiry = (int)($_ENV['JWT_EXPIRY'] ?? 86400);

    $header = json_encode(['typ' => 'JWT', 'alg' => 'HS256']);
    $payload = array_merge($payload, [
        'iat' => time(),
        'exp' => time() + $expiry,
    ]);
    $payload = json_encode($payload);

    $base64UrlHeader = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($header));
    $base64UrlPayload = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($payload));

    $signature = hash_hmac('sha256', $base64UrlHeader . "." . $base64UrlPayload, $secret, true);
    $base64UrlSignature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));

    return $base64UrlHeader . "." . $base64UrlPayload . "." . $base64UrlSignature;
}

function jwtVerify(string $token): ?object {
    try {
        $secret = $_ENV['JWT_SECRET'] ?? 'change_me';
        $parts = explode('.', $token);
        if (count($parts) !== 3) return null;

        [$header, $payload, $signature] = $parts;

        $validSignature = hash_hmac('sha256', $header . "." . $payload, $secret, true);
        $validSignature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($validSignature));

        if ($signature !== $validSignature) return null;

        $data = json_decode(base64_decode(str_replace(['-', '_'], ['+', '/'], $payload)));
        if (!isset($data->exp) || time() > $data->exp) return null;

        return $data;
    } catch (\Throwable $e) {
        return null;
    }
}

function getBearerToken(): ?string {
    $auth = '';
    if (function_exists('getallheaders')) {
        $headers = getallheaders();
        $auth = $headers['Authorization'] ?? $headers['authorization'] ?? '';
    }
    if (!$auth) {
        $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    }
    
    if (preg_match('/Bearer\s+(.+)$/i', $auth, $m)) {
        return $m[1];
    }
    return null;
}

function getAuthUser(): ?object {
    $token = getBearerToken();
    if (!$token) return null;
    $user = jwtVerify($token);
    if ($user) {
        file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] AUTH: Token UID=" . ($user->user_id ?? 'N/A') . ", Role=" . ($user->role ?? 'N/A') . "\n", FILE_APPEND);
    } else {
        file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] AUTH: Invalid Token\n", FILE_APPEND);
    }
    return $user;
}
