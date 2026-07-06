#!/usr/bin/env bash
# Bootstrap SB orchestrator runtime evidence for tri-criteria E2E tracks.
# FIXTURE PREP ONLY — blocked for proof runs unless SB_TRI_CRITERIA_ALLOW_BOOTSTRAP=1.
set -euo pipefail

if [[ "${SB_TRI_CRITERIA_ALLOW_BOOTSTRAP:-}" != "1" ]]; then
  echo "ERROR: bootstrap-orchestrator.sh blocked for cold proof runs." >&2
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
for f in runtime-paths.sh orchestrator-state.sh orchestrator-scheduler.sh orchestrator-event-log.sh orchestrator-directive.sh orchestrator-parent.sh; do
  # shellcheck source=/dev/null
  [[ -f "${LIB}/${f}" ]] && source "${LIB}/${f}"
done

intent=""
if [[ -n "$INTENT_FILE" && -f "$INTENT_FILE" ]]; then
  intent="$(tr '\n' ' ' <"$INTENT_FILE" | sed 's/  */ /g')"
fi
printf '%s\n' "$intent" >"${SB_RUNTIME_STATE_DIR}/orchestrator-intent.txt"

# Fresh session state per track
rm -f "${SB_RUNTIME_STATE_DIR}/orchestrator.json" \
  "${SB_RUNTIME_STATE_DIR}/orchestrator-events.jsonl" \
  "${SB_RUNTIME_STATE_DIR}/orchestrator-directive.json" 2>/dev/null || true
: >"${WORK_DIR}/.planning/orchestrator-composition-log.jsonl"

chain_composers() {
  local composer wid
  for composer in "$@"; do
    wid="$(sb_orchestrator_on_composer_start "$composer" "$intent" "$WORK_DIR" 2>/dev/null || true)"
    if declare -f sb_orchestrator_event_record_dispatch >/dev/null 2>&1; then
      sb_orchestrator_event_record_dispatch "AF-ORCH" "$composer" "${composer}" 0 2>/dev/null || true
    fi
    if declare -f sb_orchestrator_event_record_advance >/dev/null 2>&1; then
      sb_orchestrator_event_record_advance "$composer" "next-workflow" false 2>/dev/null || true
    fi
    echo "composer_start: $composer workflow_id=${wid:-unknown}"
  done
}

case "$TRACK" in
  TC-01)
    chain_composers silver-feature silver-devops silver-release
    if declare -f sb_scheduler_record_composition_operation >/dev/null 2>&1; then
      sb_scheduler_record_composition_operation "$WORK_DIR" "WF-SILVER-FEATURE" "insert" "WF-SILVER-DEVOPS" "DR-INSERT-POST-FEATURE-DEVOPS" "greenfield waitlist requires runtime packaging after feature delivery" 2>/dev/null || true
      sb_scheduler_record_composition_operation "$WORK_DIR" "WF-SILVER-DEVOPS" "insert" "WF-SILVER-RELEASE" "DR-INSERT-PRE-SHIP-RELEASE" "ship readiness gate after containerization" 2>/dev/null || true
    fi
    ;;
  TC-02)
    chain_composers silver-feature
    if declare -f sb_scheduler_record_composition_operation >/dev/null 2>&1; then
      sb_scheduler_record_composition_operation "$WORK_DIR" "WF-SILVER-FEATURE" "substitute" "WF-SILVER-FAST" "DR-SUBSTITUTE-LEANER-WORKFLOW" "README badge is documentation-only; substitute lean fast path" 2>/dev/null || true
      sb_scheduler_record_composition_operation "$WORK_DIR" "WF-SILVER-FAST" "prune" "AF-UI" "DR-PRUNE-SATISFIED-ATOM" "no UI atoms required for shields.io badge" 2>/dev/null || true
    fi
    if declare -f sb_orchestrator_event_record_dispatch >/dev/null 2>&1; then
      sb_orchestrator_event_append "dispatch" '{"worker_template":"FAST-DOC","skill":"silver-fast","workflow_id":"WF-SILVER-FAST"}' 2>/dev/null || true
    fi
    ;;
  TC-03)
    if declare -f sb_orchestrator_event_record_dispatch >/dev/null 2>&1; then
      sb_orchestrator_event_append "dispatch" '{"worker_template":"NEW-WORKFLOW","skill":"silver-new-workflow","workflow_id":"WF-COMPLIANCE-SNAPSHOT"}' 2>/dev/null || true
    fi
    chain_composers silver-new-workflow
    ;;
  *)
    echo "Unknown track: $TRACK" >&2
    exit 2
    ;;
esac

echo "SB_RUNTIME_STATE_DIR=$SB_RUNTIME_STATE_DIR"
echo "composition_log=${WORK_DIR}/.planning/orchestrator-composition-log.jsonl"
echo "events=${SB_RUNTIME_STATE_DIR}/orchestrator-events.jsonl"
wc -l "${WORK_DIR}/.planning/orchestrator-composition-log.jsonl" 2>/dev/null || true
wc -l "${SB_RUNTIME_STATE_DIR}/orchestrator-events.jsonl" 2>/dev/null || true
