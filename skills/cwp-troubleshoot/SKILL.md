---
name: cwp-troubleshoot
description: Diagnoses common CWP (Control Web Panel, CentOS Web Panel) server problems with decision trees and exact read-only commands, then proposes known fixes for confirmation. Covers NEW Backup and S3 failures (NoneType error, SignatureDoesNotMatch, stale backup running flag, /home/tmp_bak), AutoSSL/Let's Encrypt, postfix/dovecot/roundcube mail, PHP-FPM selector rebuild, cwpsrv not loading, permissions, disk full and MySQL. Use when a CWP server misbehaves or the user says diagnose, broken, error, not working.
license: MIT
compatibility: Run as root on a CWP server (tested on AlmaLinux 8). Needs bash.
---

# cwp-troubleshoot

Diagnose first, read-only. Fixes are only proposed; run one only after the user confirms and you have said what it changes.

Start: `bash scripts/cwp-diagnose.sh <backup|ssl|mail|phpfpm|cwpsrv|perms|disk|mysql|all>` (read-only, output redacted). Read `cwp-facts.md` from the `cwp-inspect` skill if it exists.

Tags: [V] verified on a live server, [D] from CWP docs/wiki, not live-verified, [U] unverified, check on your version.

## Backup / S3 (NEW Backup beta)

1. Which error?
   - `argument of type 'NoneType' is not iterable` [V]: AWS CLI v1 (old CWP default 1.18) crashes when the S3 error has an empty `<Message>` (seen with Contabo). Confirm with `aws --version` (`aws-cli/1`). Proposed fix: install AWS CLI v2. Even v2 crashes on some calls (e.g. `NoSuchLifecycleConfiguration`), so read the code with `aws ... --debug 2>&1 | grep -i '<Code>'`.
   - `SignatureDoesNotMatch` from the panel while the same key works in the shell [V]: the panel saved the credentials wrongly. Test in the shell: `aws s3 ls s3://BUCKET --endpoint-url https://ENDPOINT` (path-style; bucket NOT in the endpoint). If the shell works, propose re-entering the keys in the panel and re-testing. Never print the keys.
   - Restore does not list S3 backups [V]: beta limitation; restore from the object store in the shell.
2. "Backup running" never clears [V]: run `pgrep -af 'backup|restic|aws s3'`. No process means the flag is stale. Where the panel stores it: `/usr/local/cwp/.conf/backup_manager.conf` or `root_cwp.backups` (use `SHOW COLUMNS` only) [U exact field]. Propose clearing only after confirming nothing runs.
3. Disk fills during backup [V]: temp files in `/home/tmp_bak`; `du -sh /home/tmp_bak`. Remove leftovers only with no backup running and after confirmation.
4. S3 limits [V]: use multipart for large objects (single PUT over ~200 MB reported blocked); Contabo-type defaults ~10 MB/s and 250 req/s.

## AutoSSL / Let's Encrypt [D]

1. `tail -n 50 /var/log/cwp/autossl.log`.
2. Challenge dir present and writable: `/usr/local/apache/autossl_tmp/.well-known/acme-challenge/`. Helper scripts to propose, not run unasked: `/scripts/autossl_fix_tmp_path`, `autossl_reload`, `install_acme`, `autossl_generate_apache_conf`.
3. DNS points here? `dig +short A example.com`; port 80 reachable: `ss -ltn | grep ':80 '`.
4. Expiry: `openssl x509 -noout -enddate -in /etc/pki/tls/certs/<file>`.

## Mail [D]

1. `systemctl is-active postfix dovecot`; `postqueue -p | tail -n 3`; `tail -n 50 /var/log/maillog`.
2. Big queue: find the dominant reason in maillog (deferred, relay denied, blocked). `postsuper -d ALL deferred` destroys queued mail: only with explicit confirmation.
3. Login fails: `/var/log/dovecot*.log`. Mail accounts live in DB `postfix` (structure only).
4. Roundcube is at `/usr/local/cwpsrv/var/services/roundcube`; failed updates are often the cwpsrv PHP version.

## PHP-FPM selector / user conf

1. Versions in `/opt/alt`; per-user pool conf `/opt/alt/php-fpm<VER>/usr/etc/php-fpm.d/users/<USER>.conf` [D].
2. Config test: `/opt/alt/php-fpm<VER>/usr/sbin/php-fpm -t`.
3. Proposed fix: `/scripts/phpfpm_rebuild_user_conf` (rewrites pool confs; confirm), then reload the FPM service.
4. For the panel's own user confs: `/scripts/cwpsrv_rebuild_user_conf`.

## cwpsrv not loading

1. `systemctl is-active cwpsrv cwp-phpfpm`; `ss -ltnp | grep -E ':(2030|2031|2082|2083)'` [V ports].
2. `tail -n 30 /usr/local/cwpsrv/logs/error_log`.
3. Missing or wrong ionCube loader is a known cause [D]; `/scripts/update_ioncube` exists.
4. Proposed: `/scripts/reload_cwpsrv`, then `/scripts/restart_cwpsrv` (restart drops panel sessions). A third-party admin module with a PHP error can break pages: check `3rdparty.php` entries and `php -l` the module with `/usr/local/cwp/php71/bin/php`.
5. cwpsrv PHP is a bundled build tied to encoded core: do not upgrade it [D].

## Permissions

1. `ls -ld /home/<user>/public_html` should belong to that user; `find /home/<user>/public_html -xdev -perm -0002` lists world-writable files.
2. Find CWP's fixer: `ls /scripts | grep -i perm` (a `fix_acc_perm`-style tool; exact name and arguments [U], check on the server). Propose it per user, never for all accounts at once.

## Disk full

1. `df -h` and `df -i` (inodes). 2. `du -xsh /home /var /backup /usr/local | sort -rh`. 3. Logs: `/var/log`, `/usr/local/apache/domlogs`. 4. `/home/tmp_bak`. Show sizes and propose per path; never delete user data.

## MySQL

1. `systemctl is-active mariadb`; `mysqladmin status`. 2. Tail the error log in `/var/lib/mysql/*.err`. 3. `df -h /var/lib/mysql`. 4. Lost root password: `/scripts/mysql_pwd_reset` exists [V name]; it changes credentials, so confirm first and never show the new password in shared logs.

More S3/AWS detail: `references/s3-aws-cli.md`.
