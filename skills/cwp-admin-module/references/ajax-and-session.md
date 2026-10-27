# AJAX and session facts (verified on a live CWP Pro server, AlmaLinux 8)

## Routing
- Page: `/usr/local/cwpsrv/htdocs/resources/admin/modules/<name>.php`, URL `index.php?module=<name>`. CWP renders its layout and includes the file with `$include_path` set.
- AJAX: `loader_ajax.php?ajax=<name>&acc=<action>` (relative to the admin URL) loads `resources/admin/addons/ajax/ajax_<name>.php`. In that context `$include_path` is NOT set; `$ajax_file` is.
- `index.php?module=<name>&acc=...` returns the whole HTML layout. Do not use it for AJAX.
- `loader_ajax.php` already refuses logged-out requests (empty response). Still check the session yourself.
- Sub-files in `modules/<name>/` (for example `lib.php`) are fine; require them with `__DIR__`.

## Variables in the AJAX context
`$mysql_conn` (mysqli to `root_cwp`), `$db_host`, `$db_user`, `$db_pass`, `$db_name`, `$mysql_conn_postfix`, `$user_login`, `$users_path`, `$ajax_file`, `$webpanel_version`, `$_SESSION`.
These are variables of the loader's scope. If the loader includes your file inside a function they are not globals, so read them in the entry file and pass them into your lib (the template does this with `<name>_db($mysql_conn)`).

## Session
- `session_status()` reports PHP_SESSION_NONE but `$_SESSION` is populated by CWP's own handler. Writes do not persist. Never call `session_start()`.
- Keys seen: `username`, `logged`, `rkey`, `token`, `csrf_token`.
- Guard: `if (empty($_SESSION['logged']) || empty($_SESSION['token'])) { http_response_code(403); exit; }`.
- Stable CSRF without session writes: `hash_hmac('sha256', '<name>_csrf', $_SESSION['token'])`.

## Response contract used by the templates
- Success `{"ok":true,"data":...}`, failure `{"ok":false,"error":"..."}`, with HTTP 403 (CSRF/session), 405 (wrong method), 404 (unknown action).
- Always `Content-Type: application/json`, `Cache-Control: no-store`, `ob_end_clean()` before output (CWP may have buffered output).
- Errors shown to the browser must be short and generic; log the detail server-side.

## Language file
`resources/admin/modules/language/en/<name>.ini`, `KEY="text"`. Load with `parse_ini_file` from a fixed path. Never build the path from `$_GET['lang']` (the official example does; that is path traversal). INI reserved bare keys: yes, no, on, off, none, null, true, false.

## Database
`root_cwp` tables: backups, domains, nameserver, notifications, packages, settings, subdomains, user.
`user`: id, username, domain, ip_address, email, setup_date, package, backup, reseller, last_access, bandwidth, mail_disk, mysql_disk.
`packages`: package_name, disk_quota, bandwidth, ftp_accounts, email_accounts, databases, sub_domains, ...
Run `SHOW COLUMNS FROM <table>` on the target server before relying on a column; versions differ. Prepared statements only; `get_result()` needs mysqlnd (present on current builds, check with `method_exists('mysqli_stmt','get_result')`).
