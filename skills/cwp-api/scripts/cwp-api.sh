#!/usr/bin/env bash
# cwp-api.sh - call the CWP REST API (port 2304) without putting the key in argv.
# Read-only actions run at once; mutating actions print the redacted request unless --apply.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: cwp-api.sh FUNCTION [key=value ...] [options]

  FUNCTION   API function, e.g. account, packages, changepack, user_session, testconex
  key=value  request fields. "action" is required except for testconex. Do not pass "key".

Options:
  --dry-run       only print the request (key redacted), never send
  --apply         perform mutating actions (add udp del susp unsp renew)
  --insecure      skip TLS verification (self-signed lab servers only)
  --timeout N     total timeout in seconds (default 120)
  -h, --help      this help

Environment:
  CWP_HOST          server host or host:port (default port 2304)   [required]
  CWP_API_KEY       API key                                          [or CWP_API_KEY_FILE]
  CWP_API_KEY_FILE  file whose first line is the key (mode 600)
  CWP_VERIFY_TLS    set to 0 to behave like --insecure
  CWP_CACERT        CA bundle file to trust (for a private CA)

Exit codes: 0 ok, 2 API error status, 3 non-JSON body, 4 usage, 5 transport error.
USAGE
}

die() { printf 'cwp-api: %s\n' "$*" >&2; exit "${2:-4}"; }

dry=0 apply=0 insecure=0 timeout=120
fn="" pairs=()

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --dry-run) dry=1 ;;
    --apply) apply=1 ;;
    --insecure) insecure=1 ;;
    --timeout) shift; timeout="${1:-}" ;;
    --*) die "unknown option $1" ;;
    *=*) pairs+=("$1") ;;
    *) if [ -z "$fn" ]; then fn="$1"; else die "unexpected argument: $1"; fi ;;
  esac
  shift
done

[ -n "$fn" ] || { usage >&2; exit 4; }
[[ "$fn" =~ ^[a-z_]+$ ]] || die "function name must match ^[a-z_]+$"
[[ "$timeout" =~ ^[0-9]+$ ]] || die "--timeout needs a number"
[ "${CWP_VERIFY_TLS:-1}" = "0" ] && insecure=1

action=""
for kv in "${pairs[@]+"${pairs[@]}"}"; do
  name="${kv%%=*}"
  [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "bad field name: $name"
  [ "$name" = "key" ] && die "do not pass key=...; use CWP_API_KEY or CWP_API_KEY_FILE"
  case "$kv" in *$'\n'*|*$'\r'*) die "newlines are not supported in values ($name)" ;; esac
  [ "$name" = "action" ] && action="${kv#*=}"
done
if [ "$fn" != "testconex" ] && [ -z "$action" ]; then die "action=... is required"; fi

host="${CWP_HOST:-}"
[ -n "$host" ] || die "set CWP_HOST (e.g. server.example.com)"
[[ "$host" =~ ^[A-Za-z0-9.:_-]+$ ]] || die "CWP_HOST has unexpected characters"
case "$host" in *:*) ;; *) host="$host:2304" ;; esac
url="https://$host/v1/$fn/"

mutating=0
case "$action" in add|udp|del|susp|unsp|renew) mutating=1 ;; esac

# Preview: key always redacted.
preview() {
  printf 'POST %s\n' "$url"
  printf '  key=REDACTED\n'
  for kv in "${pairs[@]+"${pairs[@]}"}"; do printf '  %s\n' "$kv"; done
  if [ "$insecure" = 1 ]; then printf '  (TLS verification OFF)\n'; fi
}

if [ "$dry" = 1 ] || { [ "$mutating" = 1 ] && [ "$apply" = 0 ]; }; then
  printf 'DRY RUN (nothing sent)\n'
  preview
  if [ "$mutating" = 1 ] && [ "$apply" = 0 ] && [ "$dry" = 0 ]; then
    printf 'Mutating action: re-run with --apply to send it.\n'
  fi
  exit 0
fi

key="${CWP_API_KEY:-}"
if [ -z "$key" ] && [ -n "${CWP_API_KEY_FILE:-}" ]; then
  [ -r "$CWP_API_KEY_FILE" ] || die "cannot read CWP_API_KEY_FILE"
  IFS= read -r key < "$CWP_API_KEY_FILE" || true
fi
[ -n "$key" ] || die "set CWP_API_KEY or CWP_API_KEY_FILE"
[[ "$key" =~ ^[A-Za-z0-9]+$ ]] || die "key must be alphanumeric (CWP rejects special characters; trailing whitespace?)"
command -v curl >/dev/null 2>&1 || die "curl not found"

# Escape for a curl config-file double-quoted string.
esc() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }

curl_args=(-sS -K - --max-time "$timeout" --connect-timeout 10)
[ "$insecure" = 1 ] && curl_args+=(--insecure)
[ -n "${CWP_CACERT:-}" ] && curl_args+=(--cacert "$CWP_CACERT")

make_config() {
  printf 'url = "%s"\n' "$(esc "$url")"
  printf 'request = "POST"\n'
  printf 'data-urlencode = "key=%s"\n' "$(esc "$key")"
  for kv in "${pairs[@]+"${pairs[@]}"}"; do
    printf 'data-urlencode = "%s"\n' "$(esc "$kv")"
  done
}

rc=0
body="$(make_config | curl "${curl_args[@]}")" || rc=$?
if [ "$rc" -ne 0 ]; then
  die "transport error (curl exit $rc)" 5
fi

body="${body//"$key"/REDACTED}"
printf '%s\n' "$body"

# Judge only the leading JSON (account del appends an HTML log).
first="${body#"${body%%[![:space:]]*}"}"
case "$first" in
  "{"*|"["*) ;;
  *) printf 'cwp-api: response is not JSON\n' >&2; exit 3 ;;
esac
head_part="${first:0:300}"
case "$head_part" in
  *'"status":"Error"'*|*'"status": "Error"'*) exit 2 ;;
esac
exit 0
