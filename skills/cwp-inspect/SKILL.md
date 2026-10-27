---
name: cwp-inspect
description: Collects a read-only fact sheet (cwp-facts.md) from a CWP (Control Web Panel, CentOS Web Panel) server - OS, CWP version, cwpsrv PHP, ports, admin modules, immutability, root_cwp and postfix table structure, web stack, PHP-FPM, crons, /scripts, disk and RAM, restic/aws versions. Use when asked to inspect, audit, survey or diagnose a CWP server, or before another CWP skill needs to know what the server looks like. Never changes the server and never reads secrets or database rows.
license: MIT
compatibility: Run as root on a CWP server (tested on AlmaLinux 8). Needs bash, mysql client, ss, lsattr.
---

# cwp-inspect

Strictly read-only inspection. Produces `cwp-facts.md`, which other CWP skills read instead of guessing.

## Run it

Option A (you have a shell on the server):

```bash
bash scripts/cwp-inspect.sh --out ./cwp-facts.md
```

Option B (from a workstation; ask the user first, it connects to their server):

```bash
scp scripts/cwp-inspect.sh root@SERVER.example.com:/tmp/
ssh root@SERVER.example.com 'bash /tmp/cwp-inspect.sh --out /tmp/cwp-facts.md'
scp root@SERVER.example.com:/tmp/cwp-facts.md ./cwp-facts.md
```

Remove the two files from the server afterwards (only with the user's OK).

The script writes nowhere except the `--out` file. Re-running overwrites that file only.

## Read the facts

Sections: OS, CWP version, cwpsrv PHP, ports, admin modules (total / encoded / plain), `3rdparty.php` menu, user modules, immutability, `root_cwp` and `postfix` columns, web stack, PHP-FPM (`/opt/alt`), cron, `/scripts`, hooks, resources, backup tooling.

Interpretation notes (verified field notes, see `references/reading-facts.md`):

- cwpsrv PHP can be 8.3 although its path says `php71`. Read the "cwpsrv PHP" section; do not assume.
- Most admin modules are ionCube-encoded; "plain" ones are third-party or examples. Encoded detection is a heuristic.
- An `i` flag in lsattr on `htdocs/admin` means the tree is immutable; writing there needs `chattr -i` first (a change: ask).
- AWS CLI v1 in the facts means S3 errors from non-AWS providers can crash with `NoneType`; see the `cwp-troubleshoot` skill.

## Privacy rules

- Structure only: `SHOW COLUMNS`, never `SELECT` on data.
- Never read `/root/.my.cnf`, key files or mailboxes. The script redacts lines matching pass/secret/token/key/auth.
- The facts file describes a real server: do not commit it or paste it into public issues unreviewed; replace hostnames and IPs with example.com placeholders first.
- If asked to go further (read data, change settings), stop and ask the user.
