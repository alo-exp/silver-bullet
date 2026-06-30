#!/usr/bin/env bash
# Cross-host installation surface audit — repo layout, manifests, cache bleed.
#
# Composes validate-host-skill-surface.sh and validate-claude-agent-token-budget.sh
# with structural checks that foreign host bundles never appear on the wrong surface.
#
# Usage:
#   scripts/validate-host-install-surface.sh [--repo-root PATH]
#   scripts/validate-host-install-surface.sh --cache-root PATH --host claude|codex|cursor
#   scripts/validate-host-install-surface.sh --repo-root PATH --host all|claude|codex|cursor

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
cache_root=""
host_filter="all"
max_claude_tokens=14000

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="${2:-}"
      shift 2
      ;;
    --cache-root)
      cache_root="${2:-}"
      shift 2
      ;;
    --host)
      host_filter="${2:-}"
      shift 2
      ;;
    --max-claude-tokens)
      max_claude_tokens="${2:-}"
      shift 2
      ;;
    -h|--help)
      sed -n '1,14p' "$0"
      exit 0
      ;;
    *)
      printf 'validate-host-install-surface: unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

# shellcheck source=scripts/lib/agent-bundle-paths.sh
source "${script_dir}/lib/agent-bundle-paths.sh"

if ! command -v python3 >/dev/null 2>&1; then
  printf 'validate-host-install-surface: python3 required\n' >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'validate-host-install-surface: jq required\n' >&2
  exit 1
fi

skill_surface_script="${script_dir}/validate-host-skill-surface.sh"
token_budget_script="${script_dir}/validate-claude-agent-token-budget.sh"

