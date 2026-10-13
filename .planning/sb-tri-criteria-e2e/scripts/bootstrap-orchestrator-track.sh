#!/usr/bin/env bash
# Bootstrap SB orchestrator runtime evidence for tri-criteria E2E tracks.
# FIXTURE PREP ONLY — blocked for proof runs unless SB_TRI_CRITERIA_ALLOW_BOOTSTRAP=1.
set -euo pipefail

if [[ "${SB_TRI_CRITERIA_ALLOW_BOOTSTRAP:-}" != "1" ]]; then
  echo "ERROR: bootstrap-orchestrator-track.sh blocked for cold proof runs." >&2
  echo "Use: .planning/sb-tri-criteria-e2e/scripts/cold-verify-track.sh" >&2
  echo "Or set SB_TRI_CRITERIA_ALLOW_BOOTSTRAP=1 for explicit fixture prep only." >&2
  exit 3
fi

TRACK="${1:-TC-01}"
WORK_DIR="${2:-/Users/shafqat/projects/enterprise-grade-test-app}"
SB_ROOT="${SB_ROOT:-/Users/shafqat/projects/silver-bullet/repo}"
RUN_ID="${3:-}"
INTENT_FILE="${4:-}"

export SB_RUNTIME_STATE_DIR="${SB_RUNTIME_STATE_DIR:-${HOME}/.cursor/.silver-bullet/tri-criteria-${TRACK}}"
mkdir -p "$SB_RUNTIME_STATE_DIR" "${WORK_DIR}/.planning"

LIB="${SB_ROOT}/hooks/lib"
for f in orchestrator-state.sh orchestrator-scheduler.sh orchestrator-event-log.sh orchestrator-directive.sh orchestrator-parent.sh; do
  # shellcheck source=/dev/null
  source "${LIB}/${f}"
done

sb_orchestrator_clear_queue 2>/dev/null || true
: >"${SB_RUNTIME_STATE_DIR}/orchestrator-events.jsonl"

intent=""
if [[ -n "$INTENT_FILE" && -f "$INTENT_FILE" ]]; then
  intent="$(tr '\n' ' ' <"$INTENT_FILE" | sed 's/[[:space:]]\+/ /g')"
fi
printf '%s\n' "$intent" >"${SB_RUNTIME_STATE_DIR}/orchestrator-intent.txt"

bootstrap_composer() {
  local skill="$1" catalog_wf="$2"
  local wid
  wid="$(sb_orchestrator_on_composer_start "$skill" "$intent" "$WORK_DIR" 2>/dev/null || true)"
  sb_orchestrator_event_record_dispatch "AF-EXECUTE" "$skill" "$(sb_orchestrator_worker_template_for_skill "$skill" 2>/dev/null || echo EXECUTE)" 0 2>/dev/null || true
  sb_orchestrator_event_append "dispatch" "$(jq -nc --arg wf "$catalog_wf" --arg skill "$skill" --arg wid "${wid:-}" \
    '{workflow_id: $wf, selected_workflow: $wf, skill: $skill, instance_workflow_id: $wid}')" 2>/dev/null || true
  sb_orchestrator_event_record_advance "$skill" "$(jq -r '.current_flow // ""' "$(sb_orchestrator_state_file)")" false 2>/dev/null || true
  printf '%s\n' "$wid"
}

case "$TRACK" in
  TC-01)
    bootstrap_composer silver-feature WF-SILVER-FEATURE
    bootstrap_composer silver-devops WF-SILVER-DEVOPS
    bootstrap_composer silver-release WF-SILVER-RELEASE
  ;;
  TC-02)
    bootstrap_composer silver-fast WF-SILVER-FAST
    sb_scheduler_record_composition_operation "$WORK_DIR" WF-SILVER-FAST substitute WF-SILVER-FEATURE DR-SUBSTITUTE-LEANER-WORKFLOW "README badge is documentation-only; substitute leaner workflow" 2>/dev/null || true
    sb_scheduler_record_composition_operation "$WORK_DIR" WF-SILVER-FAST prune AF-PLAN DR-PRUNE-SATISFIED-ATOM "No planning atoms required for shields.io badge" 2>/dev/null || true
  ;;
  TC-03)
    bootstrap_composer silver-new-workflow WF-SILVER-NEW-WORKFLOW
    sb_orchestrator_event_append "dispatch" '{"worker_template":"NEW-WORKFLOW","skill":"silver-new-workflow","workflow_id":"WF-SILVER-NEW-WORKFLOW"}' 2>/dev/null || true
  ;;
esac

echo "orchestrator_state=${SB_RUNTIME_STATE_DIR}/orchestrator.json"
echo "events=${SB_RUNTIME_STATE_DIR}/orchestrator-events.jsonl"
echo "composition_log=${WORK_DIR}/.planning/orchestrator-composition-log.jsonl"
