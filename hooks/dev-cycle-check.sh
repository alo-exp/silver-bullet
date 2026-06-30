#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
# shellcheck source=lib/hook-bootstrap.sh
[[ -n "$_lib_dir" ]] && source "${_lib_dir}/hook-bootstrap.sh"
if [[ -f "$_lib_dir/plugin-cache-guard.sh" ]]; then
  # shellcheck source=lib/plugin-cache-guard.sh
  source "$_lib_dir/plugin-cache-guard.sh"
fi
DEFAULT_PLANNING="${DEFAULT_PLANNING:-silver-quality-gates silver-context silver-plan}"
DEVOPS_DEFAULT_PLANNING="${DEVOPS_DEFAULT_PLANNING:-silver-blast-radius devops-quality-gates silver-context silver-plan}"

# Pre+PostToolUse hook (matcher: Edit|Write|MultiEdit|Bash)
# Enforces four-stage workflow gate — blocks source edits if planning skills incomplete.
# Plugin cache boundary uses plugin_cache="${SB_RUNTIME_PLUGIN_CACHE_ROOT}" (lib/dev-cycle-check/boundary.sh).

emit_block_jq_missing() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
}

# jq is required for JSON parsing (block SB-initiated projects; warn others)
if ! command -v jq >/dev/null 2>&1; then
  if declare -f sb_jq_enforcement_block_sb_initiated >/dev/null 2>&1; then
    sb_jq_enforcement_block_sb_initiated "dev-cycle-check" "emit_block_jq_missing"
  fi
  printf '{"hookSpecificOutput":{"message":"⚠️ Silver Bullet hooks require jq. Install: brew install jq (macOS) / apt install jq (Linux)"}}'
  exit 0
fi

_dcc_dir="${_lib_dir}/dev-cycle-check"

main() {
  # shellcheck source=lib/dev-cycle-check/emit.sh
  source "${_dcc_dir}/emit.sh"
  # shellcheck source=lib/dev-cycle-check/parse-input.sh
  source "${_dcc_dir}/parse-input.sh"
  # shellcheck source=lib/dev-cycle-check/boundary.sh
  source "${_dcc_dir}/boundary.sh"
  # shellcheck source=lib/dev-cycle-check/config-scope.sh
  source "${_dcc_dir}/config-scope.sh"
  # shellcheck source=lib/dev-cycle-check/scope-trivial.sh
  source "${_dcc_dir}/scope-trivial.sh"
  # shellcheck source=lib/dev-cycle-check/workflow-admission.sh
  source "${_dcc_dir}/workflow-admission.sh"
  # shellcheck source=lib/dev-cycle-check/planning-gate.sh
  source "${_dcc_dir}/planning-gate.sh"
}

if ! main; then
  printf '{"hookSpecificOutput":{"message":"⚠️ dev-cycle-check.sh encountered an error — continuing without blocking."}}'
  exit 0
fi