run_repo_checks() {
  local filter="$1"
  python3 - "$repo_root" "$filter" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
host_filter = sys.argv[2]
failures: list[str] = []
host_ok: dict[str, bool] = {"claude": True, "codex": True, "cursor": True}


def fail(host: str, message: str) -> None:
    host_ok[host] = False
    failures.append(f"[{host}] {message}")


def should_check(host: str) -> bool:
    return host_filter in {"all", host}


agents_root = repo_root / "agents"
host_bundles = repo_root / "host-bundles"

if should_check("claude"):
    claude_bundle = agents_root / "claude"
    if not claude_bundle.is_dir():
        fail("claude", "missing agents/claude bundle")
    if agents_root.is_dir():
        foreign = sorted(
            child.name
            for child in agents_root.iterdir()
            if child.is_dir() and child.name not in {"claude"}
        )
        for name in foreign:
            fail("claude", f"foreign host directory agents/{name} (only agents/claude allowed)")
    for stray in ("codex", "cursor"):
        if (agents_root / stray).exists():
            fail("claude", f"agents/{stray} must not exist — use host-bundles/{stray}")

    manifest = repo_root / ".claude-plugin" / "plugin.json"
    if not manifest.is_file():
        fail("claude", "missing .claude-plugin/plugin.json")
    else:
        data = json.loads(manifest.read_text())
        skills = data.get("skills", "")
        if skills != "./agents/claude":
            fail("claude", f".claude-plugin skills path must be ./agents/claude — got {skills!r}")
        if data.get("agents"):
            fail("claude", ".claude-plugin must not declare agents (skills path is sufficient; Claude schema rejects agents)")
        if "commands" in data:
            fail("claude", ".claude-plugin must not declare commands (Codex-only surface)")

    if (repo_root / "commands").is_dir():
        fail("claude", "repo-root commands/ must not exist (Codex composer stubs live under plugins/silver-bullet/commands)")

    # Claude plugin auto-discovers agents/<subdir>/ as silver-bullet:<subdir>: namespaces.
    forbidden_ns = (":codex:", ":cursor:", "silver-bullet:codex", "silver-bullet:cursor")
    if claude_bundle.is_dir():
        for skill in sorted(claude_bundle.glob("**/SKILL.md")):
            text = skill.read_text(errors="ignore")
            for needle in forbidden_ns:
                if needle in text:
                    fail(
                        "claude",
                        f"{skill.relative_to(repo_root)}: contains foreign namespace ref {needle!r}",
                    )
                    break
            meta_name = ""
            for line in text.splitlines():
                if line.strip() == "---":
                    break
                if line.startswith("name:"):
                    meta_name = line.split(":", 1)[1].strip()
                    break
            for prefix in ("silver-bullet:codex:", "silver-bullet:cursor:"):
                if meta_name.startswith(prefix):
                    fail(
                        "claude",
                        f"{skill.relative_to(repo_root)}: agent name {meta_name!r} is a foreign host namespace",
                    )

if should_check("codex"):
    codex_bundle = host_bundles / "codex"
    if not codex_bundle.is_dir():
        fail("codex", "missing host-bundles/codex")
    if (agents_root / "codex").exists():
        fail("codex", "agents/codex must not exist — use host-bundles/codex")

    codex_manifest = repo_root / "plugins" / "silver-bullet" / ".codex-plugin" / "plugin.json"
    if not codex_manifest.is_file():
        fail("codex", "missing plugins/silver-bullet/.codex-plugin/plugin.json")
    else:
        data = json.loads(codex_manifest.read_text())
        if data.get("skills"):
            fail("codex", ".codex-plugin must not declare skills (uses skill-source mirror)")
        if data.get("agents"):
            fail("codex", ".codex-plugin must not declare agents path")

    pkg = repo_root / "plugins" / "silver-bullet"
    if pkg.is_dir():
        for forbidden in ("agents", "skills", ".generated-skills"):
            if (pkg / forbidden).exists():
                fail("codex", f"plugins/silver-bullet/{forbidden} must not ship in Codex package")
        if not (pkg / "skill-source").is_dir():
            fail("codex", "plugins/silver-bullet/skill-source missing")
        if not (pkg / "commands").is_dir():
            fail("codex", "plugins/silver-bullet/commands missing")

if should_check("cursor"):
    cursor_bundle = host_bundles / "cursor"
    if not cursor_bundle.is_dir():
        fail("cursor", "missing host-bundles/cursor")
    if (agents_root / "cursor").exists():
        fail("cursor", "agents/cursor must not exist — use host-bundles/cursor")

    cursor_manifest = repo_root / ".cursor-plugin" / "plugin.json"
    plugin_cursor_manifest = repo_root / "plugins" / "silver-bullet" / ".cursor-plugin" / "plugin.json"
    for label, manifest in (
        ("root", cursor_manifest),
        ("plugins/silver-bullet", plugin_cursor_manifest),
    ):
        if not manifest.is_file():
            if label == "plugins/silver-bullet":
                fail("cursor", f"missing {manifest.relative_to(repo_root)}")
            continue
        data = json.loads(manifest.read_text())
        skills = data.get("skills", "")
        if skills != "./agents/cursor":
            fail(
                "cursor",
                f"{manifest.relative_to(repo_root)} skills path must be ./agents/cursor — got {skills!r}",
            )
        if data.get("agents"):
            fail("cursor", f"{manifest.relative_to(repo_root)} must not declare agents (skills path is sufficient)")

    if not cursor_manifest.is_file() and not plugin_cursor_manifest.is_file():
        fail("cursor", "missing .cursor-plugin/plugin.json")

if host_bundles.is_dir() and should_check("claude"):
    if (host_bundles / "claude").exists():
        fail("claude", "host-bundles/claude must not exist — Claude bundle lives under agents/claude")

print("validate-host-install-surface: repo layout summary")
for host in ("claude", "codex", "cursor"):
    if not should_check(host):
        continue
    status = "OK" if host_ok[host] else "FAIL"
    print(f"  {host}: {status}")

if failures:
    print("validate-host-install-surface: repo violations:", file=sys.stderr)
    for line in failures:
        print(f"  {line}", file=sys.stderr)
    raise SystemExit(1)
PY
}

