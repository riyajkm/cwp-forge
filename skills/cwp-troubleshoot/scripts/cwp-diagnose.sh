#!/usr/bin/env bash
# cwp-diagnose.sh <area> - read-only diagnostics for a CWP server. Changes nothing.
# shellcheck disable=SC2016  # sh_ takes single-quoted command strings on purpose
# areas: backup ssl mail phpfpm cwpsrv perms disk mysql all
set -u
[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }
redact() { sed -E 's/((pass|pwd|secret|token|key|auth)[A-Za-z_]*[ \t]*[=:][ \t]*).*/\1[REDACTED]/I'; }
h() { printf '\n=== %s ===\n' "$1"; }
r() { printf '$ %s\n' "$*"; "$@" 2>&1 | head -n 60 | redact; }
sh_() { printf '$ %s\n' "$1"; sh -c "$1" 2>&1 | head -n 60 | redact; }

backup() {
  h "AWS CLI version (v1 crashes with NoneType on empty S3 error messages)"
  sh_ 'aws --version; which -a aws'
  h "restic"; sh_ 'restic version'
  h "Stale 'backup running' signs: processes and temp files"
  sh_ 'pgrep -af "backup|restic|aws s3" | grep -v pgrep'
  sh_ 'ls -ld /home/tmp_bak; du -sh /home/tmp_bak; ls -lt /home/tmp_bak | head -n 10'
  sh_ 'ls -l /usr/local/cwp/.conf/backup_manager.conf'
  h "Recent backup log lines"
  sh_ 'ls -t /var/log/cwp/*backup* 2>/dev/null | head -n 3'
  sh_ 'tail -n 40 "$(ls -t /var/log/cwp/*backup* 2>/dev/null | head -n 1)"'
  h "Disk space for backups"; r df -h /home /backup
}
ssl() {
  h "AutoSSL log"; r tail -n 40 /var/log/cwp/autossl.log
  h "acme.sh"; sh_ 'ls /root/.acme.sh | head -n 20'
  h "Challenge dir"; r ls -ld /usr/local/apache/autossl_tmp/.well-known/acme-challenge
  h "Certificates (expiry)"
  sh_ 'for c in /etc/pki/tls/certs/*.cert /etc/pki/tls/certs/*.crt; do [ -f "$c" ] && printf "%s " "$c" && openssl x509 -noout -enddate -in "$c"; done 2>/dev/null | head -n 40'
}
mail() {
  h "Services"; sh_ 'systemctl is-active postfix dovecot'
  h "Queue"; r postqueue -p | tail -n 5
  sh_ 'postqueue -p | grep -c "^[A-F0-9]"'
  h "maillog tail"; r tail -n 40 /var/log/maillog
  h "Dovecot"; sh_ 'tail -n 20 /var/log/dovecot.log'
  h "Roundcube dir"; r ls -ld /usr/local/cwpsrv/var/services/roundcube
  h "Postfix config problems"; sh_ 'postconf -n >/dev/null && echo postconf-ok'
}
phpfpm() {
  h "Versions"; r ls -1 /opt/alt
  h "Services"; sh_ 'systemctl list-units "*php*fpm*" --no-legend'
  h "Per-user pool confs"; sh_ 'ls /opt/alt/php-fpm*/usr/etc/php-fpm.d/users 2>/dev/null | head -n 30'
  h "Config test"; sh_ 'for b in /opt/alt/php-fpm*/usr/sbin/php-fpm; do [ -x "$b" ] && "$b" -t; done'
}
cwpsrv() {
  h "cwpsrv"; sh_ 'systemctl is-active cwpsrv cwp-phpfpm'
  sh_ 'ss -ltnp | grep -E ":(2030|2031|2082|2083|2086|2087|2304)[ ]"'
  h "Logs"; r ls -t /usr/local/cwpsrv/logs
  sh_ 'tail -n 30 /usr/local/cwpsrv/logs/error_log'
  h "ionCube"; sh_ '/usr/local/cwp/php71/bin/php -m | grep -i ioncube'
}
perms() {
  h "Home dir ownership sample (should be user:user)"
  sh_ 'ls -ld /home/*/public_html | head -n 20'
  h "World-writable files in public_html (first 20)"
  sh_ 'find /home/*/public_html -xdev -type f -perm -0002 2>/dev/null | head -n 20'
  h "Available fixer (propose only)"; sh_ 'ls /scripts | grep -i perm'
}
disk() {
  h "Filesystems"; r df -h -x tmpfs -x devtmpfs; r df -i -x tmpfs -x devtmpfs
  h "Largest top-level dirs"; sh_ 'du -xsh /home /var /backup /usr/local /tmp 2>/dev/null | sort -rh'
  h "Biggest logs"; sh_ 'du -xah /var/log /usr/local/apache/logs /usr/local/apache/domlogs 2>/dev/null | sort -rh | head -n 15'
  h "Temp"; sh_ 'du -sh /home/tmp_bak /tmp /var/tmp 2>/dev/null'
}
mysql() {
  h "Service"; sh_ 'systemctl is-active mariadb mysqld; mysql --version'
  h "Connections / uptime"; sh_ 'mysqladmin status'
  h "Processlist (command column only)"; sh_ 'mysql -e "SELECT command, COUNT(*) n FROM information_schema.processlist GROUP BY command" 2>&1'
  h "Error log"; sh_ 'tail -n 30 /var/lib/mysql/*.err'
  h "Datadir space"; r df -h /var/lib/mysql
}

case "${1:-}" in
  backup|ssl|mail|phpfpm|cwpsrv|perms|disk|mysql) "$1" ;;
  all) for a in backup ssl mail phpfpm cwpsrv perms disk mysql; do "$a"; done ;;
  *) echo "usage: cwp-diagnose.sh <backup|ssl|mail|phpfpm|cwpsrv|perms|disk|mysql|all>" >&2; exit 2 ;;
esac
