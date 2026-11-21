#!/usr/bin/env bash
# Validate host-target skill surfaces (Claude, Codex).
#
# Fails when a host exposes:
#   - user-invocable skills without sb: prefix (except lone sb)
#   - a logical route more than once (same or different raw names)
#   - a skill directory not named after its route (sb:<route> for Claude,
#     sb-<route> for Codex), or Claude sb-* hyphen directories
#
# Usage:
#   scripts/validate-host-skill-surface.sh [--repo-root PATH]

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      [[ $# -ge 2 ]] || { printf 'validate-host-skill-surface: %s requires a value\n' "$1" >&2; exit 2; }
      repo_root="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '1,11p' "$0"
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


def expected_dir(host: str, name: str) -> str:
    """The picker directory for an sb route: Claude lists routes by
    its colon names, the Codex bundle uses filesystem-safe sb-<route>."""
    if name == "sb" or host != "codex":
        return name
    return "sb-" + name[len("sb:") :]


HOST_SURFACES: dict[str, list[tuple[str, str]]] = {
    "claude": [
        ("agents/claude", "skill"),
    ],
    "codex": [
        ("host-bundles/codex", "skill"),
    ],
}

failures: list[str] = []
host_ok: dict[str, bool] = {host: True for host in HOST_SURFACES}


def fail(host: str, message: str) -> None:
    host_ok[host] = False
    failures.append(f"[{host}] {message}")


for host, surfaces in HOST_SURFACES.items():
    route_entries: dict[str, list[str]] = defaultdict(list)
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

            route_entries[route].append(f"{rel} ({name!r})")

            dir_name = path.parent.name
            want_dir = expected_dir(host, name)
            if dir_name != want_dir:
                fail(
                    host,
                    f"{rel}: directory {dir_name!r} does not match route {want_dir!r} "
                    f"(duplicate picker risk)",
                )

    # Count entries, not distinct names: two directories that both declare
    # name: sb:feature show the route twice in the picker.
    for route, entries in sorted(route_entries.items()):
        if len(entries) > 1:
            fail(
                host,
                f"logical route {route!r} exposed {len(entries)} times: {', '.join(entries)}",
            )

for host_name, rel_bundle in (("claude", "agents/claude"),):
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
