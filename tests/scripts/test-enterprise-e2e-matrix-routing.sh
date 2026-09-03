#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_ok() {
  local desc="$1"
  shift
  if "$@"; then
    echo "PASS: $desc"
    ((PASS++)) || true
  else
    echo "FAIL: $desc"
    ((FAIL++)) || true
  fi
}

assert_fail() {
  local desc="$1"
  shift
  if "$@"; then
    echo "FAIL: $desc — expected failure"
    ((FAIL++)) || true
  else
    echo "PASS: $desc"
    ((PASS++)) || true
  fi
}

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMPDIR="${TMPDIR:-/tmp}"
STATE_DIR="$(mktemp -d "${TMPDIR}/sb-matrix-routing.XXXXXX")"
trap 'rm -rf "$STATE_DIR"' EXIT

# shellcheck source=scripts/enterprise-e2e/lib/host.sh
source "${REPO_ROOT}/scripts/enterprise-e2e/lib/host.sh"

export HOME="$STATE_DIR/home"
matrix_routing_state_root() {
  local base="${1:-$HOME}"
  case "${SILVER_BULLET_RUNTIME:-claude}" in
    codex) printf '%s/.codex/.silver-bullet' "$base" ;;
    cursor) printf '%s/.cursor/.silver-bullet' "$base" ;;
    *) printf '%s/.codex/.silver-bullet' "$base" ;;
  esac
}
SB_RUNTIME_STATE_DIR="$(matrix_routing_state_root)"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
mkdir -p "$SB_RUNTIME_STATE_DIR"
STATE_FILE="${SB_RUNTIME_STATE_DIR}/state"
ROUTING_STATE_SNAPSHOT=""

# shellcheck source=tests/e2e-live/lib/skill-prompt.sh
source "${REPO_ROOT}/tests/e2e-live/lib/skill-prompt.sh"

build_matrix_prompt() {
  local route="$1"
  local prompt_card="$2"
  local evidence_path="$3"
  local row_num="${4:-}"
  local slug="${5:-}"
  route="$(enterprise_e2e_matrix_host_route "$route")"
  if [[ "$row_num" == "1" ]]; then
    printf '%s %s Enterprise E2E routing validation only. Route this request through the Silver Bullet orchestrator and invoke the composed workflow skill. Stop when routing completes.' \
      "$route" "$prompt_card"
    return 0
  fi
  local workflow_route="/silver"
  if [[ "$(enterprise_e2e_matrix_host)" == "codex" ]]; then
    workflow_route="$(enterprise_e2e_matrix_host_route "/silver")"
  fi
  matrix_router_workflow_prompt "$slug" "$prompt_card" "$evidence_path" "$workflow_route"
}

claude_routing_state_file() {
  printf '%s\n' "${SB_RUNTIME_STATE_DIR}/state"
}

snapshot_routing_state() {
  local state_file
  state_file="$(claude_routing_state_file)"
  if [[ -f "$state_file" ]]; then
    ROUTING_STATE_SNAPSHOT="$(cat "$state_file")"
  else
    ROUTING_STATE_SNAPSHOT=""
  fi
}

verify_row_routing_state_delta() {
  local state_file new_skills
  state_file="$(claude_routing_state_file)"
  [[ -f "$state_file" ]] || return 1
  new_skills="$(comm -13 \
    <(printf '%s\n' "$ROUTING_STATE_SNAPSHOT" | sed '/^$/d' | sort -u) \
    <(sed '/^$/d' "$state_file" | sort -u) 2>/dev/null || true)"
  [[ -n "$new_skills" ]] || return 1
  printf '%s\n' "$new_skills" | grep -qE '^(silver-feature|silver-fast|silver-clarify|silver-context|silver-quality-gates)$'
}

row1_prompt="$(build_matrix_prompt '/silver' 'I need to add order validation to the API — route me.' '.planning/workflows/router-session.md' '1')"
if [[ "$row1_prompt" == *"routing validation only"* && "$row1_prompt" != *"Create workflow evidence"* ]]; then
  echo "PASS: row 1 prompt is routing-only"
  ((PASS++)) || true
else
  echo "FAIL: row 1 prompt is routing-only"
  ((FAIL++)) || true
fi

