#!/usr/bin/env bash
# Enforce 100% host-agent agnostic Silver Bullet core vs installer boundary.
#
# Core (skills, templates, silver-bullet.md, hooks runtime boundary, shared scripts)
# must not embed host-specific prose, paths, or cross-host installer logic.
# Host references belong in scripts/install-{claude,codex,cursor}.sh and
# scripts/lib/install-{host}/ only.
#
# Usage:
#   scripts/validate-host-agnostic-core.sh [--repo-root PATH]
#   scripts/validate-host-agnostic-core.sh --help

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

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
      printf 'validate-host-agnostic-core: unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  printf 'validate-host-agnostic-core: python3 required\n' >&2
  exit 1
fi

python3 - "$repo_root" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

repo_root = Path(sys.argv[1]).resolve()
failures: list[str] = []

# --- Path tiers ----------------------------------------------------------------

STRICT_ROOTS = [
    "skills",
    "templates",
    ".silver-bullet",
]
STRICT_FILES = [
    "silver-bullet.md",
    "templates/silver-bullet.md.base",
]

# Host-specific template trees — excluded from core scan (owned by installers).
TEMPLATE_EXCLUDE_PREFIXES = (
    "scripts/lib/install-claude/templates/CLAUDE.md.base",
    "templates/cursor-rules/",
    "templates/cursor/",
)

HOOKS_ROOT = "hooks"

# Bridge / runtime boundary files (host identifiers allowed).
HOOKS_ALLOWLIST = {
    "hooks/cursor-hook-bridge.sh",
    "hooks/kay-project-hook-bridge.sh",
    "hooks/cursor-hooks.json",
    "hooks/generate-cursor-hooks.py",
    "hooks/lib/runtime-paths.sh",
    "hooks/lib/recommended-tools.sh",
    "hooks/lib/context-mode-gate.sh",
    "hooks/lib/rtk-gate.sh",
    "hooks/lib/alumnium-gate.sh",
    "hooks/lib/capability-tier.sh",
    "hooks/lib/hook-output.sh",
    "hooks/phase-lock-claim.sh",
    "hooks/planning-file-guard.sh",
    "hooks/session-start",
}

SCRIPTS_ALLOWLIST = {
    "scripts/lib/agent-bundle-paths.sh",
    "scripts/render-agent-bundle.py",
    "scripts/review-fix-ladder.py",
    "scripts/optimize-rtk-context-mode.sh",
    "scripts/lib/rtk-cm-hosts.json",
    "scripts/lib/claude-matrix-auth.sh",
    "scripts/lib/merge-token-compression-config.py",
    "scripts/multi-ai-task-models.py",
}

# Never scan (generated mirrors, host bundles, tests, docs, site).
GLOBAL_EXCLUDE_PREFIXES = (
    "host-bundles/",
    "agents/",
    "tests/",
    "docs/",
    "site/",
    ".planning/",
    "plugins/silver-bullet/",
    "graphify-out/",
    ".git/",
    ".agentmemory/",
)

# Host-specific release/sync/e2e scripts — not SB core contract.
SCRIPTS_HOST_TOOLING_PREFIXES = (
    "scripts/sync-",
    "scripts/validate-host-install",
    "scripts/validate-claude",
    "scripts/run-enterprise-e2e",
    "scripts/run-release-",
    "scripts/run-pre-release",
    "scripts/run-tri-host",
    "scripts/post-release",
    "scripts/monitor-enterprise-e2e",
    "scripts/ENTERPRISE-E2E",
    "scripts/install-recommended-tools",
    "scripts/sb-diagnostics.sh",
    "scripts/silver-scan.py",
    "scripts/lib/enterprise-e2e",
)

INSTALLER_SCRIPTS = {
    "scripts/install-claude.sh",
    "scripts/install-codex.sh",
    "scripts/install-cursor.sh",
    "scripts/install-recommended-tools-cursor.sh",
}

