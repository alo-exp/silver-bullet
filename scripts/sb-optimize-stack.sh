#!/usr/bin/env bash
# sb-optimize-stack.sh — apply/verify/report Graphify + agentmemory synergy_max optimization.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# One backup per run: sb_host_config keeps the user's file as it was before the run's first change.
export SB_INSTALL_RUN_START="${SB_INSTALL_RUN_START:-$(date +%s)}"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB="${REPO_ROOT}/hooks/lib/stack-optimizer.sh"
# REPO_ROOT is Silver Bullet itself (its libraries and templates). The project being optimized
# is PROJECT_ROOT: --project-root, else the git top level of the working directory, else the
# working directory.
PROJECT_ROOT=""

MODE="apply"
DRY_RUN=0
HOST_OVERRIDE=""

usage() {
  cat <<'EOF'
Usage: bash scripts/sb-optimize-stack.sh [--apply|--verify|--report] [--dry-run] [--host HOST] [--project-root DIR]

Applies or verifies the synergy_max Graphify + agentmemory optimization profile
when both tools are opted in via recommended_tools.*.enabled_by_user.

Options:
  --apply     Idempotent optimize (default)
  --verify    Scorecard only; exit 1 on critical gaps when opted in
  --report    Markdown summary to stdout
  --dry-run   Print actions without mutating host/project files
  --host HOST Override runtime host (claude|codex|cursor|opencode|pi|goose|hermes)
  --project-root DIR  Project to optimize (default: git top level of the current directory)
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
      # A trailing --host has no value; a bare `shift` would abort under set -e.
      if [[ $# -lt 2 ]]; then echo "--host requires a value" >&2; usage >&2; exit 2; fi
      shift
      HOST_OVERRIDE="$1"
      ;;
    --project-root)
      if [[ $# -lt 2 ]]; then echo "--project-root requires a value" >&2; usage >&2; exit 2; fi
      shift
      PROJECT_ROOT="$1"
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# shellcheck source=../hooks/lib/stack-optimizer.sh
source "$LIB"

if [[ -z "$PROJECT_ROOT" ]]; then
  PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
_requested_root="$PROJECT_ROOT"
PROJECT_ROOT="$(cd -- "$_requested_root" 2>/dev/null && pwd -P)" || {
  echo "Not a directory: ${_requested_root}" >&2
  exit 2
}
# Silver Bullet's own directory is not a project: refuse it rather than rewrite the bundled config
# (or append SETUP_REPORT.md there). Developing Silver Bullet itself sets SB_ALLOW_PLUGIN_ROOT=1.
if [[ "$PROJECT_ROOT" == "$(cd "$REPO_ROOT" && pwd -P)" && "${SB_ALLOW_PLUGIN_ROOT:-0}" != "1" ]]; then
  echo "Refusing to run against the Silver Bullet plugin directory (${PROJECT_ROOT}): run it from your project or pass --project-root DIR." >&2
  exit 2
fi
# The project's own file is the only config that is ever written; without one the bundled
# template is read-only defaults.
PROJECT_CONFIG="${PROJECT_ROOT}/.silver-bullet.json"
CONFIG="$PROJECT_CONFIG"
[[ -f "$CONFIG" ]] || CONFIG="${REPO_ROOT}/templates/silver-bullet.config.json.default"

if [[ -n "$HOST_OVERRIDE" ]]; then
  export SILVER_BULLET_RUNTIME="$HOST_OVERRIDE"
fi
HOST="$(sb_runtime_host)"
PROFILE="$(sb_stack_optimization_profile_name "$CONFIG")"

run_apply() {
  printf '== SB stack optimize (profile=%s, host=%s) ==\n' "$PROFILE" "$HOST"
  sb_optimize_graphify "$PROJECT_ROOT" "$CONFIG" "$HOST"
  sb_optimize_agentmemory "$PROJECT_ROOT" "$CONFIG" "$HOST"
  sb_optimize_synergy "$PROJECT_ROOT" "$CONFIG"
  local score
  # Run in this shell (not a command substitution) so the SB_STACK_SCORE_* exports survive.
  sb_optimization_score "$PROJECT_ROOT" "$CONFIG" >/dev/null
  score="$SB_STACK_SCORE"
  if [[ "$DRY_RUN" -eq 0 && -f "$PROJECT_CONFIG" ]]; then
    sb_stack_update_config_timestamps "$PROJECT_CONFIG" apply "$score"
  fi
  printf 'Optimization score: %s/100 (fails=%s warns=%s)\n' "$score" "${SB_STACK_SCORE_FAILS:-0}" "${SB_STACK_SCORE_WARNS:-0}"
  [[ "${SB_STACK_SCORE_FAILS:-0}" -eq 0 ]]
}

run_verify() {
  local score
  # Run in this shell (not a command substitution) so the SB_STACK_SCORE_* exports survive.
  sb_optimization_score "$PROJECT_ROOT" "$CONFIG" >/dev/null
  score="$SB_STACK_SCORE"
  if [[ "$DRY_RUN" -eq 0 && -f "$PROJECT_CONFIG" ]]; then
    sb_stack_update_config_timestamps "$PROJECT_CONFIG" verify "$score"
  fi
  printf '== Stack optimization verify (profile=%s) ==\n' "$PROFILE"
  printf 'Score: %s/100 | fails=%s warns=%s\n' "$score" "${SB_STACK_SCORE_FAILS:-0}" "${SB_STACK_SCORE_WARNS:-0}"
  printf '%b' "${SB_STACK_SCORE_REPORT:-}"
  if [[ "$(sb_recommended_tool_consent "$CONFIG" graphify)" == "enabled" \
     || "$(sb_recommended_tool_consent "$CONFIG" agentmemory)" == "enabled" ]]; then
    # "enabled" is the user's own enforce consent (docs/CONSENT.md), never the project file's.
    [[ "${SB_STACK_SCORE_FAILS:-0}" -eq 0 ]]
  fi
  return 0
}

run_report() {
  local score verdict
  # Run in this shell (not a command substitution) so the SB_STACK_SCORE_* exports survive.
  sb_optimization_score "$PROJECT_ROOT" "$CONFIG" >/dev/null
  score="$SB_STACK_SCORE"
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
