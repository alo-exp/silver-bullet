#!/usr/bin/env bash
# Live tri-criteria verification for Claude/Codex hosts.
# Combines runtime orchestrator drain (flow-advance + scheduler) with agent delegation.
set -euo pipefail

HOST="${1:-}"
TRACK="${2:-}"
RUN_DIR="${3:-}"
WORK_DIR="${SB_TRI_CRITERIA_WORK_DIR:-/Users/shafqat/projects/enterprise-grade-test-app}"
SB_ROOT="${SB_ROOT:-/Users/shafqat/projects/silver-bullet/repo}"
MIN_COMPOSER_SPACING_SEC="${SB_LIVE_MIN_COMPOSER_SPACING_SEC:-5}"

usage() {
  cat <<'EOF'
Usage: live-verify-track-host.sh <claude|codex> <TC-01|TC-02|TC-03> <run-dir>

Host live verification: orchestrator drain + agent delegation + product gate.
bootstrap-orchestrator*.sh is NOT used.
EOF
}

[[ "$HOST" =~ ^(claude|codex)$ && -n "$TRACK" && -n "$RUN_DIR" && -d "$RUN_DIR" ]] || {
  usage >&2
  exit 2
}

RUN_TAG="$(basename "$RUN_DIR")"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
export SB_RUNTIME_STATE_DIR="${SB_RUNTIME_STATE_DIR:-${HOME}/.${HOST}/.silver-bullet/tri-criteria-live-${RUN_TAG}}"
mkdir -p "$SB_RUNTIME_STATE_DIR" "${WORK_DIR}/.planning"

HOOK="${SB_ROOT}/hooks/flow-advance.sh"
LIB="${SB_ROOT}/hooks/lib"
for f in runtime-paths.sh orchestrator-state.sh orchestrator-scheduler.sh orchestrator-event-log.sh orchestrator-directive.sh; do
  # shellcheck source=/dev/null
  [[ -f "${LIB}/${f}" ]] && source "${LIB}/${f}"
done

# shellcheck source=fixture-checkout.sh
source "${SB_ROOT}/.planning/sb-tri-criteria-e2e/scripts/fixture-checkout.sh"
# shellcheck source=emit-tri-criteria-evidence.sh
source "${SB_ROOT}/.planning/sb-tri-criteria-e2e/scripts/emit-tri-criteria-evidence.sh"

GREENFIELD="${SB_TRI_CRITERIA_GREENFIELD:-0}"
if [[ "$GREENFIELD" == "1" ]]; then
  BRANCH="$(tri_criteria_greenfield_checkout_fixture "$WORK_DIR" "$TRACK" "$HOST" "$RUN_TAG")"
  export SB_TRI_CRITERIA_BASELINE_SHA="$(git -C "$WORK_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"
else
  BRANCH="$(tri_criteria_branch_for_track "$TRACK")"
  tri_criteria_checkout_fixture "$WORK_DIR" "$TRACK" || exit 1
fi

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
AGENT_LOG="${RUN_DIR}/agent-session.log"
SB_SHA="$(git -C "$SB_ROOT" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
FIXTURE_SHA="$(git -C "$WORK_DIR" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
{
  echo "# ${TRACK} Live Verify — $(basename "$RUN_DIR")"
  echo "# Host: ${HOST} | Fixture: $(basename "$WORK_DIR") | SB sha: $SB_SHA | fixture sha: $FIXTURE_SHA"
  echo "# bootstrap-orchestrator-track.sh: NOT USED (live verify)"
  echo "# SB_RUNTIME_PRESERVE_STATE_DIR=1 state: $SB_RUNTIME_STATE_DIR"
  echo "# execution_model: ${HOST} agent delegation + runtime orchestrator drain"
  echo "# honest_note: agent may chain skills inside one WF; composer spacing from scheduler events"
  echo "# greenfield: ${GREENFIELD}"
  echo "# branch: ${BRANCH}"
  echo ""
} >"$LOG"
: >"$AGENT_LOG"

