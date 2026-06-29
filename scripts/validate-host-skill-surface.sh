#!/usr/bin/env bash
# Validate host-target skill surfaces (Claude, Codex, Cursor).
#
# Fails when a host exposes:
#   - user-invocable skills without silver: prefix (except lone silver)
#   - duplicate logical routes under different raw names
#   - Claude silver-* hyphen directories alongside silver: routes
#
# Usage:
#   scripts/validate-host-skill-surface.sh [--repo-root PATH]

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="${2:-}"
      shift 2
      ;;
    -h|--help)
      sed -n '1,12p' "$0"
      exit 0
      ;;
    *)
      printf 'validate-host-skill-surface: unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  printf 'validate-host-skill-surface: python3 required\n' >&2
  exit 1
fi

python3 - "$repo_root" <<'PY'
from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

repo_root = Path(sys.argv[1])


def parse_frontmatter(path: Path) -> dict[str, str]:
    lines = path.read_text(errors="ignore").splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    meta: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if not match:
            continue
        meta[match.group(1)] = match.group(2).strip().strip('"')
    return meta


def is_user_invocable(meta: dict[str, str]) -> bool:
    return meta.get("user-invocable", "true").strip().lower() != "false"


def logical_route(name: str) -> str | None:
    if name == "silver":
        return "silver"
    if name.startswith("silver:"):
        return name
    if name.startswith("silver-"):
        return "silver:" + name[len("silver-") :]
    return None


def expected_claude_dir(name: str) -> str | None:
    if name == "silver":
        return "silver"
    if name.startswith("silver:"):
        return name
    return None


HOST_SURFACES: dict[str, list[tuple[str, str]]] = {
    "claude": [
        ("agents/claude", "skill"),
    ],
    "codex": [
        ("agents/codex", "skill"),
        ("plugins/silver-bullet/commands", "command"),
    ],
    "cursor": [
        ("agents/cursor", "skill"),
        ("plugins/silver-bullet/commands", "command"),
    ],
}

failures: list[str] = []
host_ok: dict[str, bool] = {host: True for host in HOST_SURFACES}


def fail(host: str, message: str) -> None:
    host_ok[host] = False
    failures.append(f"[{host}] {message}")


for host, surfaces in HOST_SURFACES.items():
    route_names: dict[str, set[str]] = defaultdict(set)
    route_entries: dict[str, list[str]] = defaultdict(list)

    for rel_root, kind in surfaces:
        root = repo_root / rel_root
        if not root.is_dir():
            fail(host, f"missing surface root: {rel_root}")
            continue

        if kind == "skill":
            paths = sorted(root.glob("*/SKILL.md"))
        else:
            paths = sorted(root.glob("*.md"))

        for path in paths:
            meta = parse_frontmatter(path)
            name = meta.get("name", "").strip()
            if not name:
                fail(host, f"{path.relative_to(repo_root)}: missing name in frontmatter")
                continue
            if not is_user_invocable(meta):
                continue

            rel = path.relative_to(repo_root)
            if name != "silver" and not name.startswith("silver:"):
                fail(
                    host,
                    f"{rel}: user-invocable skill {name!r} lacks silver: prefix "
                    f"(only bare silver is allowed)",
                )
                continue

            route = logical_route(name)
            if route is None:
                fail(host, f"{rel}: unable to derive logical route for {name!r}")
                continue

            route_names[route].add(name)
            route_entries[route].append(f"{rel} ({name!r})")

            if host == "claude" and kind == "skill":
                dir_name = path.parent.name
                expected_dir = expected_claude_dir(name)
                if expected_dir and dir_name != expected_dir:
                    fail(
                        host,
                        f"{rel}: directory {dir_name!r} does not match route {expected_dir!r} "
                        f"(duplicate picker risk)",
                    )

    for route, names in sorted(route_names.items()):
        if len(names) > 1:
            entries = ", ".join(route_entries[route])
            fail(
                host,
                f"logical route {route!r} exposed under multiple names {sorted(names)!r}: {entries}",
            )

    if host == "claude":
        claude_root = repo_root / "agents/claude"
        if claude_root.is_dir():
            hyphen_dirs = sorted(
                child.name
                for child in claude_root.iterdir()
                if child.is_dir() and child.name.startswith("silver-")
            )
            for dirname in hyphen_dirs:
                colon_name = "silver:" + dirname.removeprefix("silver-")
                fail(
                    host,
                    f"redundant hyphen directory agents/claude/{dirname} "
                    f"(use agents/claude/{colon_name})",
                )

print("validate-host-skill-surface: per-host summary")
for host in HOST_SURFACES:
    status = "OK" if host_ok[host] else "FAIL"
    print(f"  {host}: {status}")

if failures:
    print("validate-host-skill-surface: violations:", file=sys.stderr)
    for line in failures:
        print(f"  {line}", file=sys.stderr)
    raise SystemExit(1)

print("validate-host-skill-surface: OK — all host skill surfaces are namespaced and deduplicated")
PY