INSTALLER_SCRIPT_PREFIXES = (
    "scripts/lib/install-claude/",
    "scripts/lib/install-codex/",
    "scripts/lib/install-cursor/",
    "scripts/lib/host-install-guides/",
)

INSTALLER_ONLY_SCRIPT_GLOBS = (
  "scripts/pre-release-cursor",
  "scripts/release-live-matrix-cursor",
  "scripts/validate-claude-agent",
  "scripts/run-pre-release-host",
  "scripts/run-tri-host-install",
  "scripts/lib/pre-release-host",
)

# False positives — substring must not match when surrounded by these prefixes/suffixes.
FALSE_POSITIVE_WORDS = {
    "cursor": ("recursor", "precursor", "discursor"),
}

# Hard violations — never allowed outside installer surfaces.
HARD_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("Claude Code", re.compile(r"Claude Code")),
    ("~/.claude", re.compile(r"~/.claude")),
    ("~/.codex", re.compile(r"~/.codex")),
    ("~/.cursor", re.compile(r"~/.cursor")),
    ("CODEX_HOME", re.compile(r"CODEX_HOME")),
    ("CURSOR_", re.compile(r"CURSOR_")),
    (".claude-plugin", re.compile(r"\.claude-plugin")),
    (".codex-plugin", re.compile(r"\.codex-plugin")),
    (".cursor-plugin", re.compile(r"\.cursor-plugin")),
    ("silver-bullet:claude:", re.compile(r"silver-bullet:claude:")),
    ("silver-bullet:codex:", re.compile(r"silver-bullet:codex:")),
    ("silver-bullet:cursor:", re.compile(r"silver-bullet:cursor:")),
]

HOST_WORD_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("claude", re.compile(r"\bclaude\b", re.IGNORECASE)),
    ("codex", re.compile(r"\bcodex\b", re.IGNORECASE)),
    ("cursor", re.compile(r"\bcursor\b", re.IGNORECASE)),
]

RUNTIME_LINE_MARKERS = (
    "SILVER_BULLET_RUNTIME",
    "SB_RUNTIME_NAME",
    "SB_RUNTIME_HOME",
    "SB_RUNTIME_STATE",
    "_sb_runtime",
    "CODEX_CI",
    "CODEX_THREAD",
    "CODEX_INTERNAL",
    "CURSOR_PLUGIN_ROOT",
    "CLAUDE_PLUGIN_ROOT",
    "KAY_HOME",
    "install-claude",
    "install-codex",
    "install-cursor",
)

INSTALLER_CROSS_RULES = {
    "scripts/install-claude.sh": {
        "forbidden_hosts": ("codex", "cursor"),
        "forbidden_paths": (r"~/.codex", r"~/.cursor", r"\.codex-plugin", r"\.cursor-plugin", r"CODEX_HOME", r"CURSOR_"),
        "forbidden_scripts": ("install-codex.sh", "install-cursor.sh"),
    },
    "scripts/install-codex.sh": {
        "forbidden_hosts": ("claude", "cursor"),
        "forbidden_paths": (r"~/.claude", r"~/.cursor", r"\.claude-plugin", r"\.cursor-plugin", r"CURSOR_"),
        "forbidden_scripts": ("install-claude.sh", "install-cursor.sh"),
    },
    "scripts/install-cursor.sh": {
        "forbidden_hosts": ("claude", "codex"),
        "forbidden_paths": (r"~/.claude", r"~/.codex", r"\.claude-plugin", r"\.codex-plugin", r"CODEX_HOME"),
        "forbidden_scripts": ("install-claude.sh", "install-codex.sh"),
    },
}


def rel(path: Path) -> str:
    return path.relative_to(repo_root).as_posix()


def is_release_manifest_contract_line(path: Path, line: str) -> bool:
    r = rel(path)
    if r != "skills/silver-create-release/SKILL.md":
        return False
    if "git add CHANGELOG.md README.md" in line and "marketplace.json" in line and "plugin.json" in line:
        return True
    return False



