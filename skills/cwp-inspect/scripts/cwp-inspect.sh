#!/usr/bin/env bash
# cwp-inspect.sh - strictly read-only fact collector for a CWP server.
# Writes ONE Markdown file (--out, default ./cwp-facts.md). Changes nothing else.
# Never reads row data from databases, never reads /root/.my.cnf or config contents.
set -u
OUT="./cwp-facts.md"
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="${2:-}"; shift 2 ;;
    -h|--help) echo "usage: cwp-inspect.sh [--out FILE]  (run as root on the CWP server)"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$OUT" ] || { echo "--out needs a path" >&2; exit 2; }
[ "$(id -u)" -eq 0 ] || { echo "run as root (needed to read panel files)" >&2; exit 1; }
[ -d /usr/local/cwpsrv ] || { echo "not a CWP server (/usr/local/cwpsrv missing)" >&2; exit 1; }

# Redact anything that looks like a secret on any line we print.
redact() { sed -E 's/((pass|pwd|secret|token|key|auth)[A-Za-z_]*[ \t]*[=:][ \t]*).*/\1[REDACTED]/I'; }
sec() { printf '\n## %s\n\n' "$1"; }
blk() { printf '```\n'; cat; printf '```\n'; }
# Run a command, print its output in a code block; never fail the script.
run() { "$@" 2>&1 | head -n 200 | redact | blk; }

# Read-only mysql: default creds come from the root login of the server; we never print them.
MYSQL=(mysql --batch --skip-column-names)
dbq() { "${MYSQL[@]}" -e "$1" 2>/dev/null; }

{
printf '# CWP facts\n\nGenerated: %s (read-only; structure only, no row data, no secrets)\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

sec "OS"
run sh -c 'grep -E "^(PRETTY_NAME|VERSION_ID)=" /etc/os-release; uname -r'

sec "CWP version"
run sh -c 'cat /usr/local/cwp/.conf/version* 2>/dev/null; sh /scripts/cwp_version 2>/dev/null'
echo "Files in /usr/local/cwp/.conf (names only):"
run ls -1 /usr/local/cwp/.conf

sec "cwpsrv PHP"
run /usr/local/cwp/php71/bin/php -v

sec "Listening ports (cwpsrv, web, mail, db)"
run sh -c 'ss -ltnp 2>/dev/null | awk "NR==1 || /:(2030|2031|2082|2083|2086|2087|2302|2304|80|443|25|465|587|993|3306)[ ]/" | sed -E "s/users:.*\"([^\"]+)\".*/proc=\1/"'

sec "Admin modules"
M=/usr/local/cwpsrv/htdocs/resources/admin/modules
total=0; enc=0; plain_list=""
for f in "$M"/*.php; do
  [ -f "$f" ] || continue
  total=$((total+1))
  if head -c 4096 "$f" | grep -q -i -E "ioncube|sg_load|<?php //0"; then enc=$((enc+1)); else plain_list="$plain_list $(basename "$f")"; fi
done
echo "total=$total encoded=$enc plain=$((total-enc))"
echo
echo "Plain (not ionCube-encoded, likely third-party or stock examples):"
printf '%s\n' "$plain_list" | tr ' ' '\n' | sed '/^$/d' | blk

sec "3rdparty.php menu entries (labels and targets only)"
P=/usr/local/cwpsrv/htdocs/resources/admin/include/3rdparty.php
if [ -f "$P" ]; then grep -o -E 'module=[A-Za-z0-9_-]+|>[^<>]+</a>' "$P" | blk; else echo "absent"; fi

sec "User panel modules"
run ls -1 /usr/local/cwpsrv/var/services/user_files/modules

sec "Immutability (lsattr -d)"
run lsattr -d /usr/local/cwpsrv/htdocs/admin /usr/local/cwpsrv/htdocs/resources/admin /usr/local/cwpsrv/htdocs/resources/admin/modules /usr/local/cwpsrv/htdocs/resources/admin/include

sec "Database root_cwp: tables and columns (structure only)"
for t in $(dbq "SHOW TABLES FROM root_cwp"); do
  printf '### root_cwp.%s\n' "$t"
  dbq "SHOW COLUMNS FROM root_cwp.\`$t\`" | cut -f1,2 | blk
done

sec "Database postfix: tables and columns (structure only)"
for t in $(dbq "SHOW TABLES FROM postfix"); do
  printf '### postfix.%s\n' "$t"
  dbq "SHOW COLUMNS FROM postfix.\`$t\`" | cut -f1,2 | blk
done
echo "Databases present (names only):"
dbq "SHOW DATABASES" | grep -E '^(root_cwp|postfix|roundcube|oauthv2)$' | blk

sec "Web server stack"
run sh -c 'for s in httpd nginx varnish cwpsrv cwp-phpfpm postfix dovecot named mariadb mysqld; do printf "%s: " "$s"; systemctl is-active "$s" 2>/dev/null || echo unknown; done'
echo "Vhost dirs:"
run ls -d /usr/local/apache/conf.d/vhosts /etc/nginx/conf.d/vhosts /etc/varnish
cat /usr/local/cwp/.conf/web_servers.conf 2>/dev/null | grep -v -i -E 'pass|key|secret' | blk

sec "PHP-FPM / PHP versions (/opt/alt)"
run ls -1 /opt/alt

sec "Cron (names and schedules only)"
echo "/etc/cron.d:"; run ls -1 /etc/cron.d
echo "root crontab (commands, redacted):"; run cat /var/spool/cron/root

sec "/scripts"
run ls -1 /scripts

sec "Hooks config"
run ls -l /usr/local/cwpsrv/htdocs/resources/admin/include/hooks.php /usr/local/cwp/.conf/hooks.conf /usr/local/cwpsrv/htdocs/resources/conf/hooks

sec "Resources"
run df -h -x tmpfs -x devtmpfs
run free -m
run sh -c 'ls -d /home/tmp_bak 2>/dev/null && du -sh /home/tmp_bak 2>/dev/null'

sec "Backup tooling versions"
run sh -c 'restic version 2>&1; aws --version 2>&1; which -a aws 2>&1'
} > "$OUT" 2>&1

echo "wrote $OUT"
