#!/usr/bin/env bash
# Validate host-target skill surfaces (Claude, Codex, Cursor).
#
# Fails when a host exposes:
#   - user-invocable skills without sb: prefix (except lone sb)
#   - duplicate logical routes under different raw names
#   - Claude/Cursor sb-* hyphen directories alongside sb: routes
#   - Cursor user-invocable skills that duplicate plugin command stubs
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
    if name == "sb":
        return "sb"
    if name.startswith("sb:"):
        return name
    if name.startswith("sb-"):
        return "sb:" + name[len("sb-") :]
    return None


def expected_claude_dir(name: str) -> str | None:
    if name == "sb":
        return "sb"
    if name.startswith("sb:"):
        return name
    return None


HOST_SURFACES: dict[str, list[tuple[str, str]]] = {
    "claude": [
        ("agents/claude", "skill"),
    ],
    "codex": [
        ("host-bundles/codex", "skill"),
    ],
    "cursor": [
        ("plugins/silver-bullet/commands", "command"),
        ("host-bundles/cursor", "skill"),
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
    command_routes: set[str] = set()

    for rel_root, kind in surfaces:
        if kind != "command":
            continue
        root = repo_root / rel_root
        if not root.is_dir():
            fail(host, f"missing surface root: {rel_root}")
            continue
        for path in sorted(root.glob("*.md")):
            meta = parse_frontmatter(path)
            name = meta.get("name", "").strip()
            if not name:
                fail(host, f"{path.relative_to(repo_root)}: missing name in frontmatter")
                continue
            if ":" in path.name:
                fail(
                    host,
                    f"{path.relative_to(repo_root)}: command filename contains ':'; "
                    f"use a filesystem-safe kebab-case filename",
                )
            stem = path.stem
            if stem != name:
                fail(
                    host,
                    f"{path.relative_to(repo_root)}: filename stem {stem!r} must match "
                    f"kebab-case command name {name!r}",
                )
            if ":" in name:
                fail(
                    host,
                    f"{path.relative_to(repo_root)}: command name {name!r} must be kebab-case",
                )
            command_routes.add(logical_route(name) or name)

    for rel_root, kind in surfaces:
        if kind != "skill":
            continue
        root = repo_root / rel_root
        if not root.is_dir():
            fail(host, f"missing surface root: {rel_root}")
            continue

        for path in sorted(root.glob("*/SKILL.md")):
            meta = parse_frontmatter(path)
            name = meta.get("name", "").strip()
            if not name:
                fail(host, f"{path.relative_to(repo_root)}: missing name in frontmatter")
                continue

            logical_name = logical_route(name) or name
            if host in {"cursor", "codex"} and logical_name in command_routes and is_user_invocable(meta):
                rel = path.relative_to(repo_root)
                fail(
                    host,
                    f"{rel}: user-invocable skill {name!r} duplicates plugin command stub "
                    f"(set user-invocable: false on the rendered bundle skill)",
                )
                continue

            if host == "cursor" and logical_name in command_routes:
                rel = path.relative_to(repo_root)
                fail(
                    host,
                    f"{rel}: command-covered route {name!r} must not ship in host-bundles/cursor "
                    f"(slash command owns the public surface; keep instructions in skill-source/)",
                )
                continue

            if not is_user_invocable(meta):
                continue

            rel = path.relative_to(repo_root)
            if name != "sb" and not name.startswith("sb:"):
                fail(
                    host,
                    f"{rel}: user-invocable skill {name!r} lacks sb: prefix "
                    f"(only bare sb is allowed)",
                )
                continue

            route = logical_route(name)
            if route is None:
                fail(host, f"{rel}: unable to derive logical route for {name!r}")
                continue

            route_names[route].add(name)
            route_entries[route].append(f"{rel} ({name!r})")

            if host in {"claude", "cursor"}:
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

    for host_name, rel_bundle in (("claude", "agents/claude"), ("cursor", "host-bundles/cursor")):
        bundle_root = repo_root / rel_bundle
        if bundle_root.is_dir():
            hyphen_dirs = sorted(
                child.name
                for child in bundle_root.iterdir()
                if child.is_dir() and child.name.startswith("sb-")
            )
            for dirname in hyphen_dirs:
                colon_name = "sb:" + dirname.removeprefix("sb-")
                fail(
                    host_name,
                    f"redundant hyphen directory {rel_bundle}/{dirname} "
                    f"(use {rel_bundle}/{colon_name})",
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
