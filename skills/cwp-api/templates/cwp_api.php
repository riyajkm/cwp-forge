<?php
/**
 * Minimal CWP (Control Web Panel) API client. No dependencies, PHP 7.4+.
 *
 * Config from the environment (never hard-code the key):
 *   CWP_HOST         server host or host:port (default port 2304)
 *   CWP_API_KEY      API key from CWP Settings > API Manager
 *   CWP_VERIFY_TLS   "0" to skip certificate verification (self-signed lab only)
 *   CWP_CACERT       optional CA bundle path for a private CA
 *
 * Usage:
 *   $r = cwp_api('account', ['action' => 'list']);
 *   $r = cwp_api('changepack', ['action' => 'udp', 'user' => 'alice', 'package' => 3]);
 */

class CwpApiException extends RuntimeException
{
}

function cwp_redact(string $text, string $key): string
{
    return $key === '' ? $text : str_replace($key, 'REDACTED', $text);
}

/** Decode the leading JSON value of $body; `account del` appends an HTML log after it. */
function cwp_decode_leading_json(string $body)
{
    $body = ltrim($body);
    $data = json_decode($body, true);
    if (is_array($data)) {
        return $data;
    }
    if ($body === '' || ($body[0] !== '{' && $body[0] !== '[')) {
        return null;
    }
    $depth = 0;
    $inStr = false;
    $esc = false;
    $len = strlen($body);
    for ($i = 0; $i < $len; $i++) {
        $c = $body[$i];
        if ($inStr) {
            if ($esc) {
                $esc = false;
            } elseif ($c === '\\') {
                $esc = true;
            } elseif ($c === '"') {
                $inStr = false;
            }
            continue;
        }
        if ($c === '"') {
            $inStr = true;
        } elseif ($c === '{' || $c === '[') {
            $depth++;
        } elseif ($c === '}' || $c === ']') {
            $depth--;
            if ($depth === 0) {
                $d = json_decode(substr($body, 0, $i + 1), true);
                return is_array($d) ? $d : null;
            }
        }
    }
    return null;
}

/**
 * @param string $function URL function, e.g. "account"
 * @param array  $params   form fields; must include "action" (not for testconex)
 * @return array decoded response (status OK)
 * @throws CwpApiException on transport error, non-JSON body or status != OK
 */
function cwp_api(string $function, array $params = []): array
{
    $host = getenv('CWP_HOST') ?: '';
    $key = getenv('CWP_API_KEY') ?: '';
    if ($host === '' || $key === '') {
        throw new CwpApiException('Set CWP_HOST and CWP_API_KEY');
    }
    if (!preg_match('/^[a-z_]+$/', $function)) {
        throw new CwpApiException('Invalid function name');
    }
    if (strpos($host, ':') === false) {
        $host .= ':2304';
    }
    $params['key'] = $key;

    $ch = curl_init("https://{$host}/v1/{$function}/");
    $opts = [
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS     => http_build_query($params), // body, not argv or URL
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_TIMEOUT        => 120,
        CURLOPT_SSL_VERIFYPEER => getenv('CWP_VERIFY_TLS') !== '0',
        CURLOPT_SSL_VERIFYHOST => getenv('CWP_VERIFY_TLS') !== '0' ? 2 : 0,
    ];
    if (getenv('CWP_CACERT')) {
        $opts[CURLOPT_CAINFO] = getenv('CWP_CACERT');
    }
    curl_setopt_array($ch, $opts);
    $body = curl_exec($ch);
    if ($body === false) {
        $err = cwp_redact(curl_error($ch), $key);
        curl_close($ch);
        throw new CwpApiException('CWP API connection error: ' . $err);
    }
    curl_close($ch);

    $data = cwp_decode_leading_json((string) $body);
    if (!is_array($data)) {
        throw new CwpApiException('CWP API returned a non-JSON response');
    }
    // accountquota has no "status"; treat a missing status as OK.
    if (isset($data['status']) && $data['status'] !== 'OK') {
        $msg = $data['msj'] ?? $data['result'] ?? $data['message'] ?? 'unknown error';
        $msg = is_string($msg) ? $msg : json_encode($msg);
        throw new CwpApiException('CWP API error: ' . cwp_redact($msg, $key));
    }
    return $data;
}

/** Billing helper: create, but reconcile first so a retry after a timeout cannot double-create. */
function cwp_account_exists(string $user): bool
{
    $r = cwp_api('account', ['action' => 'list']);
    foreach (($r['msj'] ?? []) as $acc) {
        if (($acc['username'] ?? '') === $user) {
            return true;
        }
    }
    return false;
}

function cwp_package_id(string $name): ?int
{
    $r = cwp_api('packages', ['action' => 'list']);
    foreach (($r['msj'] ?? $r['result'] ?? []) as $p) {
        if (($p['package_name'] ?? '') === $name) {
            return (int) $p['id'];
        }
    }
    return null;
}
