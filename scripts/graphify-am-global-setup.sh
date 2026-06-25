#!/usr/bin/env bash
# graphify-am-global-setup.sh — SB-independent global Graphify + agentmemory synergy_max setup.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB="${REPO_ROOT}/hooks/lib/graphify-am-global.sh"

MODE="apply"
HOST=""
REPO_PATH=""
APPLY_ALL=0

usage() {
  cat <<'EOF'
Usage: bash scripts/graphify-am-global-setup.sh --host HOST [--apply|--verify] [options]

Global (user/machine-level) Graphify + agentmemory setup using synergy_max profile.
Does NOT require Silver Bullet, /silver:init, .silver-bullet.json, or SB hooks.

Hosts: claude | codex | opencode | goose | hermes | all

Options:
  --host HOST   Target agent host (required unless documenting defaults)
  --apply       Apply idempotent global wiring (default)
  --verify      Scorecard only; exit 1 on critical failures
  --repo PATH   Optional project root for AGENTMEMORY_EXPORT_ROOT, bridge, index
  --all         With --apply/--verify: run for every host with detected global config
  --dry-run     Print actions without mutating files
  -h, --help    Show help

Examples:
  bash scripts/graphify-am-global-setup.sh --host claude --apply
  bash scripts/graphify-am-global-setup.sh --host codex --verify
  bash scripts/graphify-am-global-setup.sh --host claude --apply --repo ~/projects/my-app
  bash scripts/graphify-am-global-setup.sh --host all --verify

Export root without --repo: ~/.agentmemory/default-export (override per project with --repo).
Git hooks: graphify hook install (global git template — applies to new repos).
See docs/graphify-am/PLATFORM-MATRIX.md and docs/graphify-am/verification/.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      shift
      HOST="${1:-}"
      [[ "$HOST" == "all" ]] && APPLY_ALL=1
      ;;
    --apply) MODE="apply" ;;
    --verify) MODE="verify" ;;
    --repo)
      shift
      REPO_PATH="${1:-}"
      REPO_PATH="$(cd "$REPO_PATH" 2>/dev/null && pwd || printf '%s' "$REPO_PATH")"
      ;;
    --all) APPLY_ALL=1 ;;
    --dry-run) export GA_GLOBAL_DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# shellcheck source=../hooks/lib/graphify-am-global.sh
source "$LIB"

if [[ -z "$HOST" && "$APPLY_ALL" -eq 0 ]]; then
  echo "Error: --host is required (claude|codex|opencode|goose|hermes|all)" >&2
  usage >&2
  exit 2
fi

run_for_host() {
  local h="${1:-}"
  ga_validate_host "$h" || {
    echo "Unsupported host: $h" >&2
    return 2
  }
  case "$MODE" in
    apply) ga_apply_host "$h" "$REPO_PATH" ;;
    verify) ga_verify_host "$h" "$REPO_PATH" ;;
  esac
}

if [[ "$APPLY_ALL" -eq 1 ]]; then
  rc=0
  mapfile -t detected < <(ga_detect_configured_hosts)
  if [[ "${#detected[@]}" -eq 0 ]]; then
    echo "No configured hosts detected (checked global config paths)." >&2
    exit 1
  fi
  for h in "${detected[@]}"; do
    run_for_host "$h" || rc=1
    echo ""
  done
  exit "$rc"
fi

if [[ "$HOST" == "all" ]]; then
  APPLY_ALL=1
  mapfile -t detected < <(ga_detect_configured_hosts)
  if [[ "${#detected[@]}" -eq 0 ]]; then
    echo "No configured hosts detected." >&2
    exit 1
  fi
  rc=0
  for h in "${detected[@]}"; do
    run_for_host "$h" || rc=1
    echo ""
  done
  exit "$rc"
fi

ga_validate_host "$HOST" || {
  echo "Unsupported host: $HOST (use: ${GA_SUPPORTED_HOSTS})" >&2
  exit 2
}

run_for_host "$HOST"
