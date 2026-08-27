#!/usr/bin/env bash
# reconcile-recommended-tools.sh — canonical five-tool reconciliation engine.
# Only this script is executable; component libs are sourced helpers.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "${SCRIPT_DIR}/lib/recommended-tools" ]]; then
  RT_LIB="${SCRIPT_DIR}/lib/recommended-tools"
elif [[ -d "${SCRIPT_DIR}/recommended-tools" ]]; then
  RT_LIB="${SCRIPT_DIR}/recommended-tools"
else
  RT_LIB="${SCRIPT_DIR}/lib/recommended-tools"
fi
RT_REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

RT_PROJECT_ROOT=""
RT_HOST="cursor"
RT_MODE="verify"
RT_SCOPE="all"
RT_FORMAT="text"
RT_ENTRY_POINT=""
RT_CONFIG_FILE=""
RT_AUTH_ERROR=""
RT_HOST_EVIDENCE_STDIN=false

usage() {
  cat <<'EOF'
Usage: bash scripts/reconcile-recommended-tools.sh [options]

Canonical consent-aware probe/reconcile engine for Graphify, agentmemory,
RTK, Context Mode, LeanCTX, and cross-tool convergence.

Options:
  --project-root <path>     Canonical SB project root (required for project scope)
  --host <cursor|...>       Target host (default: cursor; Phase A implements cursor)
  --mode verify|plan|apply  verify/plan are read-only; apply mutates (default: verify)
  --scope project|host|packages|all
  --format text|json
  --entry-point init|update|installer|doctor-fix  Required for --mode apply
  --host-evidence-stdin  Read one UTF-8 JSON attestation (max 64KiB) from stdin
  -h, --help

Authorization:
  apply requires exactly one --entry-point.
  entry-point with verify/plan fails closed.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root) RT_PROJECT_ROOT="${2:-}"; shift 2 ;;
    --host) RT_HOST="${2:-cursor}"; shift 2 ;;
    --mode) RT_MODE="${2:-verify}"; shift 2 ;;
    --scope) RT_SCOPE="${2:-all}"; shift 2 ;;
    --format) RT_FORMAT="${2:-text}"; shift 2 ;;
    --entry-point) RT_ENTRY_POINT="${2:-}"; shift 2 ;;
    --host-evidence-stdin) RT_HOST_EVIDENCE_STDIN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$RT_PROJECT_ROOT" ]]; then
  RT_PROJECT_ROOT="$(pwd)"
  if git -C "$RT_PROJECT_ROOT" rev-parse --show-toplevel >/dev/null 2>&1; then
    RT_PROJECT_ROOT="$(git -C "$RT_PROJECT_ROOT" rev-parse --show-toplevel)"
  fi
fi
RT_PROJECT_ROOT="$(cd "$RT_PROJECT_ROOT" && pwd -P)"

export RT_PROJECT_ROOT RT_HOST RT_MODE RT_SCOPE RT_FORMAT RT_ENTRY_POINT RT_REPO_ROOT

# Reentrancy guard. Apply mode shells out to the optimizers and installers, and
# those call back into this reconciler (installer post-install). Without a
# marker the chain reconcile -> optimize-rtk-context-mode ->
# install-recommended-tools-global -> install-recommended-tools-cursor ->
# reconcile loops forever. Descendants check this and skip the nested call.
if [[ "$RT_MODE" == "apply" ]]; then
  export SB_RT_APPLY_ACTIVE=1
fi

# shellcheck source=lib/recommended-tools/common.sh
source "${RT_LIB}/common.sh"
rt_init_paths

if ! rt_validate_host "$RT_HOST"; then
  if [[ "$RT_FORMAT" == "json" ]]; then
    jq -n --arg err "unknown host: ${RT_HOST} (allowed: cursor|claude|codex|opencode|goose|hermes)" \
      '{schema:"1.0.0",ok:false,error:$err,components:[]}'
  else
    echo "ERROR: unknown host: ${RT_HOST} (allowed: cursor|claude|codex|opencode|goose|hermes)" >&2
  fi
  exit 2
fi

RT_CONFIG_FILE="$(rt_project_config || true)"
export RT_CONFIG_FILE

if ! rt_validate_authorization; then
  if [[ "$RT_FORMAT" == "json" ]]; then
    jq -n --arg err "${RT_AUTH_ERROR:-authorization_failed}" \
      '{schema:"1.0.0",ok:false,error:$err,components:[]}'
  else
    echo "ERROR: ${RT_AUTH_ERROR:-authorization_failed}" >&2
  fi
  exit 2
fi

