#!/usr/bin/env bash
# Sourceable CWP API helper. Usage:  . cwp_api.sh ; cwp_api account action=list
# Env: CWP_HOST (host[:port]), CWP_API_KEY, CWP_VERIFY_TLS=0 (self-signed lab only), CWP_CACERT.
# The key goes to curl on stdin (-K -), never in argv or the process list.

_cwp_esc() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }

# cwp_api FUNCTION key=value ...   -> prints the body; returns 0 ok, 2 API error, 3 non-JSON, 5 transport
cwp_api() {
  local fn="$1"; shift
  local host="${CWP_HOST:?set CWP_HOST}" key="${CWP_API_KEY:?set CWP_API_KEY}"
  case "$host" in *:*) ;; *) host="$host:2304" ;; esac
  local -a args=(-sS -K - --max-time 120 --connect-timeout 10)
  [ "${CWP_VERIFY_TLS:-1}" = "0" ] && args+=(--insecure)
  [ -n "${CWP_CACERT:-}" ] && args+=(--cacert "$CWP_CACERT")

  local body rc=0 kv
  body="$(
    {
      printf 'url = "https://%s/v1/%s/"\nrequest = "POST"\n' "$host" "$fn"
      printf 'data-urlencode = "key=%s"\n' "$(_cwp_esc "$key")"
      for kv in "$@"; do printf 'data-urlencode = "%s"\n' "$(_cwp_esc "$kv")"; done
    } | curl "${args[@]}"
  )" || rc=$?
  [ "$rc" -eq 0 ] || { printf 'cwp_api: transport error (curl %s)\n' "$rc" >&2; return 5; }

  body="${body//"$key"/REDACTED}"
  printf '%s\n' "$body"
  local first="${body#"${body%%[![:space:]]*}"}"
  case "$first" in "{"*|"["*) ;; *) return 3 ;; esac
  case "${first:0:300}" in *'"status":"Error"'*) return 2 ;; esac
  return 0
}

# Example: create an account only if it does not exist yet (billing "order active").
# cwp_account_create alice example.com 'S3cretPass' alice@example.com 203.0.113.10 default
cwp_account_create() {
  local user="$1" domain="$2" pass="$3" email="$4" ip="$5" pkg="$6" list
  [[ "$user" =~ ^[a-z][a-z0-9]*$ ]] || { echo "bad username" >&2; return 4; }
  list="$(cwp_api account action=list)" || return $?
  case "$list" in *"\"username\":\"$user\""*) echo "already exists: $user"; return 0 ;; esac
  cwp_api account action=add "user=$user" "domain=$domain" "pass=$pass" \
    "email=$email" "server_ips=$ip" "package=$pkg"
}