def is_glob_excluded(r: str) -> bool:
    for prefix in GLOBAL_EXCLUDE_PREFIXES:
        if r.startswith(prefix):
            return True
    for prefix in SCRIPTS_HOST_TOOLING_PREFIXES:
        if r.startswith(prefix) or prefix in r:
            return True
    return False


def is_template_excluded(r: str) -> bool:
    for prefix in TEMPLATE_EXCLUDE_PREFIXES:
        if r == prefix.rstrip("/") or r.startswith(prefix):
            return True
    return False


def is_installer_script(r: str) -> bool:
    if r in INSTALLER_SCRIPTS:
        return True
    for prefix in INSTALLER_SCRIPT_PREFIXES:
        if r.startswith(prefix):
            return True
    for prefix in INSTALLER_ONLY_SCRIPT_GLOBS:
        if prefix in r:
            return True
    if "/install-claude/" in r or "/install-codex/" in r or "/install-cursor/" in r:
        return True
    base = Path(r).name
    if base.startswith("install-") and base.endswith(".sh") and "recommended-tools" not in base:
        return True
    return False


def is_scannable_file(path: Path) -> bool:
    if not path.is_file():
        return False
    return path.suffix.lower() in {
        ".md", ".sh", ".json", ".base", ".yaml", ".yml", ".txt", ".mdc", ".py", ""
    } or path.name in {"session-start", "session-stop"}


def iter_strict_files() -> list[Path]:
    found: list[Path] = []
    for root_name in STRICT_ROOTS:
        root = repo_root / root_name
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not is_scannable_file(path):
                continue
            r = rel(path)
            if is_glob_excluded(r) or is_template_excluded(r):
                continue
            found.append(path)
    for name in STRICT_FILES:
        path = repo_root / name
        if path.is_file():
            found.append(path)
    return sorted(set(found))


def iter_hooks_files() -> list[Path]:
    root = repo_root / HOOKS_ROOT
    if not root.exists():
        return []
    out: list[Path] = []
    for path in root.rglob("*"):
        if not is_scannable_file(path):
            continue
        r = rel(path)
        if is_glob_excluded(r):
            continue
        out.append(path)
    return sorted(out)


def iter_shared_scripts() -> list[Path]:
    root = repo_root / "scripts"
    if not root.exists():
        return []
    out: list[Path] = []
    for path in root.rglob("*"):
        if not is_scannable_file(path):
            continue
        r = rel(path)
        if is_glob_excluded(r) or is_installer_script(r):
            continue
        if r == "scripts/validate-host-agnostic-core.sh":
            continue
        out.append(path)
    return sorted(out)


def is_false_positive(word: str, text: str, start: int, end: int) -> bool:
    if word != "cursor":
        return False
    window = text[max(0, start - 24): min(len(text), end + 24)].lower()
    if "merge-cursor-hooks" in window or "install-cursor/" in window:
        return True
    for fp in FALSE_POSITIVE_WORDS["cursor"]:
        if fp in window:
            return True
    return False


def line_allows_runtime_identifiers(line: str) -> bool:
    return any(marker in line for marker in RUNTIME_LINE_MARKERS)


def scan_content(
    path: Path,
    *,
    strict: bool,
) -> list[tuple[int, str, str]]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    hits: list[tuple[int, str, str]] = []
    lines = text.splitlines()

    for line_no, line in enumerate(lines, start=1):
        if strict and is_release_manifest_contract_line(path, line):
            continue
        runtime_ok = not strict and line_allows_runtime_identifiers(line)

        for label, pattern in HARD_PATTERNS:
            if pattern.search(line):
                hits.append((line_no, label, line.strip()[:120]))
                continue

        if strict and not runtime_ok:
            # JSON config uses runtime IDs as structural keys — hard paths only.
            if path.suffix.lower() == ".json":
                continue
            for label, pattern in HOST_WORD_PATTERNS:
                for match in pattern.finditer(line):
                    if is_false_positive(label, line, match.start(), match.end()):
                        continue
                    hits.append((line_no, label, line.strip()[:120]))
                    break

    return hits


