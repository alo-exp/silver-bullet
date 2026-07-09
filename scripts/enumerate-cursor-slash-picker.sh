#!/usr/bin/env bash
# Enumerate Silver Bullet slash-picker entries Cursor would register from a plugin surface.
#
# Cursor plugin.json semantics (verified empirically):
#   - "commands": "./commands"  → slash commands from commands/*.md (filename stem = route)
#   - "skills": "./agents/cursor" → subagent entries from agents/cursor/*/SKILL.md (manifest)
#   - agents/cursor on disk → same subagent entries via auto-discovery (no manifest needed)
#
# Acceptance: / picker shows commands ONLY — no agents/cursor directory on surface.
#
# Usage:
#   bash scripts/enumerate-cursor-slash-picker.sh [--cursor-home PATH] [--surface PATH] [--workspace PATH]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CURSOR_HOME="${CURSOR_HOME:-${HOME}/.cursor}"
SURFACE=""
WORKSPACE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cursor-home)
      CURSOR_HOME="${2:-}"
      shift 2
      ;;
    --surface)
      SURFACE="${2:-}"
      shift 2
      ;;
    --workspace)
      WORKSPACE="${2:-}"
      shift 2
      ;;
    -h|--help)
      sed -n '1,14p' "$0"
      exit 0
      ;;
    *)
      printf 'enumerate-cursor-slash-picker: unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

python3 - "$CURSOR_HOME" "$REPO_ROOT" "$SURFACE" "$WORKSPACE" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

cursor_home = Path(sys.argv[1])
repo_root = Path(sys.argv[2])
surface_arg = sys.argv[3]
workspace_arg = sys.argv[4]


def parse_frontmatter(path: Path) -> dict[str, str]:
    text = path.read_text(errors="ignore")
    match = re.match(r"^---\n(.*?)\n---", text, re.S)
    if not match:
        return {}
    meta: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        meta[key.strip()] = value.strip().strip('"')
    return meta


def default_surface() -> Path | None:
    link = cursor_home / "plugins/cache/alo-labs/silver-bullet/current"
    if link.exists():
        return link.resolve()
    backend = cursor_home / "plugins/cache/alo-labs-agent-plugins/silver-bullet"
    if backend.is_dir():
        for child in sorted(backend.iterdir(), reverse=True):
            if child.is_dir() and re.fullmatch(r"[0-9a-f]{40}", child.name):
                return child
    return None


def enumerate_surface(root: Path) -> dict[str, object]:
    manifest_path = root / ".cursor-plugin" / "plugin.json"
    manifest: dict[str, object] = {}
    if manifest_path.is_file():
        try:
            manifest = json.loads(manifest_path.read_text())
        except Exception:
            pass

    commands_dir = root / "commands"
    agents_cursor = root / "agents" / "cursor"
    skills_path = manifest.get("skills")
    skills_root = root / str(skills_path).removeprefix("./") if skills_path else None
    if skills_root is None and agents_cursor.is_dir():
        skills_root = agents_cursor

    commands: list[dict[str, str]] = []
    subagents: list[dict[str, str]] = []
    bad_colon: list[str] = []

    if manifest.get("commands") and commands_dir.is_dir():
        for path in sorted(commands_dir.glob("*.md")):
            name = parse_frontmatter(path).get("name", "").strip() or path.stem
            route = f"/{name}" if name != "silver" else "/silver"
            if name != "silver" and not name.startswith("silver:"):
                bad_colon.append(f"{path.name}: name={name!r}")
            elif path.stem != name:
                bad_colon.append(f"{path.name}: stem {path.stem!r} != name {name!r}")
            commands.append({"route": route, "name": name, "file": str(path.relative_to(root))})

    if skills_root and skills_root.is_dir():
        for skill_md in sorted(skills_root.glob("*/SKILL.md")):
            name = parse_frontmatter(skill_md).get("name", "").strip() or skill_md.parent.name
            route = f"/{name}" if name != "silver" else "/silver"
            subagents.append(
                {
                    "route": route,
                    "name": name,
                    "dir": str(skill_md.parent.relative_to(root)),
                }
            )

    overlap = sorted({c["name"] for c in commands} & {s["name"] for s in subagents})
    agents_cursor_present = agents_cursor.is_dir() and any(agents_cursor.glob("*/SKILL.md"))
    return {
        "root": str(root),
        "manifest_skills": skills_path,
        "agents_cursor_present": agents_cursor_present,
        "commands": commands,
        "subagents": subagents,
        "overlap": overlap,
        "bad_colon": bad_colon,
    }


