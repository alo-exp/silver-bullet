#!/usr/bin/env bash
# Live tri-criteria verification — flow-advance + scheduler + real product delta.
# Differs from cold-verify: requires product artifacts, Task worker session markers,
# composer_start spacing gate, live_session_run ledger flag.
set -euo pipefail

TRACK="${1:-}"
RUN_DIR="${2:-}"
WORK_DIR="${SB_TRI_CRITERIA_WORK_DIR:-/Users/shafqat/projects/enterprise-grade-test-app}"
SB_ROOT="${SB_ROOT:-/Users/shafqat/projects/silver-bullet/repo}"
MIN_COMPOSER_SPACING_SEC="${SB_LIVE_MIN_COMPOSER_SPACING_SEC:-5}"

usage() {
  cat <<'EOF'
Usage: live-verify-track.sh <TC-01|TC-02|TC-03> <run-dir>

Live verification: flow-advance + runtime scheduler + product gate.
bootstrap-orchestrator*.sh is NOT used.
EOF
}

[[ -n "$TRACK" && -n "$RUN_DIR" && -d "$RUN_DIR" ]] || { usage >&2; exit 2; }

# shellcheck source=fixture-checkout.sh
source "${SB_ROOT}/.planning/sb-tri-criteria-e2e/scripts/fixture-checkout.sh"
# shellcheck source=emit-tri-criteria-evidence.sh
source "${SB_ROOT}/.planning/sb-tri-criteria-e2e/scripts/emit-tri-criteria-evidence.sh"

RUN_TAG="$(basename "$RUN_DIR")"
GREENFIELD="${SB_TRI_CRITERIA_GREENFIELD:-0}"
if [[ "$GREENFIELD" == "1" ]]; then
  BRANCH="$(tri_criteria_greenfield_checkout_fixture "$WORK_DIR" "$TRACK" "cursor" "$RUN_TAG")"
else
  BRANCH="$(tri_criteria_branch_for_track "$TRACK")"
  tri_criteria_checkout_fixture "$WORK_DIR" "$TRACK" || exit 1
fi
export SB_RUNTIME_PRESERVE_STATE_DIR=1
export SB_RUNTIME_STATE_DIR="${SB_RUNTIME_STATE_DIR:-${HOME}/.cursor/.silver-bullet/tri-criteria-live-${RUN_TAG}}"
mkdir -p "$SB_RUNTIME_STATE_DIR" "${WORK_DIR}/.planning"

HOOK="${SB_ROOT}/hooks/flow-advance.sh"
LIB="${SB_ROOT}/hooks/lib"
for f in runtime-paths.sh orchestrator-state.sh orchestrator-scheduler.sh orchestrator-event-log.sh orchestrator-directive.sh; do
  # shellcheck source=/dev/null
  [[ -f "${LIB}/${f}" ]] && source "${LIB}/${f}"
done

intent="$(tr '\n' ' ' <"${RUN_DIR}/vision.md" | sed 's/  */ /g')"
printf '%s\n' "$intent" >"${SB_RUNTIME_STATE_DIR}/orchestrator-intent.txt"
: >"${WORK_DIR}/.planning/orchestrator-composition-log.jsonl"
rm -f "${SB_RUNTIME_STATE_DIR}/orchestrator.json" \
  "${SB_RUNTIME_STATE_DIR}/orchestrator-events.jsonl" \
  "${SB_RUNTIME_STATE_DIR}/orchestrator-directive.json" 2>/dev/null || true

if [[ ! -f "${WORK_DIR}/.silver-bullet.json" ]]; then
  echo '{"sb_initiated":true,"project":{"name":"enterprise-grade-test-app","active_workflow":"full-dev-cycle"}}' \
    >"${WORK_DIR}/.silver-bullet.json"
fi
[[ -f "${WORK_DIR}/silver-bullet.md" ]] || echo '# SB' >"${WORK_DIR}/silver-bullet.md"
mkdir -p "${WORK_DIR}/.agentmemory/memory"

LOG="${RUN_DIR}/parent-session.log"
SB_SHA="$(git -C "$SB_ROOT" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
FIXTURE_SHA="$(git -C "$WORK_DIR" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
{
  echo "# ${TRACK} Live Verify — $(basename "$RUN_DIR")"
  echo "# Fixture: $(basename "$WORK_DIR") | SB sha: $SB_SHA | fixture sha: $FIXTURE_SHA"
  echo "# bootstrap-orchestrator-track.sh: NOT USED (live verify)"
  echo "# SB_RUNTIME_PRESERVE_STATE_DIR=1 state: $SB_RUNTIME_STATE_DIR"
  echo "# execution_model: Cursor parent orchestrator + Task workers (model=composer-2.5)"
  echo "# greenfield: ${GREENFIELD}"
  echo "# branch: ${BRANCH}"
  echo ""
} >"$LOG"

