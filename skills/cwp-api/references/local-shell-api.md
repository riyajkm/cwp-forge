# On the server: /scripts/cwp_api

When you are already root on the CWP server you do not need the HTTP API or a key for these admin actions. Source: https://wiki.centos-webpanel.com/cwp-admin-api

```bash
/scripts/cwp_api <group> <function> [args]
```

| Group | Functions |
|---|---|
| account | `remove_user U`, `suspend_user U`, `unsuspend_user U`, `unsuspend_bandwidth U`, `reset_bandwidth U`, `fix_perms U`, `list_domains U`, `update_diskquota_all`, `update_limits_all`, `mail_fix_permissions`, `update_policyd_all`, `rebuild_etc_named_conf`, `rebuild_var_named_all`, `rebuild_var_named U DOMAIN` |
| webservers | `rebuild_all`, `rebuild_user U`, `restart`, `reload` |
| apps | `install_softaculous`, `remove_softaculous`, `install_sitepad`, `remove_sitepad` |

## Differences from the REST API

- No account creation, package, mail, FTP or MySQL functions here: use the REST API (call it against the server's own IP with an IP-restricted key) or the panel.
- Suspend, unsuspend and remove exist and are the quickest from a root script.
- Whether `/scripts/cwp_api` triggers action hooks (`account_suspend`, ...) is [U]. Test with a hook that writes a file.
- For web server work prefer `cwp_api webservers reload` and `/scripts/restart_httpd` over raw `systemctl`. [U: advice inferred from the wiki]

## Other helpers worth knowing

`/scripts/list_users`, `list_domains`, `list_subdomains`, `whoowns DOMAIN`, `user_backup USER`, `cwp_version`, `check_api`, `install_api`, `add_alert TYPE "text" [LOGFILE]`. Usage `sh /scripts/NAME`. See the cwp-hooks-automation skill for the longer list.

## Safe use from automation

- Quote all input; usernames are lower-case alphanumerics, validate before passing.
- Print the command first (dry-run); require an explicit apply flag for suspend and remove.
- Log what was done with a timestamp; `/var/log/cwp/cwp_api.log` only covers REST calls.
