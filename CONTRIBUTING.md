# Contributing

- Corrections from real CWP servers are the most valuable contribution. Include your CWP version (`/scripts/cwp_version`), OS and what you observed.
- One skill per folder under `skills/`, following the [Agent Skills](https://agentskills.io) format: `SKILL.md` with `name` (= folder) and `description`, body under 500 lines, details in `references/`.
- Every skill has `evals/<skill>/evals.json` with at least 3 cases.
- Scripts: bash, `shellcheck`-clean, dry run by default, `--apply` to change anything, read-only unless they must write.
- Never commit real hostnames, IPs, account names or keys. Use `example.com`, `alice`, `203.0.113.10`.
- Run `python3 scripts/validate.py` before opening a pull request. Use Conventional Commits and add a CHANGELOG line.
