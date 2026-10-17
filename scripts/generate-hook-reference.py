#!/usr/bin/env python3
"""Generate docs/HOOKS.md, the hook reference, from hooks/hooks.json.

The registration tables (event, matcher, script, timeout) come from
hooks/hooks.json. The curated text — the one-line purpose of each hook script,
the role of files in hooks/ that hooks.json does not register, the hooks/lib
grouping and the wiring notes — lives in docs/hooks-purpose.json, taken from
each script's header comment.

Usage:
  python3 scripts/generate-hook-reference.py           # rewrite docs/HOOKS.md
  python3 scripts/generate-hook-reference.py --check   # exit 1 if docs/HOOKS.md is stale

Both modes fail when a registered hook has no purpose in docs/hooks-purpose.json,
when the data file describes a file that no longer exists, or when a file in
hooks/ is neither registered nor described. tests/docs/test-hook-reference.sh
runs --check.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
HOOKS_DIR = REPO_ROOT / "hooks"
HOOKS_JSON = HOOKS_DIR / "hooks.json"
DATA_JSON = REPO_ROOT / "docs" / "hooks-purpose.json"
OUT = REPO_ROOT / "docs" / "HOOKS.md"


def script_name(command: str) -> str:
    match = re.search(r"/hooks/([^\"'\s]+)", command)
    if not match:
        raise SystemExit(f"cannot parse hook command: {command}")
    return match.group(1)


def md_cell(text: str) -> str:
    return text.replace("|", "\\|")


def lib_entries() -> list[str]:
    names = []
    for path in sorted((HOOKS_DIR / "lib").iterdir()):
        if path.name.startswith(".") or path.name == "__pycache__":
            continue
        names.append(path.name + "/" if path.is_dir() else path.name)
    return names


def render() -> tuple[str, list[str]]:
    problems: list[str] = []
    hooks = json.loads(HOOKS_JSON.read_text(encoding="utf-8")).get("hooks", {})
    data = json.loads(DATA_JSON.read_text(encoding="utf-8"))
    purposes: dict[str, str] = data["purposes"]
    unregistered: dict[str, str] = data["unregistered"]
    event_notes: dict[str, str] = data.get("event_notes", {})

    registrations = []  # (event, position, matcher, script, timeout, flags)
    per_script: dict[str, list[str]] = {}
    for event, groups in hooks.items():
        position = 0
        for group in groups:
            matcher = group.get("matcher") or "*"
            for hook in group.get("hooks", []):
                position += 1
                name = script_name(hook.get("command", ""))
                flags = ["async"] if hook.get("async") else []
                registrations.append((event, position, matcher, name, hook.get("timeout", ""), flags))
                per_script.setdefault(name, [])
                where = f"{event} `{matcher}`"
                if where not in per_script[name]:
                    per_script[name].append(where)

    for name in sorted(per_script):
        if name not in purposes:
            problems.append(f"registered hook has no purpose in docs/hooks-purpose.json: {name}")
        if not (HOOKS_DIR / name).is_file():
            problems.append(f"hooks.json registers a missing file: hooks/{name}")
    for name in purposes:
        if name not in per_script:
            problems.append(f"docs/hooks-purpose.json has a purpose for a script hooks.json does not register: {name}")
    for name in unregistered:
        if not (HOOKS_DIR / name).exists():
            problems.append(f"docs/hooks-purpose.json describes a missing file: hooks/{name}")
    for path in sorted(HOOKS_DIR.iterdir()):
        if path.is_dir() or path.name.startswith("."):
            continue
        if path.name not in per_script and path.name not in unregistered:
            problems.append(f"hooks/{path.name} is neither registered in hooks.json nor described in docs/hooks-purpose.json")

    async_count = sum(1 for r in registrations if r[5])
    events = list(hooks.keys())
    lines: list[str] = []
    add = lines.append
    add("# Hook Reference")
    add("")
    add("> Generated from `hooks/hooks.json` and `docs/hooks-purpose.json` by `scripts/generate-hook-reference.py`.")
    add("> Do not edit by hand: change those files, then run `python3 scripts/generate-hook-reference.py`.")
    add("> `tests/docs/test-hook-reference.sh` fails when this file is stale.")
    add("")
    add(f"`hooks/hooks.json` registers **{len(registrations)} hook commands** backed by **{len(per_script)} scripts** "
        f"across {len(events)} events. {'No' if async_count == 0 else async_count} registration"
        f"{'' if async_count == 1 else 's'} {'is' if async_count == 1 else 'are'} async: the host waits for each hook "
        "up to its timeout (in seconds). The `#` column is the position in `hooks.json`; hosts may run the hooks that "
        "match one event in parallel, so do not rely on hook order.")
    add("")
    add("## How hooks are wired")
    add("")
    for bullet in data.get("wiring", []):
        add(f"- {bullet}")
    add("")
    add("## Registrations by event")
    for event in events:
        add("")
        add(f"### {event}")
        add("")
        if event in event_notes:
            add(event_notes[event])
            add("")
        add("| # | Matcher | Script | Timeout |")
        add("|---|---------|--------|---------|")
        for ev, position, matcher, name, timeout, flags in registrations:
            if ev == event:
                flag = f" ({', '.join(flags)})" if flags else ""
                add(f"| {position} | `{md_cell(matcher)}` | `{name}`{flag} | {timeout} |")
    add("")
    add("## Hook scripts")
    add("")
    add("| Script | Registered on | Purpose |")
    add("|--------|---------------|---------|")
    for name in sorted(per_script):
        where = "; ".join(md_cell(item) for item in per_script[name])
        add(f"| `{name}` | {where} | {md_cell(purposes.get(name, 'TODO: describe'))} |")
    add("")
    add("## Other files in hooks/")
    add("")
    add("These files are not registered in `hooks/hooks.json`.")
    add("")
    add("| File | Role |")
    add("|------|------|")
    for name in sorted(unregistered):
        add(f"| `{name}` | {md_cell(unregistered[name])} |")
    add("")
    add("## Shared libraries (hooks/lib/)")
    add("")
    add("Hooks source these helpers; none of them is registered as a hook. Each file's header comment describes it.")
    add("")
    entries = lib_entries()
    grouped: set[str] = set()
    for group in data.get("lib_groups", []):
        members = group["members"]
        present = [m for m in members if m in entries]
        for missing in (m for m in members if m not in entries):
            problems.append(f"docs/hooks-purpose.json lib_groups lists a missing hooks/lib entry: {missing}")
        grouped.update(present)
        if present:
            add(f"- **{group['title']}:** " + ", ".join(f"`{m}`" for m in present))
    other = [e for e in entries if e not in grouped]
    if other:
        add("- **Other:** " + ", ".join(f"`{m}`" for m in other))
    if data.get("lib_footer"):
        add("")
        add(data["lib_footer"])
    add("")
    return "\n".join(lines), problems


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate docs/HOOKS.md from hooks/hooks.json.")
    parser.add_argument("--check", action="store_true", help="fail if docs/HOOKS.md is out of date")
    args = parser.parse_args()

    content, problems = render()
    if problems:
        for problem in problems:
            print(f"ERROR: {problem}", file=sys.stderr)
        return 1
    if args.check:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != content:
            print("docs/HOOKS.md is out of date; run: python3 scripts/generate-hook-reference.py", file=sys.stderr)
            return 1
        print("docs/HOOKS.md is up to date")
        return 0
    OUT.write_text(content, encoding="utf-8")
    print(f"Wrote {OUT.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
