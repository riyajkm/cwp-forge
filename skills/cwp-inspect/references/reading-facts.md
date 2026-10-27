# Reading cwp-facts.md

Verified on CWP Pro, AlmaLinux 8.10 (field notes).

## Ground truth
- cwpsrv PHP binary: `/usr/local/cwp/php71/bin/php` (may be PHP 8.3; folder name is historical). Pools run as root, env has no HOME.
- Ports: admin 2030/2031, user 2082/2083, API 2304 (https), 2086/2087 also cwpsrv, 2302 local.
- `root_cwp` tables: backups domains nameserver notifications packages settings subdomains user.
- Account databases: `<user>_<name>`. Mail: `/var/vmail/<domain>/<mailbox>`, accounts in DB `postfix`. DNS `/var/named/*.db`. SSL `/etc/pki/tls/certs` and `/etc/pki/tls/private`.
- Apache vhosts `/usr/local/apache/conf.d/vhosts/`; nginx `/etc/nginx/conf.d/vhosts/`.
- `/usr/local/cwp/.conf/`: cwp.ini, settings.conf, web_servers.conf, mysql_user_prefix.conf, backup_manager.conf.
- Admin module AJAX goes through `loader_ajax.php?ajax=<name>&acc=<action>`; the menu file is `resources/admin/include/3rdparty.php`.

## Unverified
- Hooks config location: `include/hooks.php` is encoded; the script only reports whether candidate paths exist.
- Encoded-module detection is a header grep, not proof.
