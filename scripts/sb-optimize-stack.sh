#!/usr/bin/env bash
# sb-optimize-stack.sh — apply/verify/report Graphify + agentmemory synergy_max optimization.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB="${REPO_ROOT}/hooks/lib/stack-optimizer.sh"

MODE="apply"
DRY_RUN=0
HOST_OVERRIDE=""

usage() {
  cat <<'EOF'
Usage: bash scripts/sb-optimize-stack.sh [--apply|--verify|--report] [--dry-run] [--host HOST]

Applies or verifies the synergy_max Graphify + agentmemory optimization profile
when both tools are opted in via recommended_tools.*.enabled_by_user.

Options:
  --apply     Idempotent optimize (default)
  --verify    Scorecard only; exit 1 on critical gaps when opted in
  --report    Markdown summary to stdout
  --dry-run   Print actions without mutating host/project files
  --host HOST Override runtime host (claude|codex|cursor|opencode|goose|hermes)
  -h, --help  Show help

Skips host-level hooks when CI=true. See docs/STACK-OPTIMIZATION.md.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) MODE="apply" ;;
    --verify) MODE="verify" ;;
    --report) MODE="report" ;;
    --dry-run) DRY_RUN=1; export SB_STACK_OPTIMIZER_DRY_RUN=1 ;;
    --host)
      shift
      HOST_OVERRIDE="${1:-}"
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# shellcheck source=../hooks/lib/stack-optimizer.sh
source "$LIB"

CONFIG="${REPO_ROOT}/.silver-bullet.json"
[[ -f "$CONFIG" ]] || CONFIG="${REPO_ROOT}/templates/silver-bullet.config.json.default"

if [[ -n "$HOST_OVERRIDE" ]]; then
  export SILVER_BULLET_RUNTIME="$HOST_OVERRIDE"
fi
HOST="$(sb_runtime_host)"
PROFILE="$(sb_stack_optimization_profile_name "$CONFIG")"

run_apply() {
  printf '== SB stack optimize (profile=%s, host=%s) ==\n' "$PROFILE" "$HOST"
  sb_optimize_graphify "$REPO_ROOT" "$CONFIG" "$HOST"
  sb_optimize_agentmemory "$REPO_ROOT" "$CONFIG" "$HOST"
  sb_optimize_synergy "$REPO_ROOT" "$CONFIG"
  local score
  score="$(sb_optimization_score "$REPO_ROOT" "$CONFIG")"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    sb_stack_update_config_timestamps "$CONFIG" apply "$score"
  fi
  printf 'Optimization score: %s/100 (fails=%s warns=%s)\n' "$score" "${SB_STACK_SCORE_FAILS:-0}" "${SB_STACK_SCORE_WARNS:-0}"
  [[ "${SB_STACK_SCORE_FAILS:-0}" -eq 0 ]]
}

run_verify() {
  local score
  score="$(sb_optimization_score "$REPO_ROOT" "$CONFIG")"
  if [[ "$DRY_RUN" -eq 0 && -f "${REPO_ROOT}/.silver-bullet.json" ]]; then
    sb_stack_update_config_timestamps "${REPO_ROOT}/.silver-bullet.json" verify "$score"
  fi
  printf '== Stack optimization verify (profile=%s) ==\n' "$PROFILE"
  printf 'Score: %s/100 | fails=%s warns=%s\n' "$score" "${SB_STACK_SCORE_FAILS:-0}" "${SB_STACK_SCORE_WARNS:-0}"
  printf '%b' "${SB_STACK_SCORE_REPORT:-}"
  if [[ "$(sb_recommended_tool_consent "$CONFIG" graphify)" == "enabled" \
     || "$(sb_recommended_tool_consent "$CONFIG" agentmemory)" == "enabled" ]]; then
    [[ "${SB_STACK_SCORE_FAILS:-0}" -eq 0 ]]
  fi
  return 0
}

run_report() {
  local score verdict
  score="$(sb_optimization_score "$REPO_ROOT" "$CONFIG")"
  if [[ "$score" -ge 85 && "${SB_STACK_SCORE_FAILS:-0}" -eq 0 ]]; then
    verdict="OPTIMAL"
  elif [[ "$score" -ge 60 && "${SB_STACK_SCORE_FAILS:-0}" -eq 0 ]]; then
    verdict="ACCEPTABLE"
  else
    verdict="NEEDS_WORK"
  fi
  cat <<EOF
# Stack Optimization Report

- **Profile:** ${PROFILE}
- **Host:** ${HOST}
- **Score:** ${score}/100
- **Verdict:** ${verdict}
- **Fails:** ${SB_STACK_SCORE_FAILS:-0}
- **Warnings:** ${SB_STACK_SCORE_WARNS:-0}

## Checks

$(printf '%b' "${SB_STACK_SCORE_REPORT:-}" | sed 's/|/ | /g')

## Next steps

Run \`bash scripts/sb-optimize-stack.sh --apply\` to remediate gaps.
See \`docs/STACK-OPTIMIZATION.md\` and \`docs/research/graphify-agentmemory-optimization.md\`.
EOF
}

case "$MODE" in
  apply) run_apply ;;
  verify) run_verify ;;
  report) run_report ;;
esac
