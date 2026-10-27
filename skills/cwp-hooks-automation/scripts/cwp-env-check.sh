#!/usr/bin/env bash
# cwp-env-check.sh - read-only survey of the hook/automation environment on a CWP server.
# Changes nothing. Run as root on the server. Usage: cwp-env-check.sh [-h]
set -uo pipefail
export PATH=/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,3p' "$0"
  exit 0
fi

RES=/usr/local/cwpsrv/htdocs/resources/admin
hr() { printf '\n== %s ==\n' "$1"; }

hr "CWP version"
if [ -x /scripts/cwp_version ]; then /scripts/cwp_version 2>&1 | head -n 3; else echo "/scripts/cwp_version not found (not a CWP server?)"; fi

hr "Panel PHP"
if [ -x /usr/local/cwp/php71/bin/php ]; then /usr/local/cwp/php71/bin/php -v 2>&1 | head -n 1; else echo "missing /usr/local/cwp/php71/bin/php"; fi

hr "Hook files ($RES/hooks)"
if [ -d "$RES/hooks" ]; then find "$RES/hooks" -type f -name '*.php' -printf '%p  %s bytes  %TY-%Tm-%Td\n' 2>/dev/null | sort; else echo "no hooks dir"; fi

hr "Run-after-update script"
if [ -e /root/.cwp_autoupdate.sh ]; then ls -l /root/.cwp_autoupdate.sh; grep -c . /root/.cwp_autoupdate.sh | sed 's/^/non-empty lines: /'; else echo "/root/.cwp_autoupdate.sh does not exist"; fi

hr "Immutable flags (directories only, depth 3)"
for d in /usr/local/cwpsrv/htdocs/admin "$RES" "$RES/modules" "$RES/include" "$RES/hooks" /usr/local/cwpsrv/htdocs/resources/conf/user_panel; do
  [ -e "$d" ] && lsattr -d -- "$d" 2>/dev/null
done

hr "Admin menu file"
if [ -f "$RES/include/3rdparty.php" ]; then ls -l "$RES/include/3rdparty.php"; grep -c . "$RES/include/3rdparty.php" | sed 's/^/non-empty lines: /'; else echo "include/3rdparty.php does not exist yet"; fi

hr "/etc/cron.d"
ls -l /etc/cron.d 2>/dev/null || echo "no /etc/cron.d"

hr "Root crontab (first 30 lines)"
head -n 30 /var/spool/cron/root 2>/dev/null || echo "no root crontab"

hr "Tools"
for t in flock setsid timeout chattr lsattr curl shellcheck; do
  if command -v "$t" >/dev/null 2>&1; then printf '%-10s yes\n' "$t"; else printf '%-10s NO\n' "$t"; fi
done
