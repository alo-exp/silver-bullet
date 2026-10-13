#!/usr/bin/env bash
# sb-verify-synergy.sh — non-destructive Graphify + agentmemory synergy audit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB="${REPO_ROOT}/hooks/lib/stack-optimizer.sh"
WRITE_SETUP_REPORT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --write-setup-report) WRITE_SETUP_REPORT=1 ;;
    -h|--help)
      echo "Usage: bash scripts/sb-verify-synergy.sh [--write-setup-report]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

# shellcheck source=../hooks/lib/stack-optimizer.sh
source "$LIB"

CONFIG="${REPO_ROOT}/.silver-bullet.json"
[[ -f "$CONFIG" ]] || { echo "FAIL: .silver-bullet.json missing" >&2; exit 1; }

score="$(sb_optimization_score "$REPO_ROOT" "$CONFIG")"
verdict="NEEDS_WORK"
if [[ "$score" -ge 85 && "${SB_STACK_SCORE_FAILS:-0}" -eq 0 ]]; then
  verdict="OPTIMAL"
elif [[ "$score" -ge 60 && "${SB_STACK_SCORE_FAILS:-0}" -eq 0 ]]; then
  verdict="ACCEPTABLE"
fi

echo "Synergy audit verdict: ${verdict} (score=${score}/100, fails=${SB_STACK_SCORE_FAILS:-0}, warns=${SB_STACK_SCORE_WARNS:-0})"
printf '%b' "${SB_STACK_SCORE_REPORT:-}"

if [[ "$WRITE_SETUP_REPORT" -eq 1 ]]; then
  section_file="${REPO_ROOT}/SETUP_REPORT.md"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  {
    echo ""
    echo "## Optimization verification addendum (${ts})"
    echo ""
    echo "| Metric | Value |"
    echo "|--------|-------|"
    echo "| Verdict | ${verdict} |"
    echo "| Score | ${score}/100 |"
    echo "| Fails | ${SB_STACK_SCORE_FAILS:-0} |"
    echo "| Warnings | ${SB_STACK_SCORE_WARNS:-0} |"
    echo ""
    echo "Re-run: \`bash scripts/sb-verify-synergy.sh\`"
  } >>"$section_file"
  echo "Appended addendum to SETUP_REPORT.md"
fi

[[ "${SB_STACK_SCORE_FAILS:-0}" -eq 0 ]]