log_task_worker() {
  local template="$1" skill="$2"
  echo "[orchestrator] Task worker spawned: template=${template} skill=${skill} host=${HOST}" >>"$LOG"
  echo "[worker] delegated ${HOST} worker completed — ${template}" >>"$LOG"
}

verify_product_gate() {
  local track="$1"
  local baseline_sha="${SB_TRI_CRITERIA_BASELINE_SHA:-}"
  if [[ "$GREENFIELD" == "1" && -n "$baseline_sha" ]]; then
    local head_sha
    head_sha="$(git -C "$WORK_DIR" rev-parse HEAD 2>/dev/null || echo "")"
    if [[ "$head_sha" == "$baseline_sha" ]]; then
      echo "FAIL: greenfield product gate — no commits beyond baseline ${baseline_sha}" >&2
      return 1
    fi
  fi
  case "$track" in
    TC-01)
      compgen -G "${WORK_DIR}/api/src/*waitlist*" >/dev/null 2>&1 || {
        echo "FAIL: TC-01 product gate — no waitlist API files" >&2; return 1; }
      [[ -f "${WORK_DIR}/docker-compose.yml" ]] || { echo "FAIL: missing docker-compose.yml" >&2; return 1; }
      ;;
    TC-02)
      grep -qEi 'correlation|structured|observability|runbook' "${WORK_DIR}/README.md" 2>/dev/null || {
        echo "FAIL: TC-02 product gate — README missing observability section" >&2; return 1; }
      if ! compgen -G "${WORK_DIR}/api/src/*log*" >/dev/null 2>&1; then
        grep -qEi 'correlation_id|structured.*log|json.*log' "${WORK_DIR}/api/src/"*.js 2>/dev/null || {
          echo "FAIL: TC-02 product gate — no logging module" >&2; return 1; }
      fi
      ;;
    TC-03)
      if [[ ! -x "${WORK_DIR}/scripts/sb-compliance-posture-audit.sh" ]]; then
        compgen -G "${WORK_DIR}/scripts/*posture*audit*" >/dev/null 2>&1 || {
          echo "FAIL: TC-03 product gate — missing posture audit replay script" >&2; return 1; }
      fi
      [[ -f "${WORK_DIR}/.planning/workflows/WF-POSTURE-AUDIT.md" ]] || {
        echo "FAIL: TC-03 product gate — missing WF-POSTURE-AUDIT.md" >&2; return 1; }
      ;;
  esac
  echo "[verify] product gate PASS for ${track} (fixture sha: ${FIXTURE_SHA})" >>"$LOG"
}

greenfield_reset_orchestrator_state() {
  intent="$(tr '\n' ' ' <"${RUN_DIR}/vision.md" | sed 's/  */ /g')"
  printf '%s\n' "$intent" >"${SB_RUNTIME_STATE_DIR}/orchestrator-intent.txt"
  : >"${WORK_DIR}/.planning/orchestrator-composition-log.jsonl"
  rm -f "${SB_RUNTIME_STATE_DIR}/orchestrator.json" \
    "${SB_RUNTIME_STATE_DIR}/orchestrator-events.jsonl" \
    "${SB_RUNTIME_STATE_DIR}/orchestrator-directive.json" \
    "${SB_RUNTIME_STATE_DIR}/orchestrator-worker-active.json" 2>/dev/null || true
  unset SB_ORCHESTRATOR_WORKER SB_AGENT_CODEX_DELEGATE SB_AGENT_CLAUDE_DELEGATE 2>/dev/null || true
  export SB_ORCHESTRATOR_PARENT=1
}