def check_file(path: Path, *, tier: str) -> None:
    r = rel(path)
    if tier == "strict":
        hits = scan_content(path, strict=True)
    elif tier == "hooks":
        if r in HOOKS_ALLOWLIST:
            return
        # Runtime layer: hard foreign paths only (host IDs allowed on runtime lines).
        hits = scan_content(path, strict=False)
    elif tier == "scripts":
        if r in SCRIPTS_ALLOWLIST:
            return
        hits = scan_content(path, strict=False)
    else:
        return

    for line_no, label, snippet in hits:
        failures.append(f"[{tier}] {r}:{line_no}: {label} — {snippet}")


def check_installer_cross_contamination() -> None:
    skip_line_markers = (
        "render_agent_bundle",
        "sb_agent_bundle",
        "host-bundles/",
        "agents/claude",
        "agents/codex",
        "agents/cursor",
        "validate-host",
        ".replace(",
        "os.homedir(), '.claude'",
        "os.homedir(), \".claude\"",
        "os.homedir() + '/.claude'",
        "os.homedir() + \"/.claude\"",
        "path_segment_re",
        r"/\.claude",
        "foreign namespace",
        "backup /",
        "plugin_root}/agents/",
    )
    for script_rel, rules in INSTALLER_CROSS_RULES.items():
        path = repo_root / script_rel
        if not path.is_file():
            failures.append(f"[installer] missing {script_rel}")
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        lines = text.splitlines()
        for line_no, line in enumerate(lines, start=1):
            if any(marker in line for marker in skip_line_markers):
                continue
            lower = line.lower()
            for host in rules["forbidden_hosts"]:
                if re.search(rf"\b{re.escape(host)}\b", lower):
                    failures.append(
                        f"[installer-cross] {script_rel}:{line_no}: foreign host '{host}' — {line.strip()[:120]}"
                    )
                    break
            for frag in rules["forbidden_paths"]:
                if frag.startswith("\\"):
                    if re.search(frag, line):
                        failures.append(
                            f"[installer-cross] {script_rel}:{line_no}: foreign path '{frag}' — {line.strip()[:120]}"
                        )
                elif frag in line:
                    failures.append(
                        f"[installer-cross] {script_rel}:{line_no}: foreign path '{frag}' — {line.strip()[:120]}"
                    )
            for other in rules["forbidden_scripts"]:
                if other in line:
                    failures.append(
                        f"[installer-cross] {script_rel}:{line_no}: foreign installer '{other}' — {line.strip()[:120]}"
                    )


# --- Run scans -----------------------------------------------------------------

for path in iter_strict_files():
    check_file(path, tier="strict")

for path in iter_hooks_files():
    check_file(path, tier="hooks")

for path in iter_shared_scripts():
    check_file(path, tier="scripts")

check_installer_cross_contamination()

# --- Report --------------------------------------------------------------------

print("validate-host-agnostic-core: scan summary")
print(f"  strict roots: {', '.join(STRICT_ROOTS)}")
print(f"  hooks allowlist: {len(HOOKS_ALLOWLIST)} files")
print(f"  installer scripts: {len(INSTALLER_CROSS_RULES)} cross-checks")

if failures:
    print("validate-host-agnostic-core: violations:", file=sys.stderr)
    for line in failures[:200]:
        print(f"  {line}", file=sys.stderr)
    if len(failures) > 200:
        print(f"  ... and {len(failures) - 200} more", file=sys.stderr)
    print(f"validate-host-agnostic-core: FAIL ({len(failures)} violations)", file=sys.stderr)
    raise SystemExit(1)

print("validate-host-agnostic-core: OK — core is host-agent agnostic")
PY
