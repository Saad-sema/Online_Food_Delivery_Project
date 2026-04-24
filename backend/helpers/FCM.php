<?php
declare(strict_types=1);
/**
 * Firebase Cloud Messaging Helper (HTTP v1 API)
 * Falls back to using the legacy FCM server key if v1 is not configured.
 * For production: replace sendFCMv1() with Google OAuth2 token-based HTTP v1.
 */

function sendFCM(string $fcmToken, string $title, string $body, array $data = []): bool {
    if (empty($fcmToken)) return false;

    $serverKey = $_ENV['FCM_SERVER_KEY'] ?? '';
    if (empty($serverKey)) return false;

    $payload = json_encode([
        'to'           => $fcmToken,
        'notification' => [
            'title' => $title,
            'body'  => $body,
            'sound' => 'default',
        ],
        'data'         => $data,
        'priority'     => 'high',
    ]);

    $ch = curl_init('https://fcm.googleapis.com/fcm/send');
    curl_setopt_array($ch, [
        CURLOPT_POST           => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER     => [
            'Authorization: key=' . $serverKey,
            'Content-Type: application/json',
        ],
        CURLOPT_POSTFIELDS => $payload,
        CURLOPT_TIMEOUT    => 10,
    ]);

    $result = curl_exec($ch);
    $err    = curl_errno($ch);
    curl_close($ch);

    if ($err) return false;

    $decoded = json_decode($result, true);
    return isset($decoded['success']) && $decoded['success'] > 0;
}

function sendFCMMultiple(array $fcmTokens, string $title, string $body, array $data = []): void {
    foreach ($fcmTokens as $token) {
        sendFCM($token, $title, $body, $data);
    }
}
