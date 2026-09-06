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


def logical_route(name: str) -> str | None:
    if name == "silver":
        return "silver"
    if name.startswith("sb:"):
        return name
    if name.startswith("silver-"):
        return "sb:" + name.removeprefix("silver-")
    return None


def command_routes(root: Path) -> set[str]:
    routes: set[str] = set()
    commands = root / "commands"
    if not commands.is_dir():
        return routes
    for path in sorted(commands.glob("*.md")):
        name = path.stem
        route = logical_route(name)
        if route:
            routes.add(route)
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


def host_bundle_skill_routes(root: Path) -> set[str]:
    routes: set[str] = set()
    bundle = root / "host-bundles" / "cursor"
    if not bundle.is_dir():
        return routes
    for skill_md in sorted(bundle.glob("*/SKILL.md")):
        meta = parse_frontmatter(skill_md)
        name = meta.get("name", skill_md.parent.name).strip()
        route = logical_route(name) or logical_route(skill_md.parent.name)
        if route:
            routes.add(route)
    return routes


def plugin_manifest_issues(root: Path) -> list[str]:
    issues: list[str] = []
    manifest = root / ".cursor-plugin" / "plugin.json"
    if not manifest.is_file():
        return issues
    try:
        data = json.loads(manifest.read_text())
    except Exception:
        return ["invalid .cursor-plugin/plugin.json"]
    skills = data.get("skills")
    if skills:
        issues.append(f"plugin.json declares skills={skills!r} (registers subagents in / picker)")
    return issues


def nested_plugin_picker_surfaces(root: Path) -> list[str]:
    issues: list[str] = []
    nested_commands = root / "plugins" / "silver-bullet" / "commands"
    nested_agents = root / "plugins" / "silver-bullet" / "agents" / "cursor"
    nested_manifest = root / "plugins" / "silver-bullet" / ".cursor-plugin" / "plugin.json"
    if nested_commands.is_dir() and any(nested_commands.glob("*.md")):
        issues.append("plugins/silver-bullet/commands")
    if nested_agents.is_dir() and any(nested_agents.glob("*/SKILL.md")):
        issues.append("plugins/silver-bullet/agents/cursor")
    if nested_manifest.is_file():
        try:
            manifest = json.loads(nested_manifest.read_text())
            if manifest.get("commands") or manifest.get("skills"):
                issues.append("plugins/silver-bullet/.cursor-plugin/plugin.json declares commands/skills")
        except Exception:
            pass
    if (root / "host-bundles" / "cursor").is_dir():
        issues.append("host-bundles/cursor")
    return issues


def workspace_auto_discovery_report(root: Path) -> dict[str, object]:
    patterns = load_cursorignore(root)
    issues: list[str] = []
    ignored = 0
    for label, scan_root in [
        ("skills", root / "skills"),
        ("host-bundles/cursor", root / "host-bundles" / "cursor"),
        ("agents", root / "agents"),
        ("plugins/silver-bullet/skill-source", root / "plugins" / "silver-bullet" / "skill-source"),
        ("plugins/silver-bullet/agents", root / "plugins" / "silver-bullet" / "agents"),
        ("project .cursor/agents", root / ".cursor" / "agents"),
    ]:
        if not scan_root.is_dir():
            continue
        for skill_md in sorted(scan_root.glob("**/SKILL.md")):
            if is_cursorignored(root, skill_md, patterns) or is_cursorignored(root, skill_md.parent, patterns):
                ignored += 1
                continue
            meta = parse_frontmatter(skill_md)
            name = meta.get("name", skill_md.parent.name).strip()
            issues.append(f"{label}: {name} ({skill_md.parent.relative_to(root)})")
    for issue in plugin_manifest_issues(root):
        issues.append(f".cursor-plugin/plugin.json: {issue}")
    return {"patterns": patterns, "issues": issues, "ignored": ignored}


