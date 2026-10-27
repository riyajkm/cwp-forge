# README structure for CWP users

Readers are hosting admins in a hurry. Lead with the outcome, then the 30-second install, then trust.

1. **Title + one-line promise** ("Per-account backups to S3 from inside CWP").
2. **Badges**: CI, latest release, license, "tested on CWP x.y".
3. **Screenshot or GIF** of the admin page (redact hostnames, IPs, accounts; use example.com and alice).
4. **What it does / what it does not do** (3 to 6 bullets each). Say plainly what it changes on the server.
5. **Requirements / compatibility table**: CWP version, OS (AlmaLinux 8, Rocky 8), cwpsrv PHP, other tools. Mark each cell tested / expected / untested.
6. **Install**: pinned to a release tag.
   ```bash
   curl -fsSLO https://github.com/OWNER/cwp-mymodule/releases/download/vX.Y.Z/cwp-mymodule-X.Y.Z.tar.gz
   sha256sum -c <(curl -fsSL .../SHA256SUMS | grep tar.gz)
   tar xzf cwp-mymodule-X.Y.Z.tar.gz && cd cwp-mymodule-X.Y.Z
   sudo ./install.sh --dry-run && sudo ./install.sh
   ```
   Never `curl | bash`.
7. **First run**: where the menu item appears (Developer Menu), the first screen, a minimal config.
8. **Upgrade** (re-run the installer; config kept) and **Uninstall** (`uninstall.sh`, `--purge`).
9. **After a CWP update** (menu vanished?): `sudo ./install.sh --heal`, or wait for the daily self-heal.
10. **Security model**: privilege boundary, what runs as root, what is logged, how secrets are stored, link to SECURITY.md.
11. **Troubleshooting**: 5 to 10 real symptoms with the log path and fix.
12. **Docs / Contributing / License / Changelog links**.
13. **Support**: where to file issues; what to include (versions, redacted logs); not a replacement for CWP support.

Style: short sentences, copy-pasteable commands, no marketing adjectives, no claims you cannot test, no real server data.