# shellcheck source=lib/recommended-tools/probe-graphify.sh
source "${RT_LIB}/probe-graphify.sh"
# shellcheck source=lib/recommended-tools/repair-graphify.sh
source "${RT_LIB}/repair-graphify.sh"
# shellcheck source=lib/recommended-tools/probe-agentmemory.sh
source "${RT_LIB}/probe-agentmemory.sh"
# shellcheck source=lib/recommended-tools/probe-rtk.sh
source "${RT_LIB}/probe-rtk.sh"
# shellcheck source=lib/recommended-tools/probe-context-mode.sh
source "${RT_LIB}/probe-context-mode.sh"
# shellcheck source=lib/recommended-tools/probe-leanctx.sh
source "${RT_LIB}/probe-leanctx.sh"
# shellcheck source=lib/recommended-tools/probe-alumnium.sh
source "${RT_LIB}/probe-alumnium.sh"
# shellcheck source=lib/recommended-tools/probe-cross-tool.sh
source "${RT_LIB}/probe-cross-tool.sh"
# shellcheck source=lib/recommended-tools/heartbeat.sh
source "${RT_LIB}/heartbeat.sh"
# shellcheck source=lib/recommended-tools/receipts.sh
source "${RT_LIB}/receipts.sh"

if [[ "$RT_HOST_EVIDENCE_STDIN" == true ]]; then
  if ! rt_host_evidence_read_stdin; then
    if [[ "$RT_FORMAT" == "json" ]]; then
      jq -n --arg err "${RT_HOST_EVIDENCE_ERROR:-host_evidence_invalid}" \
        '{schema:"1.0.0",ok:false,error:$err,components:[]}'
    else
      echo "ERROR: ${RT_HOST_EVIDENCE_ERROR:-host_evidence_invalid}" >&2
    fi
    exit 2
  fi
fi

RT_SUPPRESS_RELOAD_RECEIPT_CREATE=0
RT_HOST_EVIDENCE_RECEIPT_CLEARED=0
export RT_SUPPRESS_RELOAD_RECEIPT_CREATE RT_HOST_EVIDENCE_RECEIPT_CLEARED

if [[ "$RT_MODE" == "apply" && -n "${RT_HOST_EVIDENCE_JSON:-}" ]]; then
  rt_receipt_consume_host_evidence || true
fi

declare -a RT_COMPONENT_RESULTS=()
declare -a RT_ALL_FAILURES=()
RT_RESTART_REQUIRED=false
RT_CROSS_TOOL_REPAIRED=false
RT_HOST_CONVERGENCE_RAN=false

if [[ "$RT_MODE" == "apply" ]] && rt_scope_includes_component cross_tool; then
  export RT_CROSS_TOOL_BATCH=1
fi

rt_run_component() {
  local component="$1" probe_fn repair_fn probe_json repair_json merged
  rt_scope_includes_component "$component" || return 0
  probe_fn="rt_probe_${component}"
  repair_fn="rt_repair_${component}"
  probe_json=""
  if declare -f "$probe_fn" >/dev/null 2>&1; then
    probe_json="$("$probe_fn")"
  fi
  if [[ "$RT_MODE" == "apply" && -n "$probe_json" ]]; then
    local repairable
    repairable="$(printf '%s' "$probe_json" | jq -r '.repairable // false')"
    if [[ "$repairable" == "true" ]] && declare -f "$repair_fn" >/dev/null 2>&1; then
      repair_json="$("$repair_fn")"
      if [[ "$component" == "cross_tool" ]]; then
        RT_CROSS_TOOL_REPAIRED=true
      fi
      local restart
      restart="$(printf '%s' "$repair_json" | jq -r '.restart_required // false')"
      if [[ "$restart" == "true" ]]; then
        RT_RESTART_REQUIRED=true
      fi
      if declare -f "$probe_fn" >/dev/null 2>&1; then
        probe_json="$("$probe_fn")"
      fi
      merged="$(jq -n --argjson probe "$probe_json" --argjson repair "$repair_json" \
        '$probe + {actions:$repair.actions, failures:$repair.failures, restart_required:$repair.restart_required}')"
      probe_json="$merged"
      while IFS= read -r f; do
        [[ -n "$f" ]] && RT_ALL_FAILURES+=("$f")
      done < <(printf '%s' "$repair_json" | jq -r '.failures[]? // empty')
    fi
  fi
  [[ -n "$probe_json" ]] && RT_COMPONENT_RESULTS+=("$probe_json")
}

rt_reprobe_sibling_components() {
  local sibling probe_fn probe_json updated=() comp_json comp_name merged
  for comp_json in "${RT_COMPONENT_RESULTS[@]}"; do
    comp_name="$(printf '%s' "$comp_json" | jq -r '.component')"
    if [[ "$comp_name" == "cross_tool" ]]; then
      updated+=("$comp_json")
      continue
    fi
    probe_fn="rt_probe_${comp_name}"
    if declare -f "$probe_fn" >/dev/null 2>&1; then
      probe_json="$("$probe_fn")"
      merged="$(jq -n --argjson probe "$probe_json" --argjson prior "$comp_json" \
        '$probe + {actions:($prior.actions // []), failures:($prior.failures // []), restart_required:($prior.restart_required // false)}')"
      updated+=("$merged")
    else
      updated+=("$comp_json")
    fi
  done
  RT_COMPONENT_RESULTS=("${updated[@]}")
}