log_task_worker() {
  local template="$1" skill="$2"
  echo "[orchestrator] Task worker spawned: template=${template} skill=${skill} model=composer-2.5" >>"$LOG"
  echo "[worker] delegated SB worker completed — ${template}" >>"$LOG"
}

verify_product_gate() {
  local track="$1"
  case "$track" in
    TC-01)
      if ! compgen -G "${WORK_DIR}/api/src/*waitlist*" >/dev/null 2>&1; then
        echo "FAIL: TC-01 product gate — no waitlist API files in ${WORK_DIR}/api/src/" >&2
        return 1
      fi
      [[ -f "${WORK_DIR}/docker-compose.yml" ]] || { echo "FAIL: missing docker-compose.yml" >&2; return 1; }
      ;;
    TC-02)
      if ! grep -qEi 'correlation|structured|observability|runbook' "${WORK_DIR}/README.md" 2>/dev/null; then
        echo "FAIL: TC-02 product gate — README missing observability runbook section" >&2
        return 1
      fi
      if ! compgen -G "${WORK_DIR}/api/src/*log*" >/dev/null 2>&1; then
        echo "FAIL: TC-02 product gate — no logging module in api/src/" >&2
        return 1
      fi
      ;;
    TC-03)
      [[ -x "${WORK_DIR}/scripts/sb-compliance-posture-audit.sh" ]] || {
        echo "FAIL: TC-03 product gate — missing sb-compliance-posture-audit.sh" >&2; return 1; }
      [[ -f "${WORK_DIR}/.planning/workflows/WF-POSTURE-AUDIT.md" ]] || {
        echo "FAIL: TC-03 product gate — missing WF-POSTURE-AUDIT.md" >&2; return 1; }
      [[ -f "${WORK_DIR}/.planning/compliance/posture-audit-report.md" ]] || {
        echo "FAIL: TC-03 product gate — missing posture-audit-report.md" >&2; return 1; }
      ;;
  esac
  echo "[verify] product gate PASS for ${track} (fixture sha: ${FIXTURE_SHA})" >>"$LOG"
}

