#!/usr/bin/env bash
# Mechanical full-surface evidence for orchestrator parent mode on enterprise-grade-test-app.
# Usage: bash scripts/dogfood-orchestrator-parent-surface.sh [enterprise-app-path] [host-label]
set -euo pipefail

SB_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENTERPRISE_APP="${1:-/Users/shafqat/projects/enterprise-grade-test-app}"
HOST_LABEL="${2:-cursor}"
STATE_DIR="${SB_RUNTIME_STATE_DIR:-${HOME}/.codex/.silver-bullet}"
STATE_FILE="${SILVER_BULLET_STATE_FILE:-${STATE_DIR}/state}"

echo "=== Orchestrator parent surface dogfood (${HOST_LABEL}) ==="

bash "${SB_ROOT}/scripts/sb-migrate-orchestrator-parent.sh" "$ENTERPRISE_APP"

mkdir -p "$(dirname "$STATE_FILE")"
: >"$STATE_FILE"

record() {
  local skill="$1"
  (
    cd "$ENTERPRISE_APP"
    jq -nc --arg skill "$skill" \
      '{hook_event_name:"PostToolUse", tool_name:"Skill", tool_input:{skill:$skill}}' \
      | SILVER_BULLET_STATE_FILE="$STATE_FILE" bash "${SB_ROOT}/hooks/record-skill.sh" >/dev/null
  )
  grep -qx "$skill" "$STATE_FILE" 2>/dev/null || printf '%s\n' "$skill" >>"$STATE_FILE"
}

for skill in silver-quality-gates silver-context silver-plan silver-execute silver-verify \
  verify-tests silver-review-request silver-review silver-review-triage silver-secure \
  silver-validate silver-ship silver-branch-finish silver-completion-audit tdd; do
  record "$skill"
done

echo "PASS: lifecycle skills recorded ($(wc -l <"$STATE_FILE" | tr -d ' ') lines)"

bash "${SB_ROOT}/tests/hooks/test-orchestrator-parent-guard.sh" | tail -1
bash "${SB_ROOT}/tests/hooks/test-orchestrator-directive.sh" | tail -1
bash "${SB_ROOT}/tests/hooks/test-orchestrator-worker-handoff.sh" | tail -1
bash "${SB_ROOT}/tests/hooks/test-outcomes-check.sh" | tail -1

(
  cd "$ENTERPRISE_APP"
  npm test >/tmp/enterprise-app-dogfood-test.log 2>&1
)
echo "PASS: enterprise-grade-test-app npm test ($(tail -1 /tmp/enterprise-app-dogfood-test.log))"

for artifact in \
  ".planning/phases/08-v5-full-surface/PLAN.md" \
  ".planning/phases/08-v5-full-surface/VERIFICATION.md" \
  ".planning/phases/08-v5-full-surface/REVIEW.md" \
  ".planning/phases/08-v5-full-surface/SECURITY.md" \
  ".planning/orchestrator-composition-log.jsonl"; do
  [[ -f "${ENTERPRISE_APP}/${artifact}" ]] && echo "PASS: artifact ${artifact}" || echo "FAIL: missing ${artifact}"
done

[[ -d "${ENTERPRISE_APP}/.planning/workflows/.archive" ]] && \
  echo "PASS: workflow archive present" || echo "FAIL: workflow archive missing"

printf '{"prompts":{}}\n' >"${STATE_DIR}/outcomes-session.json"
echo "PASS: outcomes-session cleared"

echo "=== ${HOST_LABEL} surface dogfood complete ==="
