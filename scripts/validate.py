#!/usr/bin/env python3
"""Validate cwp-forge: skill frontmatter (agentskills.io rules), agents, commands, evals and manifests.

Exit 1 on any error. Run from the repo root: python3 scripts/validate.py
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
errors: list[str] = []


def frontmatter(path: pathlib.Path) -> dict:
    text = path.read_text(encoding="utf-8")
    if "\r\n" in text:
        errors.append(f"{path}: CRLF line endings (use LF)")
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        errors.append(f"{path}: missing YAML frontmatter")
        return {}
    data = {}
    for line in m.group(1).splitlines():
        if re.match(r"^[A-Za-z][\w-]*:", line):
            k, v = line.split(":", 1)
            data[k.strip()] = v.strip().strip('"').strip("'")
    data["_body_lines"] = text[m.end():].count("\n")
    return data


skills = sorted(p for p in (ROOT / "skills").iterdir() if p.is_dir())
for d in skills:
    f = d / "SKILL.md"
    if not f.exists():
        errors.append(f"{d}: missing SKILL.md")
        continue
    fm = frontmatter(f)
    name, desc = fm.get("name", ""), fm.get("description", "")
    if name != d.name:
        errors.append(f"{f}: name '{name}' must equal folder '{d.name}'")
    if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", name or "x-") or len(name) > 64:
        errors.append(f"{f}: name must be lowercase-hyphenated, <= 64 chars")
    if not desc or len(desc) > 1024:
        errors.append(f"{f}: description required, <= 1024 chars (got {len(desc)})")
    if fm.get("_body_lines", 0) > 500:
        errors.append(f"{f}: body over 500 lines ({fm['_body_lines']}); move detail to references/")
    ev = ROOT / "evals" / d.name / "evals.json"
    if not ev.exists():
        errors.append(f"{d.name}: missing evals/{d.name}/evals.json")
    else:
        try:
            cases = json.loads(ev.read_text(encoding="utf-8"))
            # accept {"cases": [...]}, skill-creator {"evals": [...]} or a bare list
            n = len(cases if isinstance(cases, list) else (cases.get("cases") or cases.get("evals") or []))
            if n < 3:
                errors.append(f"{ev}: needs >= 3 cases (got {n})")
        except json.JSONDecodeError as e:
            errors.append(f"{ev}: invalid JSON ({e})")

for kind in ("agents", "commands"):
    for f in sorted((ROOT / kind).glob("*.md")):
        fm = frontmatter(f)
        if kind == "agents" and (fm.get("name") != f.stem or not fm.get("description")):
            errors.append(f"{f}: agent needs name (= file name) and description")
        if kind == "commands" and not fm.get("description"):
            errors.append(f"{f}: command needs a description")

for mf in (ROOT / ".claude-plugin" / "plugin.json", ROOT / ".claude-plugin" / "marketplace.json"):
    try:
        json.loads(mf.read_text(encoding="utf-8"))
    except Exception as e:  # noqa: BLE001
        errors.append(f"{mf}: {e}")

private = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")
for f in ROOT.rglob("*"):
    if f.is_file() and ".git" not in f.parts and f.suffix in {".md", ".sh", ".php", ".json", ".html", ".py", ".ini"}:
        for ip in private.findall(f.read_text(encoding="utf-8", errors="ignore")):
            if not ip.startswith(("127.", "0.", "10.", "192.168.", "203.0.113.", "198.51.100.", "192.0.2.")) and ip not in {"1.2.3.4"}:
                errors.append(f"{f}: real-looking IP address {ip} (use documentation ranges like 203.0.113.10)")

print(f"skills: {len(skills)}  agents: {len(list((ROOT / 'agents').glob('*.md')))}  commands: {len(list((ROOT / 'commands').glob('*.md')))}")
if errors:
    print("\n".join(f"ERROR {e}" for e in errors))
    sys.exit(1)
print("OK")