def analyze_surface(label: str, root: Path) -> dict[str, object]:
    if not root.is_dir():
        return {
            "label": label,
            "path": str(root),
            "missing": True,
            "cmd_agent_overlap": [],
            "cmd_skills_overlap": [],
            "extra_surfaces": [],
            "host_bundle_overlap": [],
            "manifest_issues": [],
        }
    cmd = command_routes(root)
    agent = agent_skill_routes(root)
    skills = canonical_skill_routes(root)
    host_bundle = host_bundle_skill_routes(root)
    cmd_agent = sorted(cmd & agent)
    cmd_skills = sorted(cmd & skills)
    host_overlap = sorted(cmd & host_bundle)
    extra_surfaces = nested_plugin_picker_surfaces(root) if "gitPath" in label or label == "installed-gitPath" else []
    manifest_issues = plugin_manifest_issues(root)
    return {
        "label": label,
        "path": str(root),
        "missing": False,
        "commands": len(cmd),
        "agents": len(agent),
        "skills_dirs": len(list((root / "skills").glob("*/SKILL.md"))) if (root / "skills").is_dir() else 0,
        "cmd_agent_overlap": cmd_agent,
        "cmd_skills_overlap": cmd_skills,
        "host_bundle_overlap": host_overlap,
        "extra_surfaces": extra_surfaces,
        "manifest_issues": manifest_issues,
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
workspace = workspace_auto_discovery_report(repo_root)
failures = 0

print("Silver Bullet Cursor slash-picker duplicate diagnostic")
print(f"cursor_home={cursor_home}")
print()

if workspace["issues"]:
    failures += 1
    print("[FAIL] dev-workspace-auto-discovery")
    print(f"  path: {repo_root}")
    print(f"  .cursorignore patterns={workspace['patterns']!r}")
    print(f"  unignored workspace skill surfaces ({len(workspace['issues'])}):")
    for issue in workspace["issues"][:12]:
        print(f"    - {issue}")
    if len(workspace["issues"]) > 12:
        print(f"    ... +{len(workspace['issues']) - 12} more")
    print()
else:
    print("[OK] dev-workspace-auto-discovery")
    print(f"  path: {repo_root}")
    print(f"  .cursorignore patterns={workspace['patterns']!r}")
    print(f"  ignored workspace entries={workspace['ignored']}")
    print()

for item in results:
    label = item["label"]
    if item.get("missing"):
        print(f"[MISSING] {label}: {item['path']}")
        continue
    cmd_agent = item["cmd_agent_overlap"]
    cmd_skills = item["cmd_skills_overlap"]
    host_overlap = item.get("host_bundle_overlap", [])
    extra_surfaces = item.get("extra_surfaces", [])
    manifest_issues = item.get("manifest_issues", [])
    status = "OK"
    agent_count = int(item.get("agents", 0) or 0)
    if cmd_agent or cmd_skills or host_overlap or extra_surfaces or manifest_issues or agent_count > 0:
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
    if host_overlap:
        print(f"  cmd∩host-bundles ({len(host_overlap)}): {', '.join(host_overlap[:8])}"
              + (" ..." if len(host_overlap) > 8 else ""))
    if extra_surfaces:
        print(f"  extra picker surfaces ({len(extra_surfaces)}): {', '.join(extra_surfaces[:4])}"
              + (" ..." if len(extra_surfaces) > 4 else ""))
    if manifest_issues:
        print(f"  manifest issues ({len(manifest_issues)}): {', '.join(manifest_issues[:4])}"
              + (" ..." if len(manifest_issues) > 4 else ""))
    if agent_count > 0:
        print(f"  agents/cursor subagent surface present ({agent_count} skills — must be 0)")
    print()

if failures:
    print(f"RESULT: FAIL — {failures} surface(s) still expose picker duplicates")
    raise SystemExit(1)

print("RESULT: OK — zero command overlap in all discovered surfaces")
PY
