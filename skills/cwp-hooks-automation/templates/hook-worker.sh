#!/usr/bin/env bash
# cwp-hook-worker.sh - detached worker started by a CWP action hook stub.
# Install: /usr/local/sbin/cwp-hook-worker.sh, mode 0750 root:root.
# Dry-run by default; the hook stub passes --apply.
#
# Usage: cwp-hook-worker.sh [--apply] EVENT USER [DOMAIN]
set -euo pipefail
umask 027
export PATH=/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin

LOGDIR=/var/log/cwp-forge
LOG="$LOGDIR/worker.log"
LOCK=/var/lock/cwp-hook-worker.lock
STEP_TIMEOUT=300

apply=0
if [ "${1:-}" = "--apply" ]; then apply=1; shift; fi
event="${1:-}" user="${2:-}" domain="${3:-}"

mkdir -p "$LOGDIR"
log() { printf '%s %s %s\n' "$(date -Is)" "${event:-?}" "$*" | tee -a "$LOG" >/dev/null; }

# Validate before anything else. Reject, do not sanitise.
case "$event" in
  account_new|account_remove|account_suspend|account_unsuspend|account_new_domain|account_remove_domain) ;;
  *) log "rejected: unknown event"; exit 64 ;;
esac
[[ "$user" =~ ^[a-z][a-z0-9]{0,31}$ ]] || { log "rejected: bad user"; exit 64; }
if [ -n "$domain" ]; then
  [[ "$domain" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$ ]] || { log "rejected: bad domain"; exit 64; }
fi

# Serialise workers, but wait briefly instead of dropping the event.
exec 9>"$LOCK"
flock -w 60 9 || { log "skipped: lock busy"; exit 75; }

run() { # run a step: print in dry-run, execute with a timeout when applying
  if [ "$apply" = 1 ]; then
    log "run: $*"
    timeout "$STEP_TIMEOUT" "$@" >>"$LOG" 2>&1 || log "step failed (exit $?): $1"
  else
    printf 'DRY RUN would run: %s\n' "$*"
  fi
}

# ---- Your logic goes here. Keep each handler idempotent. ----
handle_account_new()       { run sh /scripts/whoowns "${domain:-example.com}"; }   # placeholder step
handle_account_remove()    { log "account $user removed"; }
handle_account_suspend()   { log "account $user suspended"; }
handle_account_unsuspend() { log "account $user unsuspended"; }
handle_account_new_domain()    { log "domain $domain added to $user"; }
handle_account_remove_domain() { log "domain $domain removed from $user"; }

log "start apply=$apply user=$user domain=${domain:-none}"
"handle_$event"
log "done"
