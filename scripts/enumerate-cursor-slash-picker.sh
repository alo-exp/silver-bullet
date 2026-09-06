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


def load_cursorignore(root: Path) -> list[str]:
    path = root / ".cursorignore"
    if not path.is_file():
        return []
    patterns: list[str] = []
    for raw in path.read_text(errors="ignore").splitlines():
        line = raw.strip()
        if line and not line.startswith("#"):
            patterns.append(line.lstrip("/"))
    return patterns


def is_cursorignored(root: Path, path: Path, patterns: list[str]) -> bool:
    try:
        rel = path.relative_to(root).as_posix()
    except ValueError:
        return False
    for pattern in patterns:
        if pattern.endswith("/"):
            if rel == pattern.rstrip("/") or rel.startswith(pattern):
                return True
        elif rel == pattern or rel.startswith(pattern + "/"):
            return True
    return False


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
    local_plugin = cursor_home / "plugins/local/silver-bullet"
    if local_plugin.is_dir() and not local_plugin.is_symlink():
        manifest = local_plugin / ".cursor-plugin" / "plugin.json"
        if manifest.is_file():
            return local_plugin
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
            route = f"/{name}" if name not in {"silver", "sb"} else "/sb"
            if ":" in path.name:
                bad_colon.append(f"{path.name}: colon-bearing command filename is not desktop-safe")
            elif name != path.stem or ":" in name:
                bad_colon.append(
                    f"{path.name}: command name {name!r} must match its kebab-case filename stem"
                )
            commands.append({"route": route, "name": name, "file": str(path.relative_to(root))})

    if skills_root and skills_root.is_dir():
        for skill_md in sorted(skills_root.glob("*/SKILL.md")):
            name = parse_frontmatter(skill_md).get("name", "").strip() or skill_md.parent.name
            route = f"/{name}" if name not in {"silver", "sb"} else "/sb"
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

    ignore_patterns = load_cursorignore(root)
    subagents: list[dict[str, str]] = []
    ignored: list[dict[str, str]] = []
    bad_colon: list[str] = []

    def add_skill_entry(skill_md: Path, surface: str) -> None:
        name = parse_frontmatter(skill_md).get("name", "").strip() or skill_md.parent.name
        route = f"/{name}" if name not in {"silver", "sb"} else "/sb"
        entry = {
            "route": route,
            "name": name,
            "dir": str(skill_md.parent.relative_to(root)),
            "surface": surface,
        }
        if is_cursorignored(root, skill_md, ignore_patterns) or is_cursorignored(root, skill_md.parent, ignore_patterns):
            ignored.append(entry)
            return
        subagents.append(entry)
        if name not in {"silver", "sb"} and not name.startswith("sb:"):
            bad_colon.append(f"{skill_md.parent.relative_to(root)}: name={name!r}")

    if skills_root and skills_root.is_dir():
        for skill_md in sorted(skills_root.glob("*/SKILL.md")):
            add_skill_entry(skill_md, "manifest.skills")

    seen: set[Path] = set()
    for surface, surface_root in [
        ("skills", root / "skills"),
        ("host-bundles/cursor", root / "host-bundles" / "cursor"),
        ("agents", root / "agents"),
        ("plugins/silver-bullet/skill-source", root / "plugins" / "silver-bullet" / "skill-source"),
        ("plugins/silver-bullet/agents", root / "plugins" / "silver-bullet" / "agents"),
        ("project .cursor/agents", root / ".cursor" / "agents"),
    ]:
        if not surface_root.is_dir():
            continue
        for skill_md in sorted(surface_root.glob("**/SKILL.md")):
            resolved = skill_md.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            add_skill_entry(skill_md, surface)

    return {
        "root": str(root),
        "manifest_skills": skills_path,
        "subagents": subagents,
        "ignored": ignored,
        "bad_colon": bad_colon,
        "ignore_patterns": ignore_patterns,
    }


def enumerate_global_custom_agents(root: Path) -> list[dict[str, str]]:
    if not root.is_dir():
        return []
    entries: list[dict[str, str]] = []
    for skill_md in sorted(root.glob("**/SKILL.md")):
        name = parse_frontmatter(skill_md).get("name", "").strip() or skill_md.parent.name
        if name.startswith("sb:") or name.startswith("silver-"):
            entries.append({"name": name, "file": str(skill_md.relative_to(root))})
    for path in sorted(root.glob("**/*")):
        if not path.is_file() or path.name == "SKILL.md":
            continue
        if path.suffix.lower() not in {".md", ".json", ".yaml", ".yml"}:
            continue
        text = path.read_text(errors="ignore")
        meta = parse_frontmatter(path)
        name = meta.get("name") or meta.get("title") or path.stem
        if name.startswith("sb:") or name.startswith("silver-") or "Silver Bullet" in text[:2000]:
            entries.append({"name": name, "file": str(path.relative_to(root))})
    return entries


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
    ws_ignored = workspace["ignored"]
    ws_bad_colon = workspace["bad_colon"]
    global_custom = enumerate_global_custom_agents(cursor_home / "agents")
    print()
    print("Workspace slash-picker exposure (dev checkout)")
    print(f"workspace={workspace['root']}")
    print(f"manifest.skills={workspace['manifest_skills']!r}")
    print(f".cursorignore patterns={workspace['ignore_patterns']!r}")
    print(f"workspace_subagents={len(ws_subagents)} ignored_workspace_entries={len(ws_ignored)}")
    print(f"workspace_bad_colon={len(ws_bad_colon)} global_custom_agents={len(global_custom)}")
    if workspace["manifest_skills"] or ws_subagents or ws_bad_colon or global_custom:
        print()
        print("WORKSPACE SUBAGENT/SKILL ENTRIES (must be zero):")
        for entry in ws_subagents[:12]:
            print(f"  {entry['route']}  ({entry['dir']} via {entry['surface']})")
        if len(ws_subagents) > 12:
            print(f"  ... +{len(ws_subagents) - 12} more")
        if ws_bad_colon:
            print("WORKSPACE COLON VIOLATIONS:")
            for item in ws_bad_colon[:12]:
                print(f"  - {item}")
            if len(ws_bad_colon) > 12:
                print(f"  ... +{len(ws_bad_colon) - 12} more")
        if global_custom:
            print("GLOBAL CUSTOM AGENT ENTRIES (must be zero for SB):")
            for entry in global_custom[:12]:
                print(f"  {entry['name']}  ({entry['file']})")
            if len(global_custom) > 12:
                print(f"  ... +{len(global_custom) - 12} more")
        print()
        print("RESULT: FAIL — workspace/global surfaces still expose SB skills in / picker")
        raise SystemExit(1)
    print("RESULT: OK — workspace/global surfaces do not expose SB skills in / picker")
PY
