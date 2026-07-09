#!/usr/bin/env bash
# Report slash-picker duplicate risk for Silver Bullet Cursor plugin surfaces.
#
# Checks install cache, backend marketplace cache, and active gitPath checkout for:
#   - command name overlap with agents/cursor skill names
#   - logical route overlap between commands/ and canonical skills/ (hyphen dirs)
#
# Usage:
#   bash scripts/diagnose-cursor-picker-duplicates.sh [--cursor-home PATH] [--all-gitpaths]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CURSOR_HOME="${CURSOR_HOME:-${HOME}/.cursor}"
ALL_GITPATHS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cursor-home)
      CURSOR_HOME="${2:-}"
      shift 2
      ;;
    --all-gitpaths)
      ALL_GITPATHS=1
      shift
      ;;
    -h|--help)
      sed -n '1,14p' "$0"
      exit 0
      ;;
    *)
      printf 'diagnose-cursor-picker-duplicates: unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

python3 - "$CURSOR_HOME" "$REPO_ROOT" "$ALL_GITPATHS" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

cursor_home = Path(sys.argv[1])
repo_root = Path(sys.argv[2])
all_gitpaths = sys.argv[3] == "1"


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


def logical_route(name: str) -> str | None:
    if name == "silver":
        return "silver"
    if name.startswith("silver:"):
        return name
    if name.startswith("silver-"):
        return "silver:" + name.removeprefix("silver-")
    return None


def command_routes(root: Path) -> set[str]:
    routes: set[str] = set()
    commands = root / "commands"
    if not commands.is_dir():
        return routes
    for path in sorted(commands.glob("*.md")):
        name = parse_frontmatter(path).get("name", "").strip()
        if name:
            routes.add(name)
    return routes


def agent_skill_routes(root: Path) -> set[str]:
    routes: set[str] = set()
    agents = root / "agents" / "cursor"
    if not agents.is_dir():
        return routes
    for skill_md in sorted(agents.glob("*/SKILL.md")):
        name = parse_frontmatter(skill_md).get("name", "").strip()
        if name:
            routes.add(name)
    return routes


def canonical_skill_routes(root: Path) -> set[str]:
    routes: set[str] = set()
    skills = root / "skills"
    if not skills.is_dir():
        return routes
    for skill_md in sorted(skills.glob("*/SKILL.md")):
        meta = parse_frontmatter(skill_md)
        name = meta.get("name", skill_md.parent.name).strip()
        route = logical_route(name) or logical_route(skill_md.parent.name)
        if route:
            routes.add(route)
    return routes


def analyze_surface(label: str, root: Path) -> dict[str, object]:
    if not root.is_dir():
        return {
            "label": label,
            "path": str(root),
            "missing": True,
            "cmd_agent_overlap": [],
            "cmd_skills_overlap": [],
        }
    cmd = command_routes(root)
    agent = agent_skill_routes(root)
    skills = canonical_skill_routes(root)
    cmd_agent = sorted(cmd & agent)
    cmd_skills = sorted(cmd & skills)
    return {
        "label": label,
        "path": str(root),
        "missing": False,
        "commands": len(cmd),
        "agents": len(agent),
        "skills_dirs": len(list((root / "skills").glob("*/SKILL.md"))) if (root / "skills").is_dir() else 0,
        "cmd_agent_overlap": cmd_agent,
        "cmd_skills_overlap": cmd_skills,
    }


def discover_roots(cursor_home: Path) -> list[tuple[str, Path]]:
    roots: list[tuple[str, Path]] = []
    install_link = cursor_home / "plugins/cache/alo-labs/silver-bullet/current"
    if install_link.exists():
        roots.append(("install-cache", install_link.resolve()))

    backend_root = cursor_home / "plugins/cache/alo-labs-agent-plugins/silver-bullet"
    if backend_root.is_dir():
        for child in sorted(backend_root.iterdir()):
            if child.is_dir() and re.fullmatch(r"[0-9a-f]{40}", child.name):
                roots.append((f"backend-cache/{child.name[:8]}", child))

    registry = cursor_home / "plugins/installed_plugins.json"
    if registry.is_file():
        try:
            data = json.loads(registry.read_text())
            entry = data.get("plugins", {}).get("silver-bullet@alo-labs")
            if isinstance(entry, list) and entry:
                entry = entry[0]
            if isinstance(entry, dict):
                git_path = entry.get("gitPath")
                if git_path:
                    roots.append(("installed-gitPath", Path(git_path)))
        except Exception:
            pass

    gitpath_base = cursor_home / "plugins/marketplaces/github.com/alo-exp/silver-bullet"
    if gitpath_base.is_dir():
        active_shas: set[str] = set()
        if registry.is_file():
            try:
                data = json.loads(registry.read_text())
                entry = data.get("plugins", {}).get("silver-bullet@alo-labs")
                if isinstance(entry, list) and entry:
                    entry = entry[0]
                if isinstance(entry, dict):
                    sha = entry.get("gitCommitSha", "")
                    if sha:
                        active_shas.add(sha)
            except Exception:
                pass
        if all_gitpaths:
            for child in sorted(gitpath_base.iterdir()):
                if child.is_dir() and re.fullmatch(r"[0-9a-f]{40}", child.name):
                    roots.append((f"gitPath/{child.name[:8]}", child))
        else:
            for sha in sorted(active_shas):
                child = gitpath_base / sha
                if child.is_dir():
                    roots.append((f"gitPath/{sha[:8]}", child))

    return roots


results = [analyze_surface(label, path) for label, path in discover_roots(cursor_home)]
failures = 0

print("Silver Bullet Cursor slash-picker duplicate diagnostic")
print(f"cursor_home={cursor_home}")
print()

for item in results:
    label = item["label"]
    if item.get("missing"):
        print(f"[MISSING] {label}: {item['path']}")
        continue
    cmd_agent = item["cmd_agent_overlap"]
    cmd_skills = item["cmd_skills_overlap"]
    status = "OK"
    if cmd_agent or cmd_skills:
        status = "FAIL"
        failures += 1
    print(f"[{status}] {label}")
    print(f"  path: {item['path']}")
    print(
        f"  commands={item['commands']} agents/cursor={item['agents']} "
        f"skills/={item['skills_dirs']}"
    )
    if cmd_agent:
        print(f"  cmd∩agents ({len(cmd_agent)}): {', '.join(cmd_agent[:8])}"
              + (" ..." if len(cmd_agent) > 8 else ""))
    if cmd_skills:
        print(f"  cmd∩skills/ ({len(cmd_skills)}): {', '.join(cmd_skills[:8])}"
              + (" ..." if len(cmd_skills) > 8 else ""))
    print()

if failures:
    print(f"RESULT: FAIL — {failures} surface(s) still expose picker duplicates")
    raise SystemExit(1)

print("RESULT: OK — zero command overlap in all discovered surfaces")
PY
