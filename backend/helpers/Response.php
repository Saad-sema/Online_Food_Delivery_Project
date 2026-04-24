<?php
declare(strict_types=1);
/**
 * JSON Response Helper
 */

function respond(bool $success, string $message, $data = null, int $code = 200): void {
    http_response_code($code);
    $body = ['success' => $success, 'message' => $message];
    if ($data !== null) $body['data'] = $data;
    $json = json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    
    // Log response status for debugging
    file_put_contents(BASEPATH . '/debug.log', "[" . date('Y-m-d H:i:s') . "] RESPONSE $code: " . (strlen($json) > 100 ? substr($json, 0, 100) . '...' : $json) . "\n", FILE_APPEND);
    
    echo $json;
    exit;
}

function respondSuccess($data = null, string $message = 'Success', int $code = 200): void {
    respond(true, $message, $data, $code);
}

function respondError(string $message = 'Error', int $code = 400, $data = null): void {
    respond(false, $message, $data, $code);
}

function respondUnauthorized(string $message = 'Unauthorized'): void {
    respond(false, $message, null, 401);
}

function respondForbidden(string $message = 'Forbidden'): void {
    respond(false, $message, null, 403);
}

function respondNotFound(string $message = 'Not Found'): void {
    respond(false, $message, null, 404);
}