printf 'silver-context\n' >"$STATE_FILE"
snapshot_routing_state
printf 'silver-context\nsilver-feature\n' >"$STATE_FILE"
assert_ok "detects new routing skill in state delta" verify_row_routing_state_delta

snapshot_routing_state
printf 'silver-context\nsilver-unknown\n' >"$STATE_FILE"
assert_fail "rejects unrelated new skill names" verify_row_routing_state_delta

driver="$(grep -F 'enterprise_e2e_matrix_quiesce_orchestrator_queue' "${REPO_ROOT}/scripts/enterprise-e2e/matrix.sh" | head -1 || true)"
if [[ -n "$driver" ]]; then
  echo "PASS: matrix runner quiesces orchestrator before live rows"
  ((PASS++)) || true
else
  echo "FAIL: matrix runner quiesces orchestrator before live rows"
  ((FAIL++)) || true
fi

if [[ -f "${REPO_ROOT}/hooks/lib/e2e-matrix-routing.sh" ]]; then
  # shellcheck source=hooks/lib/e2e-matrix-routing.sh
  source "${REPO_ROOT}/hooks/lib/e2e-matrix-routing.sh"
  export SB_E2E_ENTERPRISE_MATRIX=1
  sb_e2e_matrix_set_routing_row_marker
  if sb_e2e_matrix_routing_row_active; then
    echo "PASS: routing row marker pairs with enterprise matrix env"
    ((PASS++)) || true
  else
    echo "FAIL: routing row marker pairs with enterprise matrix env"
    ((FAIL++)) || true
  fi
  unset SB_E2E_ENTERPRISE_MATRIX
  unset SB_E2E_MATRIX_ROUTING_ROW
  if sb_e2e_matrix_routing_row_active; then
    echo "PASS: routing row marker active without enterprise matrix env (hook spawn)"
    ((PASS++)) || true
  else
    echo "FAIL: routing row marker active without enterprise matrix env (hook spawn)"
    ((FAIL++)) || true
  fi
  sb_e2e_matrix_clear_routing_row_marker
  unset SB_E2E_ENTERPRISE_MATRIX
else
  echo "FAIL: e2e-matrix-routing.sh helper missing"
  ((FAIL++)) || true
fi

SUBAGENT_HOOK="${REPO_ROOT}/hooks/subagent-stop-enforcement.sh"
if [[ -x "$SUBAGENT_HOOK" && -f "${REPO_ROOT}/hooks/lib/e2e-matrix-routing.sh" ]]; then
  # shellcheck source=hooks/lib/e2e-matrix-routing.sh
  source "${REPO_ROOT}/hooks/lib/e2e-matrix-routing.sh"
  export SB_RUNTIME_STATE_DIR="$(matrix_routing_state_root "$STATE_DIR/home")"
  sb_e2e_matrix_set_routing_row_marker
  sub_out="$(printf '%s' '{"hook_event_name":"Stop"}' | HOME="$HOME" SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$SB_RUNTIME_STATE_DIR" bash "$SUBAGENT_HOOK" 2>/dev/null || true)"
  if ! printf '%s' "$sub_out" | grep -qE '"decision"\s*:\s*"block"'; then
    echo "PASS: subagent-stop exempt when routing row marker set"
    ((PASS++)) || true
  else
    echo "FAIL: subagent-stop exempt when routing row marker set"
    ((FAIL++)) || true
  fi
  sb_e2e_matrix_clear_routing_row_marker
fi

