#!/usr/bin/env bash
# CWPMOD_TITLE engine: root-side verbs, called by the CWP admin module through an argument array (never a shell string).
# Every input is validated here again; the PHP allowlist is the first gate, this is the second.
set -Eeuo pipefail
umask 077

VERSION='0.1.0'
STATE=/var/lib/cwpmod_example
RE_ACCOUNT='^[a-z][a-z0-9_]{0,31}$'

die() { printf '%s\n' "$1" >&2; exit "${2:-2}"; }

account=''
parse_account() {
  while (($#)); do
    case $1 in
      --account) (($# >= 2)) || die "missing value"; account=$2; shift 2 ;;
      *) die "unknown option" ;;
    esac
  done
  [[ $account =~ $RE_ACCOUNT ]] || die "invalid account"
  [[ -d /home/$account && ! -L /home/$account ]] || die "no such account"
}

verb=${1:-}
(($#)) && shift
case $verb in
  version)
    printf '{"version":"%s"}\n' "$VERSION"
    ;;
  disk-usage)
    parse_account "$@"
    kb=$(du -skx -- "/home/$account" | cut -f1)
    printf '{"account":"%s","disk_kb":%d}\n' "$account" "$kb"
    ;;
  refresh)
    parse_account "$@"
    install -d -m 0700 -- "$STATE"
    date -u +%FT%TZ >"$STATE/last-refresh-$account"
    printf '{"account":"%s","refreshed":true}\n' "$account"
    ;;
  *) die "unknown verb" ;;
esac
