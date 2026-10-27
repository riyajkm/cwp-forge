# /scripts helpers

Source: https://wiki.centos-webpanel.com/cwp-scripts and https://wiki.centos-webpanel.com/cwp-admin-api [V]. Usage is `sh /scripts/NAME [args]`. There are about 97 helpers on a current server [V field]; `ls /scripts` is the truth for your version. Arguments are mostly undocumented: read the script header (when not encoded) or test on a lab VM.

## Accounts and info

| Script | Use |
|---|---|
| `list_users` | list accounts (same as `/usr/local/cwpsrv/htdocs/resources/scripts/list_users` [F]) |
| `list_domains`, `list_subdomains` | domains/subdomains |
| `whoowns DOMAIN` | which account owns a domain |
| `user_backup USER` | back up one account |
| `cwp_version` | installed panel version (log it when self-healing) |
| `ulimit_user_check` | per-user limits check |

## Panel and updates

| Script | Use |
|---|---|
| `restart_cwpsrv`, `reload_cwpsrv` | panel web server (prefer reload) |
| `cwpsrv_rebuild_user_conf` | rebuild cwpsrv user config |
| `update_cwp` | run a CWP update (triggers `/root/.cwp_autoupdate.sh` afterwards [V wiki]) |
| `update_ioncube` | fix the ionCube loader |
| `add_alert TYPE "text" [LOGFILE]` | panel notification; TYPE `alert-danger|success|info|warning|dismissable`; LOGFILE adds a "Check Detailed Info" button |
| `check_api`, `install_api` | API service checks/install |

## Web and PHP

| Script | Use |
|---|---|
| `restart_httpd` | Apache |
| `phpfpm_rebuild_user_conf` | rebuild per-user PHP-FPM pool config |
| `varnish_clear_cache` | Varnish purge |
| `open_basedir-suphp`, `php_big_file_upload` | PHP limit helpers |
| `/scripts/cwp_api webservers rebuild_all` / `rebuild_user U` / `restart` / `reload` | vhost rebuild and reload; log `/var/log/cwp/webservers.log`; a vhost renamed `.disabled` means a bad config |

Never hand-edit generated vhosts; use templates then `rebuild_*`.

## SSL, DNS, mail, DB

`install_acme`, `autossl_reload`, `autossl_generate_apache_conf`, `autossl_fix_tmp_path`, `generate_hostname_ssl`, `mail_vmail_import`, `mail_rebuild_sni_certs`, `mysql_pwd_reset`, `mysql_fix_myisam_tables`, `/scripts/cwp_api account rebuild_etc_named_conf`, `rebuild_var_named_all`, `rebuild_var_named U DOMAIN`.

## Misc

`bandwidth_run`, `chroot_add`, `chroot_remove`, `softaculous_fix_update`, `/scripts/cwp_api account fix_perms U`, `update_diskquota_all`, `update_limits_all`, `mail_fix_permissions`, `update_policyd_all`, `unsuspend_bandwidth U`, `reset_bandwidth U`, `suspend_user U`, `unsuspend_user U`, `remove_user U`.

## Rules for calling them from automation

- Quote and validate arguments; never build a command string from event data.
- Prefer a CWP script over raw `systemctl` when one exists [U advice].
- Treat `remove_user`, `mysql_pwd_reset`, `chroot_*` as destructive: dry-run print first, explicit apply.
- Capture output to a log; scripts may print HTML-ish or progress text.
- Some scripts take long (rebuilds): run them detached with `timeout`, behind a lock.

## Key paths

| Thing | Path |
|---|---|
| CWP conf | `/usr/local/cwp/.conf/` (`cwp.ini`, `settings.conf`, `web_servers.conf`, `api_key.conf`, `api_allowed.conf`, `.security_advisor.conf`, `.devtools_config`) |
| Logs | `/var/log/cwp/` (`cwp_api.log`, `webservers.log`, `autossl.log`), `/var/log/cwp_client_login.log`, `/usr/local/cwpsrv/logs/`, `/var/log/cron`, `/var/log/maillog` |
| Panel PHP | `/usr/local/cwp/php71/bin/php` (modern PHP despite the name), pools `/usr/local/cwp/php71/etc/cwpsrv.conf` and `php-fpm.d/cwpsvc.conf` [V field] |
| Reload cwpsrv PHP | `service cwp-phpfpm reload` |
| Vhosts | `/usr/local/apache/conf.d/vhosts/`, `/etc/nginx/conf.d/vhosts/` |
| Panel DB | MariaDB `root_cwp` (tables `user`, `domains`, `subdomains`, `packages`, `settings`, `backups`, `notifications`, `nameserver` [V field]); prefer API or scripts over SQL writes |
