#!/usr/bin/env bash
# cwp-review-scan.sh - read-only grep scan of a CWP module for risky patterns.
# Usage: cwp-review-scan.sh [PATH ...]   (default: current directory)
# Output: file:line: RULE-ID [severity] message
# Exit:   0 clean, 1 findings, 2 usage error. Nothing is modified.
# A hit is a lead to review by hand, not a verdict (grep cannot follow data flow).
# shellcheck disable=SC2016  # PHP patterns contain literal $ on purpose
set -u

case ${1:-} in
  -h | --help)
    sed -n '2,6p' "$0"
    exit 0
    ;;
esac

[ $# -eq 0 ] && set -- .
for p in "$@"; do
  [ -e "$p" ] || { echo "no such path: $p" >&2; exit 2; }
done
TARGETS=("$@")
found=0

# scan RULE SEVERITY MESSAGE REGEX [php|sh|all]
scan() {
  local rule=$1 sev=$2 msg=$3 re=$4 kind=${5:-php} out
  local -a inc=(--include='*.php')
  case $kind in
    sh) inc=(--include='*.sh') ;;
    all) inc=(--include='*.php' --include='*.sh') ;;
  esac
  out=$(grep -rnE "${inc[@]}" -e "$re" "${TARGETS[@]}" 2>/dev/null) || return 0
  [ -n "$out" ] || return 0
  found=1
  while IFS= read -r line; do
    printf '%s: %s [%s] %s\n' "$(printf '%s' "$line" | cut -d: -f1,2)" "$rule" "$sev" "$msg"
  done <<<"$out"
}

REQ='\$_(GET|POST|REQUEST|COOKIE)'

# Command execution with variables
scan CWP-SH-01 HIGH "shell function called with a variable or request data; use proc_open with an argument array" \
  '\b(shell_exec|exec|system|passthru|popen)\s*\([^)]*\$'
scan CWP-SH-02 HIGH "backtick shell execution with a variable" '`[^`]*\$[a-zA-Z_{][^`]*`'
scan CWP-SH-03 HIGH "proc_open with a string command (shell is used); pass an array" \
  'proc_open\s*\(\s*("|'"'"'|\$)'
scan CWP-SH-04 MEDIUM "escapeshellarg/escapeshellcmd in use; last resort only, prefer argument arrays" \
  'escapeshell(arg|cmd)\s*\('
scan CWP-SH-05 HIGH "eval/assert/create_function/preg_replace /e style dynamic code" \
  '\b(eval|create_function)\s*\(|\bassert\s*\(\s*\$'
scan CWP-SH-06 HIGH "shell script: unquoted variable in eval or sh -c" '\beval\b|\b(sh|bash)\s+-c\s+[^'"'"'"]*\$' sh

# SQL
scan CWP-SQL-01 HIGH "SQL built from request data; use prepared statements" \
  "(query|mysqli_query|real_query)\s*\([^;]*${REQ}"
scan CWP-SQL-02 HIGH "SQL string with a concatenated or interpolated variable; use prepare()/bind_param()" \
  '(SELECT|INSERT|UPDATE|DELETE)\s[^;]*(\.\s*\$|"[^"]*\$[a-zA-Z_{])'

# Paths and files
scan CWP-PATH-01 HIGH "request data in a file function; validate against an allowlist and realpath()" \
  "\b(file_get_contents|file_put_contents|fopen|unlink|rename|copy|mkdir|rmdir|readfile|include|include_once|require|require_once|chmod|chown|symlink|touch|scandir|glob)\s*\(?[^;]*${REQ}"
scan CWP-PATH-02 MEDIUM "path built from a variable; check realpath() prefix and refuse symlinks" \
  '\b(file_put_contents|unlink|rename|copy|mkdir|chmod|chown|readfile)\s*\(\s*\$'
scan CWP-PATH-03 MEDIUM "chmod 0777/0666 or world-writable mode" '(chmod|mkdir|umask)\s*\([^)]*0?(777|666|776|766)'

# Output escaping
scan CWP-XSS-01 HIGH "request data echoed or printed without htmlspecialchars/json_encode" \
  "(echo|print)\b[^;]*${REQ}"
scan CWP-XSS-02 MEDIUM "json_encode without JSON_HEX_* flags for HTML/JS output" \
  'json_encode\s*\([^,)]*\)'
scan CWP-XSS-03 MEDIUM "inline <script> assigning a PHP echo; use json_encode with JSON_HEX_TAG|JSON_HEX_AMP|JSON_HEX_APOS|JSON_HEX_QUOT" \
  '=\s*["'"'"']?<\?(php\s+)?=?\s*(echo\s+)?\$'