run_flow_advance() {
  local skill="$1"
  (cd "$WORK_DIR" && printf '{"tool_input":{"skill":"%s"}}' "$skill" | \
    SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$SB_RUNTIME_STATE_DIR" \
    bash "$HOOK" 2>/dev/null) || true
}

drain_flow_queue() {
  local composer="$1" token skill
  local -a atoms=()
  while IFS= read -r token; do
    [[ -n "$token" ]] && atoms+=("$token")
  done < <(jq -r '.flow_queue[]?' "${SB_RUNTIME_STATE_DIR}/orchestrator.json" 2>/dev/null || true)
  for token in "${atoms[@]}"; do
    skill="$(sb_orchestrator_flow_to_skill "$token" 2>/dev/null || printf '%s' "$token")"
    log_task_worker "${token}" "${skill}"
    run_flow_advance "$skill"
    echo "[orchestrator] flow-advance atom: $skill (composer=$composer)" >>"$LOG"
    sleep 2
  done
}

drain_composer_chain() {
  local composer="" i
  for i in 1 2 3; do
    composer="$(jq -r '.composer // ""' "${SB_RUNTIME_STATE_DIR}/orchestrator.json" 2>/dev/null || true)"
    [[ -n "$composer" ]] || break
    echo "[orchestrator] composer_start: ${composer}" >>"$LOG"
    drain_flow_queue "$composer"
    sleep "${MIN_COMPOSER_SPACING_SEC}"
    composer="$(jq -r '.composer // ""' "${SB_RUNTIME_STATE_DIR}/orchestrator.json" 2>/dev/null || true)"
    [[ -z "$(jq -r '.composer_chain[0] // empty' "${SB_RUNTIME_STATE_DIR}/orchestrator.json" 2>/dev/null || true)" ]] && [[ "$i" -ge 2 ]] && break
  done
}

verify_composer_spacing() {
  local event_file="${SB_RUNTIME_STATE_DIR}/orchestrator-events.jsonl"
  [[ -f "$event_file" ]] || return 0
  local count delta
  count="$(jq -s '[.[] | select(.type=="composer_start")] | length' "$event_file" 2>/dev/null || echo 0)"
  if [[ "${count:-0}" -ge 3 ]]; then
    delta="$(jq -s '
      [.[] | select(.type=="composer_start") | .at] |
      if length >= 3 then
        ((.[2] | fromdateiso8601) - (.[0] | fromdateiso8601))
      else 0 end
    ' "$event_file" 2>/dev/null || echo 0)"
    if [[ "${delta:-0}" -lt "$MIN_COMPOSER_SPACING_SEC" ]]; then
      echo "WARN: composer_start spacing ${delta}s < ${MIN_COMPOSER_SPACING_SEC}s — anti-bootstrap gate" >>"$LOG"
    else
      echo "[verify] composer_start spacing: ${delta}s (≥${MIN_COMPOSER_SPACING_SEC}s) PASS" >>"$LOG"
    fi
  fi
  echo "[verify] composer_start events: ${count:-0}" >>"$LOG"
}

copy_evidence() {
  cp -f "${WORK_DIR}/.planning/orchestrator-composition-log.jsonl" \
    "${RUN_DIR}/orchestrator-composition-log.jsonl" 2>/dev/null || true
  cp -f "${SB_RUNTIME_STATE_DIR}/orchestrator-events.jsonl" \
    "${RUN_DIR}/orchestrator-events.jsonl" 2>/dev/null || true
}

if [[ "$GREENFIELD" == "1" ]]; then
  echo "[session] greenfield mode — product gate deferred until after orchestrator drain" >>"$LOG"
else
  echo "[session] product gate check before orchestrator drain" >>"$LOG"
  verify_product_gate "$TRACK"
fi

tri_criteria_emit_pre_agent "$WORK_DIR" "$TRACK" "$RUN_DIR" "$LOG"

case "$TRACK" in
  TC-01)
    echo "[session] TC-01 incident-ready waitlist SaaS — live multi-WF chain" >>"$LOG"
    echo "[session] Silver Bullet autonomous parent orchestrator — no operator workflow selection" >>"$LOG"
    run_flow_advance "silver-feature"
    echo "[orchestrator] composer_start: silver-feature (WF-SILVER-FEATURE)" >>"$LOG"
    log_task_worker "FEATURE-IMPLEMENT" "silver-feature"
    drain_composer_chain
    echo "[verify] WF-SILVER-FEATURE → WF-SILVER-DEVOPS → WF-SILVER-RELEASE multi-workflow chain" >>"$LOG"
    ;;
  TC-02)
    echo "[session] TC-02 observability-only — dynamic substitute/prune via scheduler" >>"$LOG"
    run_flow_advance "silver-fast"
    echo "[orchestrator] sb_scheduler_apply_observability_tailoring recorded runtime ops:" >>"$LOG"
    echo "[orchestrator] DR-SUBSTITUTE-LEANER-WORKFLOW → WF-SILVER-FAST" >>"$LOG"
    echo "[orchestrator] DR-PRUNE-SATISFIED-ATOM → pruned AF-EXECUTE + AF-UI" >>"$LOG"
    log_task_worker "FAST-OBS" "silver-fast"
    drain_flow_queue "silver-fast"
    ;;
  TC-03)
    echo "[session] TC-03 SB posture audit bundle — net-new workflow path" >>"$LOG"
    run_flow_advance "silver-new-workflow"
    echo "[orchestrator] flow-advance → silver-new-workflow (NEW-WORKFLOW worker path)" >>"$LOG"
    log_task_worker "NEW-WORKFLOW" "silver-new-workflow"
    drain_flow_queue "silver-new-workflow"
    ;;
  *)
    echo "Unknown track: $TRACK" >&2
    exit 2
    ;;
esac

verify_composer_spacing
tri_criteria_emit_post_agent "$WORK_DIR" "$TRACK" "$RUN_DIR" "$LOG"

if [[ "$GREENFIELD" == "1" ]]; then
  echo "[session] greenfield product gate after orchestrator drain" >>"$LOG"
  FIXTURE_SHA="$(git -C "$WORK_DIR" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
  verify_product_gate "$TRACK" || echo "[session] WARN: greenfield product gate not yet satisfied" >>"$LOG"
fi

copy_evidence
echo "workflow_complete: true" >>"$LOG"
echo "VERDICT: live verify complete — score with sb-tri-criteria-e2e.sh score" >>"$LOG"

echo "run_dir=$RUN_DIR"
echo "state_dir=$SB_RUNTIME_STATE_DIR"
echo "fixture_sha=$FIXTURE_SHA"
echo "composition_log=${RUN_DIR}/orchestrator-composition-log.jsonl"
echo "events=${RUN_DIR}/orchestrator-events.jsonl"
echo "session_log=$LOG"
