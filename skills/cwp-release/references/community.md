# CWP developer programme and forum announcement

What is verified, and what is not.

## Where CWP developers publish
- Official developer docs: https://docs.control-webpanel.com/docs/developer/ (API pages are detailed; custom-module pages are short and old). Read them for the supported module layout before you announce.
- Community forum: https://forum.centos-webpanel.com/ with a section for new modules (`/new-modules/`). Module authors announce and support their work there.
- Developer programme / listing: the process and any requirements are set by the CWP team and may change. **Check the docs site and ask in the forum or via CWP support before promising a listing.** Do not state that the module is "approved", "official" or "certified" unless CWP told you so in writing.

## Before posting
- [ ] A tagged release exists with a CHANGELOG and checksums.
- [ ] README tested compatibility matrix is honest (versions you actually ran).
- [ ] SECURITY.md exists and the security review gate passed.
- [ ] Screenshots redacted (example.com, alice).
- [ ] Support channel decided (GitHub Issues), so the thread stays short.

## Post structure (new-modules section)
Title: `[Module] <name> <version> - <one-line what it does>`
Body:
1. What it does (2 to 3 sentences) and a screenshot.
2. Tested on: CWP version, OS, PHP.
3. Install one-liner pointing to the release (checksum shown), link to repo.
4. What it changes on the server (files, menu, cron) and how to uninstall.
5. Known limits and what is next.
6. Licence and how to report bugs/security issues (GitHub, not the thread).

## Etiquette
- One announcement per release that matters; update the same thread with a short note for point releases.
- Search first; if a similar module exists, say how yours differs and credit it.
- Be factual; no comparisons that disparage CWP or other authors; no sales pitch for paid add-ons inside a free-module thread unless the rules of the section allow it.
- Answer reports with version and logs requested; move bugs to Issues; close the loop in the thread when fixed.
- Never ask users to post credentials, keys or full hostnames; remind them to redact.
- Disclose security fixes in release notes after users had time to update; use private reporting for new reports.
- Respect forum rules and moderators; if a post is moved or removed, ask politely, do not repost.