def enumerate_workspace(root: Path) -> dict[str, object]:
    manifest_path = root / ".cursor-plugin" / "plugin.json"
    manifest: dict[str, object] = {}
    if manifest_path.is_file():
        try:
            manifest = json.loads(manifest_path.read_text())
        except Exception:
            pass

    skills_path = manifest.get("skills")
    skills_root: Path | None = None
    if skills_path:
        skills_root = root / str(skills_path).removeprefix("./")

    subagents: list[dict[str, str]] = []
    if skills_root and skills_root.is_dir():
        for skill_md in sorted(skills_root.glob("*/SKILL.md")):
            name = parse_frontmatter(skill_md).get("name", "").strip() or skill_md.parent.name
            route = f"/{name}" if name != "silver" else "/silver"
            subagents.append(
                {
                    "route": route,
                    "name": name,
                    "dir": str(skill_md.parent.relative_to(root)),
                }
            )

    return {
        "root": str(root),
        "manifest_skills": skills_path,
        "subagents": subagents,
    }


root = Path(surface_arg) if surface_arg else default_surface()
if root is None or not root.is_dir():
    print("ERROR: no Cursor Silver Bullet plugin surface found", file=sys.stderr)
    raise SystemExit(1)

result = enumerate_surface(root)
commands = result["commands"]
subagents = result["subagents"]
overlap = result["overlap"]
bad_colon = result["bad_colon"]

print("Silver Bullet Cursor slash-picker enumeration")
print(f"surface={result['root']}")
print(f"manifest.skills={result['manifest_skills']!r}")
print(f"agents/cursor on disk={result['agents_cursor_present']}")
print(f"commands={len(commands)} subagents={len(subagents)} overlap={len(overlap)}")
print()

if bad_colon:
    print("COLON/FILENAME VIOLATIONS:")
    for item in bad_colon:
        print(f"  - {item}")
    print()

if overlap:
    print("COMMAND+SUBAGENT OVERLAP:")
    for name in overlap:
        print(f"  - {name}")
    print()

if subagents:
    print("SUBAGENT ENTRIES (must be zero for / picker):")
    for entry in subagents[:12]:
        print(f"  {entry['route']}  ({entry['dir']})")
    if len(subagents) > 12:
        print(f"  ... +{len(subagents) - 12} more")
    print()

print("COMMAND ENTRIES:")
for entry in commands:
    print(f"  {entry['route']}  ({entry['file']})")

failures = 0
if result["manifest_skills"]:
    failures += 1
if result["agents_cursor_present"]:
    failures += 1
if subagents:
    failures += 1
if overlap:
    failures += 1
if bad_colon:
    failures += 1

print()
if failures:
    print(f"RESULT: FAIL — {failures} picker policy violation(s)")
    raise SystemExit(1)

print("RESULT: OK — commands-only slash picker with colon routes")

workspace_root = Path(workspace_arg) if workspace_arg else repo_root
if workspace_root.is_dir():
    workspace = enumerate_workspace(workspace_root)
    ws_subagents = workspace["subagents"]
    print()
    print("Workspace slash-picker exposure (dev checkout)")
    print(f"workspace={workspace['root']}")
    print(f"manifest.skills={workspace['manifest_skills']!r}")
    print(f"workspace_subagents={len(ws_subagents)}")
    if workspace["manifest_skills"] or ws_subagents:
        print()
        print("WORKSPACE SUBAGENT/SKILL ENTRIES (must be zero):")
        for entry in ws_subagents[:12]:
            print(f"  {entry['route']}  ({entry['dir']})")
        if len(ws_subagents) > 12:
            print(f"  ... +{len(ws_subagents) - 12} more")
        print()
        print("RESULT: FAIL — workspace manifest still exposes skills in / picker")
        raise SystemExit(1)
    print("RESULT: OK — workspace manifest does not expose skills in / picker")
PY
