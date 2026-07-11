#!/usr/bin/env bash
# enable-rtk-context-mode.sh — verify RTK and/or Context Mode install + wiring.
# Adapted from token-compression setup runbook Step 5.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="all"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool) TOOL="${2:-all}"; shift 2 ;;
    -h|--help)
      cat <<'EOF'
Usage: bash scripts/enable-rtk-context-mode.sh [--tool rtk|context_mode|all]

Verifies RTK and/or Context Mode CLI, host wiring, and instruction fragment.
Exit non-zero on hard failures — used by /silver:init and sb-diagnostics.sh.
EOF
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

_lib="${REPO_ROOT}/hooks/lib"
# shellcheck source=/dev/null
[[ -f "$_lib/recommended-tools.sh" ]] && source "$_lib/recommended-tools.sh"
# shellcheck source=/dev/null
[[ -f "$_lib/rtk-gate.sh" ]] && source "$_lib/rtk-gate.sh"
# shellcheck source=/dev/null
[[ -f "$_lib/context-mode-gate.sh" ]] && source "$_lib/context-mode-gate.sh"

pass=0
fail=0
warn=0

ok()   { echo "  [x] $1"; pass=$((pass + 1)); }
err()  { echo "  [ ] $1 — $2"; fail=$((fail + 1)); }
hint() { echo "  [!] $1 — $2"; warn=$((warn + 1)); }

check_rtk() {
  echo "RTK:"
  if sb_rtk_cli_available 2>/dev/null; then
    ok "binary present: $(sb_rtk_version_string 2>/dev/null || echo rtk)"
  elif sb_rtk_cli_path >/dev/null 2>&1; then
    err "wrong rtk binary on PATH" "install rtk-ai/rtk; rtk gain --help must succeed"
  else
    err "rtk not on PATH" "brew tap rtk-ai/rtk && brew install rtk"
  fi

  if sb_rtk_version_ok "${REPO_ROOT}/.silver-bullet.json" 2>/dev/null; then
    ok "version OK (v0.4x)"
  elif sb_rtk_cli_available 2>/dev/null; then
    err "version too old" "upgrade to rtk >= 0.42.0"
  fi

  local host artifact
  host="$(sb_runtime_host 2>/dev/null || echo cursor)"
  artifact="$(sb_rtk_platform_hook_artifact_path "$REPO_ROOT" "$host" 2>/dev/null || true)"
  if sb_rtk_platform_hook_present "$REPO_ROOT" "$host" 2>/dev/null; then
    ok "host hook wired (${host}: ${artifact})"
  else
    err "host hook missing (${host})" "run rtk init for host — see docs/RTK.md"
  fi
  echo ""
}

check_context_mode() {
  echo "Context Mode:"
  if sb_context_mode_node_ok "${REPO_ROOT}/.silver-bullet.json" 2>/dev/null; then
    ok "Node $(node --version 2>/dev/null | sed 's/^v//') (>= 22.5)"
  else
    err "Node too old or missing" "upgrade to Node >= 22.5"
  fi

  if sb_context_mode_cli_available 2>/dev/null; then
    ok "CLI or Claude plugin present"
  else
    err "context-mode not installed" "npm install -g context-mode or Claude plugin"
  fi

  local host artifact
  host="$(sb_runtime_host 2>/dev/null || echo cursor)"
  artifact="$(sb_context_mode_platform_artifact_path "$REPO_ROOT" "$host" 2>/dev/null || true)"
  if sb_context_mode_platform_artifact_present "$REPO_ROOT" "$host" 2>/dev/null; then
    ok "platform artifact (${host}: ${artifact})"
  else
    err "MCP/plugin not wired (${host})" "see docs/CONTEXT-MODE.md"
  fi

  if sb_context_mode_instruction_fragment_present "$REPO_ROOT" 2>/dev/null; then
    ok "instruction fragment in project docs"
  else
    hint "instruction fragment missing" "run /silver:init scaffold or append templates/context-mode-hint.md.base"
  fi
  echo ""
}

echo "=== RTK + Context Mode verification (repo: ${REPO_ROOT}) ==="
echo ""

case "$TOOL" in
  rtk) check_rtk ;;
  context_mode) check_context_mode ;;
  all)
    check_rtk
    check_context_mode
    ;;
  *)
    echo "Invalid --tool: $TOOL (use rtk|context_mode|all)" >&2
    exit 2
    ;;
esac

echo "=== Summary: $pass passed, $fail failed, $warn hints ==="
if [[ "$fail" -gt 0 ]]; then
  echo "Some checks failed. Resolve [ ] lines and re-run." >&2
  exit 1
fi
exit 0
