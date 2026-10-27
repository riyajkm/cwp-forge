# Verify per CWP version (user panel facts that are undocumented or from forums)

The official user-module page (updated 2020) covers only the three files. Everything else below is observed in community modules (for example pro-cms/cwp-git-deployer) or inferred. Check each on the target server before relying on it, and record the CWP version (`/scripts/cwp_version`) with the result.

| # | Claim | How to verify | If different |
|---|---|---|---|
| 1 | Logic file path `/usr/local/cwpsrv/var/services/user_files/modules/<name>.php` | `ls` it; drop a file that writes to a log; open `?module=<name>` | Older layouts used `htdocs/resources/client/modules`; use whatever existing modules use (`ls .../user_files/modules`) |
| 2 | Twig template `users/cwp_theme/<theme>/mod_<name>.html`, variables `mod`, `langmod`, `users` | Render `{{ mod|json_encode }}` temporarily | Follow an existing `mod_*.html` |
| 3 | Language file `users/cwp_lang/en/<name>.ini` | Missing file gives empty labels or an error | Check sibling modules |
| 4 | `$_SESSION['username']` is the account | Temporarily `error_log(json_encode(array_keys($_SESSION)))` in the module, read the php-fpm/cwpsrv log, remove it | Never fall back to request data. Stop and ask |
| 5 | CSRF secret: `tokenuser` (documented) or `token` | Same probe as #4 | Template fails closed (writes refused) until a secret key exists |
| 6 | The module file may call `session_start()` (git-deployer does) while admin modules must not | Do not call it; if `$_SESSION` is empty in your module, investigate instead | |
| 7 | AJAX is the same route with `&acc=` (POST) and the module echoes then exits | curl with a session cookie | |
| 8 | `menuConf.php` path `htdocs/resources/conf/user_panel/menuConf.php`, array `$menu[group]['modules'][key]` with keys `url,label,type,order,icon` | `grep -n "'url'" -m5 menuConf.php`; read an existing entry; mirror its exact key names and the `url` value format | Edit `menuconf.snippet` to match |
| 9 | Groups available: settings, file_management, domain, databases, emails_accounts, dns_functions, addons, reseller, servercast | `grep -o "^\s*'[a-z_]*' *=> *array" menuConf.php` | Pick an existing group |
| 10 | `type` values `url`, `modal`, `page`; `tabs` sub-arrays | Inspect existing entries | |
| 11 | Menu entry visible only if the package has the feature enabled (User Accounts > Features, Themes and Languages) | Create a test package with and without it | Some installs show nothing until `menu_left.html` is also edited (forum report); prefer fixing via menuConf first and test the direct URL |
| 12 | Direct URL `?module=<name>` works for users whose package lacks the feature | Test with such a user | If it works, add your own entitlement check (queue/DB) before doing anything |
| 13 | `menuConf.php` and the `original` theme are overwritten by CWP updates | Run an update on a test VM or `/root/.cwp_autoupdate.sh` | `fix-module` restores both; keep cron + autoupdate hook |
| 14 | `menuConf.php` is plain PHP (not ionCube) | `head -c 200 menuConf.php`, `php -l` | `fix-module` refuses to patch a file without `$menu` and lints the result before writing |
| 15 | Panel PHP uid (root or not) | `references/root-job-queue.md` section "Who is the panel uid?" | Set `PANEL_UID` |
| 16 | Dev toggle for uncompressed HTML/JS: `echo '{"compress_js":false,"compress_html":false}' > /usr/local/cwp/.conf/.devtools_config` | Reload the page and view source | Remove after development |
| 17 | A module that only `echo`s renders a bare white page; an empty module gives a 500 | Follow the template contract (set `$mod`, ship the `mod_*.html`) | |
| 18 | Whether `user_files/modules/<name>/` subdirectories are safe (core uses `cwp_framework/`) | Templates keep a single file to avoid this question | |

Report unverified items in your hand-off to the user instead of silently assuming.