# Session and CSRF
scan CWP-SESS-01 HIGH "session_start() in a CWP module; CWP owns the session and writes do not persist" \
  '\bsession_start\s*\('
scan CWP-SESS-02 MEDIUM "writes to \$_SESSION do not persist under CWP's handler" '\$_SESSION\s*\[[^]]+\]\s*='
scan CWP-CSRF-01 MEDIUM "request data used with rand/md5/sha1 for a token; use hash_hmac sha256 of the session token" \
  '\b(md5|sha1|rand|mt_rand|uniqid)\s*\('
scan CWP-CSRF-02 MEDIUM "non-constant-time comparison of a token; use hash_equals()" \
  "csrf[a-z_]*['\"]?\]?\s*(==|!=)"

# Identity (user modules)
scan CWP-ID-01 HIGH "user identity taken from request data; use \$_SESSION['username'] only" \
  "(user(name)?|account|owner)['\"]?\]?\s*=\s*${REQ}|${REQ}\s*\[\s*['\"](user|username|account|owner)['\"]"

# Secrets
scan CWP-SEC-01 HIGH "possible hard-coded secret" \
  "(password|passwd|secret|api_?key|token)['\"]?\s*(=>|=)\s*['\"][^'\"\$ ]{8,}['\"]" all
scan CWP-SEC-02 HIGH "secret passed on a command line (visible in ps); use stdin, env or a 0600 file" \
  '(-p|--password|--pass|--secret|--token)[= ]\$|MYSQL_PWD=.*\$|-p"?\$' all
scan CWP-SEC-03 MEDIUM "error output or var_dump/print_r left in code" '\b(var_dump|print_r|var_export|phpinfo)\s*\('
scan CWP-SEC-04 MEDIUM "debug flags: display_errors/error_reporting on" \
  "ini_set\s*\(\s*['\"]display_errors['\"]\s*,\s*['\"]?(1|on|true)"

# Network
scan CWP-NET-01 MEDIUM "curl with TLS verification disabled" 'CURLOPT_SSL_VERIFY(PEER|HOST)\s*,\s*(false|0)|curl\b[^|;]*\s(-k|--insecure)\b' all
scan CWP-NET-02 MEDIUM "request-controlled URL fetched server-side (SSRF); allowlist hosts" \
  "(curl_init|file_get_contents|fopen)\s*\(\s*${REQ}"

# Per-file checks: guards
guard_check() {
  local f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if ! grep -qE 'include_path|ajax_file' "$f"; then
      # Library files included only by a guarded page are fine; flag for a human.
      if grep -qE "${REQ}|<\?php" "$f"; then
        printf '%s:1: CWP-GUARD-01 [MEDIUM] no $include_path/$ajax_file guard; direct URL access possible (ignore only if the file defines functions/classes and is never web-reachable)\n' "$f"
        found=1
      fi
    fi
  done < <(grep -rlE --include='*.php' -e '<\?php' "${TARGETS[@]}" 2>/dev/null)

  while IFS= read -r f; do
    [ -n "$f" ] || continue
    # single quotes: $_SESSION must reach grep literally (set -u would abort on an unset variable).
    # A shared lib included by the AJAX file may hold the check, so require_once/include also passes.
    if ! grep -qE 'logged|\$_SESSION\[.token.\]|require_once|include' "$f"; then
      printf '%s:1: CWP-AUTH-01 [HIGH] AJAX file without its own $_SESSION logged/token check (loader_ajax.php is not enough)\n' "$f"
      found=1
    fi
  done < <(grep -rlE --include='ajax_*.php' -e 'ajax_file' "${TARGETS[@]}" 2>/dev/null)

  # State-changing AJAX/handlers that read POST but never verify a CSRF token
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if ! grep -qiE 'hash_equals|hash_hmac|csrf' "$f"; then
      printf '%s:1: CWP-CSRF-03 [HIGH] reads $_POST but shows no CSRF verification (hash_equals/hash_hmac)\n' "$f"
      found=1
    fi
  done < <(grep -rlE --include='*.php' -e '\$_(POST|REQUEST)' "${TARGETS[@]}" 2>/dev/null)
}
guard_check

# Shell scripts: missing strict mode
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if ! grep -qE '^\s*set\s+-[A-Za-z]*[eu]' "$f"; then
    printf '%s:1: CWP-SH-07 [LOW] no "set -e"/"set -u" strict mode\n' "$f"
    found=1
  fi
done < <(grep -rlE --include='*.sh' -e '^#!' "${TARGETS[@]}" 2>/dev/null)

if [ "$found" -eq 0 ]; then
  echo "cwp-review-scan: no findings (this does not prove the module is safe)"
  exit 0
fi
exit 1