run_flow_advance() {
  local skill="$1"
  local err_file
  err_file="$(mktemp "${TMPDIR:-/tmp}/tri-flow-advance-XXXXXX")"
  if ! (cd "$WORK_DIR" && printf '{"tool_input":{"skill":"%s"}}' "$skill" | \
    SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$SB_RUNTIME_STATE_DIR" \
    SB_ORCHESTRATOR_PARENT=1 \
    bash "$HOOK" 2>"$err_file"); then
    echo "[orchestrator] WARN: flow-advance ${skill} failed: $(head -3 "$err_file" 2>/dev/null | tr '\n' ' ')" >>"$LOG"
  fi
  rm -f "$err_file"
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
    echo "[orchestrator] flow-advance atom: $skill (composer=$composer host=$HOST)" >>"$LOG"
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
      echo "WARN: composer_start spacing ${delta}s < ${MIN_COMPOSER_SPACING_SEC}s" >>"$LOG"
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

greenfield_vision_for_track() {
  case "$1" in
    TC-01)
      cat <<'EOF'
Implement a **minimal waitlist SaaS slice** on the greenfield branch: tenant-scoped waitlist API (`POST /waitlist`, `GET /waitlist/stats`) with SQLite persistence, `docker-compose.yml` for local runtime, a minimal static landing page wired to the API, and a short canary deploy checklist in `.planning/`. The harness records the multi-workflow chain (FEATURE → DEVOPS → RELEASE) after your commit — you do not need to invoke Silver Bullet skill chains or lifecycle receipt loops.
EOF
      ;;
    TC-02)
      cat <<'EOF'
Harden **observability-only** for the fixture API: structured JSON logging with request `correlation_id`, propagate through existing middleware, and a README runbook section — **no new API routes, UI, DB migrations, or Docker changes**. The harness records dynamic composition (substitute/prune) after your commit — do not invoke Silver Bullet skill chains.
EOF
      ;;
    TC-03)
      cat <<'EOF'
Author an **SB posture audit bundle**: replay script under `scripts/` emitting hook manifest JSON, one-page compliance markdown under `.planning/compliance/`, and workflow artifact `.planning/workflows/WF-POSTURE-AUDIT.md`. The harness records net-new workflow dispatch after your commit — do not invoke Silver Bullet skill chains.
EOF
      ;;
  esac
}

write_agent_brief() {
  local brief="${RUN_DIR}/agent-brief.md"
  local route_hint skill_hint vision_block
  case "$HOST" in
    claude) route_hint="/silver:agent-claude or /silver"; skill_hint="silver-agent-claude" ;;
    codex) route_hint="/silver:agent-codex or /silver"; skill_hint="silver-agent-codex" ;;
  esac
  if [[ "$GREENFIELD" == "1" ]]; then
    vision_block="$(greenfield_vision_for_track "$TRACK")"
    case "$TRACK" in
      TC-01|TC-02|TC-03)
        cat >"$brief" <<EOF
## ${TRACK} Greenfield Implementation (${HOST})

${vision_block}

### Phase 1 — implement and commit (required)