rt_forced_host_convergence_pass() {
  local conv_json failure restart
  [[ "${RT_MODE:-verify}" == "apply" ]] || return 0
  rt_cross_tool_batch_active || return 0
  [[ "$RT_CROSS_TOOL_REPAIRED" == true ]] && return 0
  rt_any_five_tool_mutation_allowed || return 0

  conv_json="$(rt_apply_host_convergence_batches true)"
  RT_HOST_CONVERGENCE_RAN=true
  while IFS= read -r failure; do
    [[ -n "$failure" ]] && RT_ALL_FAILURES+=("$failure")
  done < <(printf '%s' "$conv_json" | jq -r '.failures[]? // empty')
  restart="$(printf '%s' "$conv_json" | jq -r '.restart_required // false')"
  if [[ "$restart" == "true" ]]; then
    RT_RESTART_REQUIRED=true
  fi
}

rt_run_component graphify
rt_run_component agentmemory
rt_run_component rtk
rt_run_component context_mode
rt_run_component leanctx
rt_run_component alumnium
rt_run_component cross_tool

if [[ "$RT_MODE" == "apply" ]]; then
  rt_forced_host_convergence_pass
fi

if [[ "$RT_MODE" == "apply" && ( "$RT_CROSS_TOOL_REPAIRED" == true || "$RT_HOST_CONVERGENCE_RAN" == true ) ]]; then
  rt_reprobe_sibling_components
fi

if [[ "$RT_MODE" == "apply" && "$RT_ENTRY_POINT" != "doctor-fix" ]]; then
  rt_heartbeat_cleanup_expired 2>/dev/null || true
fi

receipt_eval="$(rt_reconcile_receipt_state 2>/dev/null || echo '{}')"
receipt_has="$(printf '%s' "$receipt_eval" | jq -r '.has_receipt // false')"
receipt_canonical="$(printf '%s' "$receipt_eval" | jq -r '.canonical_state // "ready"')"
receipt_activation="$(printf '%s' "$receipt_eval" | jq -r '.activation_status // "none"')"
receipt_clear="$(printf '%s' "$receipt_eval" | jq -r '.clear_eligible // false')"

if [[ "$receipt_has" == "true" && "$receipt_canonical" == "reload_required" ]]; then
  RT_RESTART_REQUIRED=true
  updated_components=()
  for comp in "${RT_COMPONENT_RESULTS[@]}"; do
    state="$(printf '%s' "$comp" | jq -r '.canonical_state')"
    if [[ "$state" == "ready" ]]; then
      comp="$(printf '%s' "$comp" | jq --arg act "$receipt_activation" \
        '.canonical_state = "reload_required" | .activation_status = $act | .reload_receipt = true')"
    fi
    updated_components+=("$comp")
  done
  RT_COMPONENT_RESULTS=("${updated_components[@]}")
fi

components_json="$(printf '%s\n' "${RT_COMPONENT_RESULTS[@]}" | jq -s '.')"
ok=true
if printf '%s' "$components_json" | jq -e '[.[] | select(.canonical_state == "failed" or .canonical_state == "repairable" or .canonical_state == "reload_required")] | length > 0' >/dev/null; then
  ok=false
fi
if [[ "$receipt_has" == "true" && "$receipt_canonical" == "reload_required" ]]; then
  ok=false
fi

result_json="$(jq -n \
  --arg schema "$RT_RESULT_SCHEMA_VERSION" \
  --arg mode "$RT_MODE" \
  --arg scope "$RT_SCOPE" \
  --arg host "$RT_HOST" \
  --arg project_root "$RT_PROJECT_ROOT" \
  --arg entry_point "${RT_ENTRY_POINT:-}" \
  --argjson ok "$ok" \
  --argjson components "$components_json" \
  --argjson restart_required "$([[ "$RT_RESTART_REQUIRED" == true ]] && echo true || echo false)" \
  --argjson failures "$(printf '%s\n' "${RT_ALL_FAILURES[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
  --argjson receipt "$receipt_eval" \
  '{
    schema: $schema,
    ok: $ok,
    mode: $mode,
    scope: $scope,
    host: $host,
    project_root: $project_root,
    entry_point: (if $entry_point == "" then null else $entry_point end),
    components: $components,
    failures: $failures,
    restart_required: $restart_required,
    receipt: $receipt
  }')"

if [[ "$RT_FORMAT" == "json" ]]; then
  printf '%s\n' "$result_json"
else
  echo "=== reconcile-recommended-tools (${RT_MODE}/${RT_SCOPE} host=${RT_HOST}) ==="
  printf '%s\n' "$result_json" | jq -r '.components[] | "\(.component): \(.canonical_state) (activation=\(.activation_status))"'
  if [[ "$RT_RESTART_REQUIRED" == true ]]; then
    echo "RESTART_REQUIRED: yes — reload Cursor MCP after host config changes"
    echo "CONFIGURED: yes | LIVE: no | ACTION: Tools & MCP → graphify off/on, then start a new chat; fallback Developer: Reload Window"
  fi
  if [[ "$receipt_has" == "true" ]]; then
    echo "RELOAD_RECEIPT: active (activation=${receipt_activation}, clear_eligible=${receipt_clear})"
  fi
  [[ "$ok" == true ]] || exit 1
fi

[[ "$ok" == true ]] || exit 1