run_cache_checks() {
  local root="$1"
  local host="$2"
  python3 - "$root" "$host" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

cache_root = Path(sys.argv[1])
host = sys.argv[2]
failures: list[str] = []

if not cache_root.is_dir():
    print(f"validate-host-install-surface: cache root missing: {cache_root}", file=sys.stderr)
    raise SystemExit(1)

agents = cache_root / "agents"


def forbid(path: Path, label: str) -> None:
    if path.exists():
        failures.append(f"[{host}] cache bleed: {label} present at {path.relative_to(cache_root)}")


def require(path: Path, label: str) -> None:
    if not path.is_dir():
        failures.append(f"[{host}] cache missing required {label}: {path.relative_to(cache_root)}")


if host == "claude":
    require(agents / "claude", "agents/claude")
    forbid(agents / "codex", "agents/codex")
    forbid(agents / "cursor", "agents/cursor")
    forbid(cache_root / "host-bundles", "host-bundles")
    forbid(cache_root / "commands", "commands")
    if agents.is_dir():
        foreign = [
            child.name
            for child in agents.iterdir()
            if child.is_dir() and child.name != "claude"
        ]
        for name in foreign:
            failures.append(f"[claude] cache bleed: agents/{name}")

elif host == "cursor":
    require(agents / "cursor", "agents/cursor")
    forbid(agents / "claude", "agents/claude")
    forbid(agents / "codex", "agents/codex")
    forbid(cache_root / "host-bundles", "host-bundles")

elif host == "codex":
    forbid(agents / "claude", "agents/claude")
    forbid(agents / "cursor", "agents/cursor")
    forbid(cache_root / "host-bundles", "host-bundles")
    # Codex package uses skill-source; agents/ at package root is legacy bleed.
    if (cache_root / "agents").is_dir():
        failures.append("[codex] cache bleed: agents/ tree (Codex uses skill-source/)")
    if not (cache_root / "skill-source").is_dir() and not (cache_root / "hooks").is_dir():
        failures.append("[codex] cache missing skill-source/ and hooks/ — not a Codex package root")

else:
    print(f"validate-host-install-surface: unknown host for cache check: {host}", file=sys.stderr)
    raise SystemExit(2)

if failures:
    print(f"validate-host-install-surface: cache violations ({host}):", file=sys.stderr)
    for line in failures:
        print(f"  {line}", file=sys.stderr)
    raise SystemExit(1)

print(f"validate-host-install-surface: cache OK for host={host} ({cache_root})")
PY
}

exit_code=0

if [[ -n "$cache_root" ]]; then
  if [[ "$host_filter" == "all" ]]; then
    printf 'validate-host-install-surface: --cache-root requires --host claude|codex|cursor\n' >&2
    exit 2
  fi
  run_cache_checks "$cache_root" "$host_filter" || exit_code=1
else
  if [[ "$host_filter" == "all" || "$host_filter" == "claude" || "$host_filter" == "codex" || "$host_filter" == "cursor" ]]; then
    run_repo_checks "$host_filter" || exit_code=1
  else
    printf 'validate-host-install-surface: invalid --host %s\n' "$host_filter" >&2
    exit 2
  fi

  if [[ -x "$skill_surface_script" ]]; then
    if ! bash "$skill_surface_script" --repo-root "$repo_root"; then
      exit_code=1
    fi
  fi

  if [[ "$host_filter" == "all" || "$host_filter" == "claude" ]]; then
    if [[ -x "$token_budget_script" ]]; then
      if ! bash "$token_budget_script" --repo-root "$repo_root" --max-tokens "$max_claude_tokens"; then
        exit_code=1
      fi
    fi
  fi
fi

if [[ "$exit_code" -eq 0 ]]; then
  echo "validate-host-install-surface: OK — no cross-host installation bleed detected"
fi
exit "$exit_code"