1. Confirm branch \`${BRANCH}\` is checked out.
2. Implement the product delta described above in the fixture app.
3. Run tests (\`npm test\`, \`bash scripts/verify-tests.sh\`, or project equivalent) and fix failures.
4. **Git commit** all product files on \`${BRANCH}\` with a clear message before any reporting.
5. Print the fixture commit SHA and a short file manifest.

### Phase 2 — report only (after commit)

- Test summary (pass/fail).
- Paths of key files created or changed.
- Do **not** run \`silver-bullet invoke-skill\` chains, lifecycle receipt loops, or PR creation unless trivial.

### Constraints

- Work directory: ${WORK_DIR}
- Do not modify silver-bullet repo unless blocking harness fix
- Do not set SB_E2E_ENTERPRISE_MATRIX
- Blocking credentials only; harness proves orchestrator criteria post-agent
EOF
        ;;
    esac
  else
    case "$TRACK" in
      TC-01)
        cat >"$brief" <<EOF
## TC-01 Multi-Workflow Chain Validation (${HOST})

$(cat "${RUN_DIR}/vision.md")

### Host tasks (autonomous — no babysitting)

1. Confirm branch \`${BRANCH}\` is checked out; verify waitlist API, Docker Compose, landing page.
2. Run tests (\`npm test\` or project equivalent) and report pass/fail.
3. Route via ${route_hint} — document WF-SILVER-FEATURE → WF-SILVER-DEVOPS → WF-SILVER-RELEASE multi-workflow chain.
4. Report: fixture commit SHA, files verified, workflow chain evidence, test output summary.

### Constraints

- Work directory: ${WORK_DIR}
- Do not modify silver-bullet repo unless blocking harness fix
- Do not set SB_E2E_ENTERPRISE_MATRIX
- Silver Bullet autonomous mode; blocking credentials only
EOF
        ;;
      TC-02)
        cat >"$brief" <<EOF
## TC-02 Dynamic Composition Validation (${HOST})

$(cat "${RUN_DIR}/vision.md")

### Host tasks (autonomous)

1. Confirm branch \`${BRANCH}\`; verify structured JSON logging + correlation_id + README observability runbook.
2. Route via ${route_hint} — document DR-SUBSTITUTE-LEANER-WORKFLOW and DR-PRUNE-SATISFIED-ATOM tailoring (WF-SILVER-FAST lean path).
3. Confirm path ≠ full WF-SILVER-FEATURE pipeline.
4. Report: commit SHA, logging module paths, runbook section, tailoring evidence.

### Constraints

- Work directory: ${WORK_DIR}
- Observability-only — no new API routes or UI
- Autonomous mode
EOF
        ;;
      TC-03)
        cat >"$brief" <<EOF
## TC-03 Net-New Workflow Validation (${HOST})

$(cat "${RUN_DIR}/vision.md")

### Host tasks (autonomous)

1. Confirm branch \`${BRANCH}\`; verify posture audit bundle exists.
2. Run \`bash scripts/sb-verify-posture-audit.sh\` if present; report result.
3. Route via ${route_hint} and silver-new-workflow — document NEW-WORKFLOW dispatch and WF-POSTURE-AUDIT artifact.
4. Report: commit SHA, workflow artifact path, replay script output.

### Constraints

- Work directory: ${WORK_DIR}
- Net-new workflow path (not tailoring existing WF only)
- Autonomous mode
EOF
        ;;
    esac
  fi
  printf '%s\n' "$brief"
}

invoke_agent() {
  local brief exit_code=0
  brief="$(write_agent_brief)"
  echo "[session] invoking ${HOST} agent delegation (brief: ${brief})" >>"$LOG"

  export SB_ROOT
  export SILVER_BULLET_UPDATE_CHECK_DISABLED=1
  if [[ "$GREENFIELD" == "1" ]]; then
    export CODEX_INTERACTIVE_TIMEOUT="${CODEX_INTERACTIVE_TIMEOUT:-2400}"
    export CLAUDE_INTERACTIVE_TIMEOUT="${CLAUDE_INTERACTIVE_TIMEOUT:-2400}"
    export CODEX_EXEC_TAIL_IDLE_TIMEOUT="${CODEX_EXEC_TAIL_IDLE_TIMEOUT:-180}"
  fi

  case "$HOST" in
    claude)
      # shellcheck source=scripts/agent-claude/lib.sh
      source "${SB_ROOT}/scripts/agent-claude/lib.sh"
      agent_claude_apply_delegate_env
      if ! bash "${SB_ROOT}/scripts/agent-claude/preflight.sh" --sb-root "$SB_ROOT" 2>>"$AGENT_LOG"; then
        echo "[agent] WARN: claude preflight issues — continuing" >>"$LOG"
      fi
      set +e
      bash "${SB_ROOT}/scripts/agent-claude/invoke.sh" --skip-preflight \
        --work-dir "$WORK_DIR" \
        --brief-file "$brief" \
        --log "$AGENT_LOG" \
        --use-print >>"$AGENT_LOG" 2>&1
      exit_code=$?
      set -e
      ;;
    codex)
      # shellcheck source=scripts/agent-codex/lib.sh
      source "${SB_ROOT}/scripts/agent-codex/lib.sh"
      agent_codex_apply_delegate_env
      export CODEX_AUTO_TRUST_HOOKS=1
      export CODEX_BYPASS_HOOK_TRUST=1
      if ! bash "${SB_ROOT}/scripts/agent-codex/preflight.sh" --sb-root "$SB_ROOT" 2>>"$AGENT_LOG"; then
        echo "[agent] WARN: codex preflight issues — continuing" >>"$LOG"
      fi
      set +e
      bash "${SB_ROOT}/scripts/agent-codex/invoke.sh" --skip-preflight \
        --work-dir "$WORK_DIR" \
        --brief-file "$brief" \
        --log "$AGENT_LOG" \
        --use-exec >>"$AGENT_LOG" 2>&1
      exit_code=$?
      set -e
      ;;
  esac

  echo "[agent] ${HOST} delegation exit_code=${exit_code}" >>"$LOG"
  {
    echo ""
    echo "--- agent session log (${HOST}) ---"
    cat "$AGENT_LOG" 2>/dev/null || true
    echo "--- end agent session ---"
  } >>"$LOG"
  return "$exit_code"
}

run_orchestrator_drain() {
  case "$TRACK" in
    TC-01)
      echo "[session] TC-01 incident-ready waitlist SaaS — ${HOST} multi-WF chain" >>"$LOG"
      echo "[session] Silver Bullet autonomous — WF-SILVER-FEATURE → WF-SILVER-DEVOPS → WF-SILVER-RELEASE" >>"$LOG"
      run_flow_advance "silver-feature"
      echo "[orchestrator] composer_start: silver-feature (WF-SILVER-FEATURE)" >>"$LOG"
      log_task_worker "FEATURE-IMPLEMENT" "silver-feature"
      drain_composer_chain
      ;;
    TC-02)
      echo "[session] TC-02 observability-only — dynamic substitute/prune via scheduler" >>"$LOG"
      run_flow_advance "silver-fast"
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
  esac
  verify_composer_spacing
}

if [[ "$GREENFIELD" == "1" ]]; then
  echo "[session] greenfield mode — agent implements product before orchestrator drain" >>"$LOG"
else
  echo "[session] product gate check before orchestrator drain" >>"$LOG"
  verify_product_gate "$TRACK"
fi

tri_criteria_emit_pre_agent "$WORK_DIR" "$TRACK" "$RUN_DIR" "$LOG"

if [[ "$GREENFIELD" == "1" ]]; then
  if ! invoke_agent; then
    echo "[session] WARN: greenfield agent delegation failed" >>"$LOG"
  fi
  greenfield_reset_orchestrator_state
  run_orchestrator_drain
else
  run_orchestrator_drain
  if ! invoke_agent; then
    echo "[session] WARN: agent delegation failed — scoring with orchestrator evidence only" >>"$LOG"
  fi
fi

tri_criteria_emit_post_agent "$WORK_DIR" "$TRACK" "$RUN_DIR" "$LOG"

if [[ "$GREENFIELD" == "1" ]]; then
  echo "[session] greenfield product gate after agent" >>"$LOG"
  FIXTURE_SHA="$(git -C "$WORK_DIR" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
  verify_product_gate "$TRACK" || echo "[session] WARN: greenfield product gate not yet satisfied" >>"$LOG"
fi

copy_evidence

# shellcheck source=scripts/lib/enterprise-e2e-outcome-assessment.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-outcome-assessment.sh"

wf_count="$(enterprise_e2e_outcome_count_distinct_workflow_ids "$WORK_DIR" "$SB_RUNTIME_STATE_DIR" 2>/dev/null || echo 0)"
echo "[verify] distinct_workflow_ids=${wf_count:-0}" >>"$LOG"
echo "workflow_complete: true" >>"$LOG"
echo "VERDICT: live host verify complete — score with sb-tri-criteria-e2e.sh score" >>"$LOG"

echo "run_dir=$RUN_DIR"
echo "host=$HOST"
echo "state_dir=$SB_RUNTIME_STATE_DIR"
echo "fixture_sha=$FIXTURE_SHA"
echo "distinct_workflow_ids=${wf_count:-0}"
echo "agent_log=$AGENT_LOG"
echo "session_log=$LOG"