LEDGER_HOOK="${REPO_ROOT}/hooks/instruction-ledger-gate.sh"
if [[ -x "$LEDGER_HOOK" && -f "${REPO_ROOT}/hooks/lib/e2e-matrix-routing.sh" ]]; then
  # shellcheck source=hooks/lib/e2e-matrix-routing.sh
  source "${REPO_ROOT}/hooks/lib/e2e-matrix-routing.sh"
  ledger_home="$(mktemp -d "${TMPDIR}/sb-matrix-ledger.XXXXXX")"
  cp "$REPO_ROOT/silver-bullet.md" "$ledger_home/silver-bullet.md"
  printf '{"sb_initiated":true,"orchestrator_mode":"parent","project":{"name":"test","active_workflow":"full-dev-cycle"},"skills":{"required_planning":["silver-quality-gates"]}}\n' \
    >"$ledger_home/.silver-bullet.json"
  ledger_state="$(matrix_routing_state_root "$ledger_home")"
  mkdir -p "$ledger_state"
  jq -n '{prompt_id:"abc",status:"pending",children:[{id:"c1",label:"item",status:"pending",evidence:"",children:[]}]}' \
    >"${ledger_state}/instruction-ledger.json"
  export SB_RUNTIME_STATE_DIR="$ledger_state"
  ledger_out="$(cd "$ledger_home" && printf '%s' '{"hook_event_name":"Stop"}' | HOME="$ledger_home" SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$ledger_state" bash "$LEDGER_HOOK" 2>/dev/null || true)"
  if printf '%s' "$ledger_out" | grep -qE '"decision"\s*:\s*"block"'; then
    echo "PASS: instruction-ledger blocks Stop with unresolved items (no marker)"
    ((PASS++)) || true
  else
    echo "FAIL: instruction-ledger blocks Stop with unresolved items (no marker)"
    ((FAIL++)) || true
  fi
  sb_e2e_matrix_set_routing_row_marker
  ledger_out="$(cd "$ledger_home" && printf '%s' '{"hook_event_name":"Stop"}' | HOME="$ledger_home" SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$ledger_state" bash "$LEDGER_HOOK" 2>/dev/null || true)"
  if ! printf '%s' "$ledger_out" | grep -qE '"decision"\s*:\s*"block"'; then
    echo "PASS: instruction-ledger exempt when routing row marker set"
    ((PASS++)) || true
  else
    echo "FAIL: instruction-ledger exempt when routing row marker set"
    ((FAIL++)) || true
  fi
  sb_e2e_matrix_clear_routing_row_marker
  rm -rf "$ledger_home"
fi

SITE_REG_HOOK="${REPO_ROOT}/hooks/site-regression-gate.sh"
if [[ -x "$SITE_REG_HOOK" && -f "${REPO_ROOT}/hooks/lib/e2e-matrix-routing.sh" ]]; then
  # shellcheck source=hooks/lib/e2e-matrix-routing.sh
  source "${REPO_ROOT}/hooks/lib/e2e-matrix-routing.sh"
  site_home="$(mktemp -d "${TMPDIR}/sb-matrix-site.XXXXXX")"
  cp "$REPO_ROOT/silver-bullet.md" "$site_home/silver-bullet.md"
  printf '{"sb_initiated":true,"orchestrator_mode":"parent","project":{"name":"test","active_workflow":"full-dev-cycle"},"skills":{"required_planning":["silver-quality-gates"]}}\n' \
    >"$site_home/.silver-bullet.json"
  site_state="$(matrix_routing_state_root "$site_home")"
  mkdir -p "$site_state"
  jq -n '{active:true,started_at:"2026-01-01T00:00:00Z",last_touch_at:"2026-06-28T12:00:00Z",touch_reason:"site-intent",regression_passed_at:null,push_intent:false}' \
    >"${site_state}/site-session.json"
  export SB_RUNTIME_STATE_DIR="$site_state"
  site_out="$(cd "$site_home" && printf '%s' '{"hook_event_name":"Stop"}' | HOME="$site_home" SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$site_state" bash "$SITE_REG_HOOK" 2>/dev/null || true)"
  if printf '%s' "$site_out" | grep -qE '"decision"\s*:\s*"block"'; then
    echo "PASS: site-regression blocks Stop with active session (no marker)"
    ((PASS++)) || true
  else
    echo "FAIL: site-regression blocks Stop with active session (no marker)"
    ((FAIL++)) || true
  fi
  sb_e2e_matrix_set_routing_row_marker
  site_out="$(cd "$site_home" && printf '%s' '{"hook_event_name":"Stop"}' | HOME="$site_home" SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$site_state" bash "$SITE_REG_HOOK" 2>/dev/null || true)"
  if ! printf '%s' "$site_out" | grep -qE '"decision"\s*:\s*"block"'; then
    echo "PASS: site-regression exempt when routing row marker set"
    ((PASS++)) || true
  else
    echo "FAIL: site-regression exempt when routing row marker set"
    ((FAIL++)) || true
  fi
  sb_e2e_matrix_clear_routing_row_marker
  rm -rf "$site_home"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
