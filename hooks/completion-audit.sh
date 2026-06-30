#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
# shellcheck source=lib/hook-bootstrap.sh
source "${_lib_dir}/hook-bootstrap.sh"
for _ca_mod in classify gates state-helpers planning-tier deploy-tier; do
  # shellcheck source=/dev/null
  source "${_lib_dir}/completion-audit/${_ca_mod}.sh"
done

# Read JSON from stdin
input=$(cat)

# Detect hook event type (PreToolUse vs PostToolUse) — best-effort without jq
hook_event="PostToolUse"
if command -v jq >/dev/null 2>&1; then
  hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse"')
fi

# Emit a block in the correct format for the hook event type
emit_block() {
  local reason="$1"
  local json_reason
  if command -v jq >/dev/null 2>&1; then
    json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  elif command -v python3 >/dev/null 2>&1; then
    json_reason=$(python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' <<<"$reason")
  else
    json_reason='"enforcement blocked"'
  fi
  sb_hook_audit_record "completion-audit" "$hook_event" "deny" "$reason" "${cmd:-}"
  if [[ "$hook_event" == "PreToolUse" ]]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
  else
    printf '{"decision":"block","reason":%s,"hookSpecificOutput":{"message":%s}}' "$json_reason" "$json_reason"
  fi
}

if ! command -v jq >/dev/null 2>&1; then
  _ca_config=""
  _ca_search="$PWD"
  while true; do
    if [[ -f "$_ca_search/.silver-bullet.json" && -f "$_ca_search/silver-bullet.md" ]]; then
      _ca_config="$_ca_search/.silver-bullet.json"
      break
    fi
    if [[ -d "$_ca_search/.git" ]] || [[ "$_ca_search" == "/" ]]; then
      break
    fi
    _ca_search=$(dirname "$_ca_search")
  done
  if [[ -n "$_ca_config" ]] && declare -f sb_project_is_initiated >/dev/null 2>&1 && sb_project_is_initiated "$_ca_config"; then
    sb_jq_enforcement_block "completion-audit" "emit_block"
    exit 0
  fi
  if printf '%s' "$input" | grep -qE 'git commit|git push|gh pr create|gh release create|\bdeploy\b'; then
    sb_jq_enforcement_block "completion-audit" "emit_block"
  fi
  printf '{"hookSpecificOutput":{"message":"⚠️  ENFORCEMENT INACTIVE — jq not installed. Install: brew install jq (macOS) / apt install jq (Linux). All Silver Bullet enforcement hooks are disabled until jq is available."}}'
  exit 0
fi

emit_warn() {
  local reason="$1"
  jq -n --arg m "$reason" '{"hookSpecificOutput":{"message":$m}}'
}

capture_evidence_warn() {
  EVIDENCE_SCHEMA_WARN="$1"
}

# Extract the command being run
if declare -f sb_tool_name >/dev/null 2>&1; then
  tool_name="$(sb_tool_name "$input")"
else
  tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""')
fi
if declare -f sb_tool_is_shell_like >/dev/null 2>&1; then
  sb_tool_is_shell_like "$tool_name" || exit 0
fi
if declare -f sb_tool_command_string >/dev/null 2>&1; then
  cmd="$(sb_tool_command_string "$input")"
else
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
fi
[[ -z "$cmd" ]] && exit 0

ca_classify_command "$cmd" || exit 0

# ── Error handler: warn and exit 0 on unexpected failure ─────────────────────
trap 'printf "{\"hookSpecificOutput\":{\"message\":\"⚠️  completion-audit.sh: unexpected error — skipping check\"}}" ; exit 0' ERR

# ── Resolve config file by walking up from $PWD ──────────────────────────────
config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" ]] && [[ -f "$search_dir/silver-bullet.md" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    break
  fi
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir=$(dirname "$search_dir")
done

# No config → project not set up with Silver Bullet — silent exit
[[ -z "$config_file" ]] && exit 0

if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
  sb_project_is_initiated "$config_file" || exit 0
fi

# ── Read config values ────────────────────────────────────────────────────────
SB_STATE_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_STATE_DIR"
state_file="${SB_STATE_DIR}/state"
trivial_file="${SB_STATE_DIR}/trivial"
quality_gate_state_file="${SB_STATE_DIR}/quality-gate-state"
verify_tests_state_file="${SB_STATE_DIR}/verify-tests-state"
required_planning_cfg=""
required_deploy_cfg=""
required_deploy_devops_cfg=""
required_planning_devops_cfg=""
active_workflow="full-dev-cycle"
release_require_plugin_runtime_matrix="false"
release_require_pre_release_quality_gate="false"

sb_default_state="${SB_STATE_DIR}/state"
sb_default_trivial="${SB_STATE_DIR}/trivial"
config_vals=$(jq -r --arg ds "$sb_default_state" --arg dt "$sb_default_trivial" '[
  (.state.state_file // $ds),
  (.state.trivial_file // $dt),
  ((.skills.required_planning // []) | join(" ")),
  ((.skills.required_planning_devops // []) | join(" ")),
  ((.skills.required_deploy // []) | join(" ")),
  ((.skills.required_deploy_devops // []) | join(" ")),
  (.project.active_workflow // "full-dev-cycle"),
  (.release.quality_gate_state_file // ""),
  ((.release.require_plugin_runtime_matrix // false) | tostring),
  ((.release.require_pre_release_quality_gate // false) | tostring)
] | join("\n")' "$config_file")

state_file=$(printf '%s' "$config_vals" | sed -n '1p')
state_file="${state_file/#\~/$HOME}"
trivial_file=$(printf '%s' "$config_vals" | sed -n '2p')
trivial_file="${trivial_file/#\~/$HOME}"
required_planning_cfg=$(printf '%s' "$config_vals" | sed -n '3p')
required_planning_devops_cfg=$(printf '%s' "$config_vals" | sed -n '4p')
required_deploy_cfg=$(printf '%s' "$config_vals" | sed -n '5p')
required_deploy_devops_cfg=$(printf '%s' "$config_vals" | sed -n '6p')
active_workflow=$(printf '%s' "$config_vals" | sed -n '7p')
cfg_quality_gate_state_file=$(printf '%s' "$config_vals" | sed -n '8p')
[[ -n "$cfg_quality_gate_state_file" ]] && quality_gate_state_file="${cfg_quality_gate_state_file/#\~/$HOME}"
release_require_plugin_runtime_matrix=$(printf '%s' "$config_vals" | sed -n '9p')
release_require_pre_release_quality_gate=$(printf '%s' "$config_vals" | sed -n '10p')

# Env var override for state file
state_file="${SILVER_BULLET_STATE_FILE:-$state_file}"
# Env var override for pre-release quality gate file
quality_gate_state_file="${SILVER_BULLET_QUALITY_GATE_STATE_FILE:-$quality_gate_state_file}"
# Env var override for the test execution gate file
verify_tests_state_file="${SILVER_BULLET_VERIFY_TESTS_STATE_FILE:-$verify_tests_state_file}"

# Security: validate paths stay within the host runtime state root (SB-002/SB-003)
if ! sb_runtime_path_is_state_scoped "$state_file"; then
  state_file="${SB_STATE_DIR}/state"
fi
if ! sb_runtime_path_is_state_scoped "$trivial_file"; then
  trivial_file="${SB_STATE_DIR}/trivial"
fi
if ! sb_runtime_path_is_state_scoped "$quality_gate_state_file"; then
  quality_gate_state_file="${SB_STATE_DIR}/quality-gate-state"
fi
if ! sb_runtime_path_is_state_scoped "$verify_tests_state_file"; then
  verify_tests_state_file="${SB_STATE_DIR}/verify-tests-state"
fi

# ── Trivial bypass (reject symlinks) ─────────────────────────────────────────
if [[ -f "$trivial_file" && ! -L "$trivial_file" ]]; then
  exit 0
fi
# ── Detect current git branch ─────────────────────────────────────────────────
current_branch=""
current_branch=$(git -C "$PWD" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
# Validate branch name: only allow safe characters
if [[ -n "$current_branch" ]] && ! printf '%s' "$current_branch" | grep -qE '^[a-zA-Z0-9/_.-]+$'; then
  current_branch=""
fi
on_main=false
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
  on_main=true
fi

# ── Read state file ───────────────────────────────────────────────────────────
state_contents=""
[[ -f "$state_file" ]] && state_contents=$(cat "$state_file")

if [[ "$is_intermediate" == true ]]; then
  ca_run_planning_tier_gate
  exit 0
fi

ca_run_deploy_tier_gate
