#!/usr/bin/env bash
# dev-cycle-check module — auto-split
# --- Resolve config file by walking up from file's directory (or $PWD for Bash) ---
config_file=""
config_search_dir="$PWD"
if [[ -n "$file_path" ]]; then
  config_search_dir="$(dirname "$file_path")"
fi
if declare -f sb_find_project_config_from >/dev/null 2>&1; then
  config_file="$(sb_find_project_config_from "$config_search_dir" 2>/dev/null || true)"
else
  search_dir="$config_search_dir"
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
fi

if [[ -n "$config_file" ]]; then
  if declare -f sb_project_active >/dev/null 2>&1; then
    sb_project_active "$config_file" || exit 0
  elif declare -f sb_project_is_initiated >/dev/null 2>&1; then
    sb_project_is_initiated "$config_file" || exit 0
  fi
fi

# --- Read config values with defaults ---
src_pattern="/src/"
src_exclude_pattern='__tests__|\.test\.'
required_planning=""   # resolved below after reading active_workflow
active_workflow="full-dev-cycle"
SB_STATE_DIR="${SB_RUNTIME_STATE_DIR}"
state_file="${SB_STATE_DIR}/state"
trivial_file="${SB_STATE_DIR}/trivial"
verify_tests_state_file="${SB_STATE_DIR}/verify-tests-state"

if [[ -n "$config_file" ]]; then
  src_pattern=$(jq -r '.project.src_pattern // "/src/"' "$config_file")
  # Validate src_pattern: only allow safe path-segment patterns (prevents regex injection)
  if ! printf '%s' "$src_pattern" | grep -qE '^/[a-zA-Z0-9/_.|()-]*/?$'; then
    src_pattern="/src/"
  fi
  # Reject overly permissive patterns (SENTINEL-3.1)
  if printf '%s' "$src_pattern" | grep -qE '^\.\*$|^\.\+$|^/$|^$'; then
    src_pattern="/src/"
  fi
  src_exclude_pattern=$(jq -r '.project.src_exclude_pattern // "__tests__|\\.test\\."' "$config_file")
  # Validate exclude pattern: reject patterns > 200 chars (ReDoS mitigation)
  if [[ ${#src_exclude_pattern} -gt 200 ]]; then
    src_exclude_pattern='__tests__|\.test\.'
  fi
  # Validate exclude pattern: only allow safe characters (prevents regex injection)
  if ! printf '%s' "$src_exclude_pattern" | grep -qE '^[a-zA-Z0-9/_.\-|()\^$+?*]+$'; then
    src_exclude_pattern='__tests__|\.test\.'
  fi
  active_workflow=$(jq -r '.project.active_workflow // "full-dev-cycle"' "$config_file")
  if [[ "$active_workflow" == "devops-cycle" ]]; then
    custom_planning=$(jq -r '(.skills.required_planning_devops // .skills.required_planning // []) | join(" ")' "$config_file")
  else
    custom_planning=$(jq -r '(.skills.required_planning // []) | join(" ")' "$config_file")
  fi
  [[ -n "$custom_planning" ]] && required_planning="$custom_planning"
  cfg_state=$(jq -r '.state.state_file // ""' "$config_file")
  [[ -n "$cfg_state" ]] && state_file="${cfg_state/#\~/$HOME}"
  cfg_trivial=$(jq -r '.state.trivial_file // ""' "$config_file")
  [[ -n "$cfg_trivial" ]] && trivial_file="${cfg_trivial/#\~/$HOME}"
fi

# Codex shell edits often use relative workspace paths (e.g. `src/routes/x.js`)
# while the configured source gate is usually expressed as `/src/`.
# Keep a relaxed fallback so Bash-based file writes still count as source edits.
dcc_matches_src_scope() {
  local candidate="$1"
  local pattern="$2"
  if printf '%s' "$candidate" | grep -qE "$pattern"; then
    return 0
  fi

  local relaxed_pattern
  relaxed_pattern=$(printf '%s' "$pattern" | sed -E 's#(^|\|)/#\1#g; s#/$##')
  if [[ -n "$relaxed_pattern" && "$relaxed_pattern" != "$pattern" ]]; then
    if printf '%s' "$candidate" | grep -qE "(^|[[:space:][:punct:]])(${relaxed_pattern})(/|[[:space:][:punct:]]|$)"; then
      return 0
    fi
  fi

  return 1
}

dcc_collect_shell_in_scope_targets() {
  shell_in_scope_targets=()
  local target_path
  for target_path in "${shell_write_targets[@]:-}"; do
    if ! dcc_matches_src_scope "$target_path" "$src_pattern"; then
      continue
    fi
    if printf '%s' "$target_path" | grep -qE "$src_exclude_pattern"; then
      continue
    fi
    shell_in_scope_targets+=("$target_path")
  done
}

dcc_shell_payload_looks_read_only() {
  local payload="$1"
  declare -f sb_shell_command_looks_read_only >/dev/null 2>&1 || return 1
  sb_shell_command_looks_read_only "$payload" >/dev/null 2>&1
}

dcc_shell_command_shows_write_intent() {
  local payload="${1:-}"
  [[ -n "$payload" ]] || return 1
  if [[ ${#shell_write_targets[@]} -gt 0 ]]; then
    return 0
  fi
  if printf '%s' "$payload" | grep -qE '(>>|[[:space:]]>[^>&=]|\btee\b|\bcp\b|\bmv\b|\binstall\b|\bsed\b[[:space:]]+-[^[:space:];|&]*i|\bperl\b[[:space:]]+-[^[:space:];|&]*i|\btouch\b|\bchmod\b)'; then
    return 0
  fi
  return 1
}

dcc_shell_payload_is_sb_skill_adapter_invocation() {
  local payload="$1"
  [[ -n "$payload" ]] || return 1
  # Codex invokes SB skills through the package-local adapter. The adapter is
  # the workflow continuation channel, not a source edit; concrete redirects
  # and writes are still handled by shell_write_targets before this check.
  [[ "$payload" != *$'\n'* ]] || return 1
  python3 "${_lib_dir}/tool-input/skill_adapter_invocation.py" "$payload" >/dev/null 2>&1
}

dcc_workflow_id_from_shell_assignment() {
  local payload="$1"
  local first_line
  first_line=$(printf '%s' "$payload" | sed -n '1p')
  first_line="${first_line#"${first_line%%[![:space:]]*}"}"

  if [[ "$first_line" =~ ^export[[:space:]]+SB_WORKFLOW_ID=([A-Za-z0-9T_-]+)[[:space:]]*[\;] ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "$first_line" =~ ^env[[:space:]]+ ]]; then
    first_line="${first_line#env }"
    first_line="${first_line#"${first_line%%[![:space:]]*}"}"
  fi

  if [[ "$first_line" =~ (^|[[:space:]])SB_WORKFLOW_ID=([A-Za-z0-9T_-]+)[[:space:]] ]]; then
    printf '%s' "${BASH_REMATCH[2]}"
    return 0
  fi

  return 1
}

# Current-version configs can explicitly set the planning floor. Legacy
# configs are normalized to inherit the current default SB planning gates.
default_planning="$DEFAULT_PLANNING"
if [[ "$active_workflow" == "devops-cycle" ]]; then
  default_planning="$DEVOPS_DEFAULT_PLANNING"
fi
if declare -F sb_required_skills_normalize_configured_list >/dev/null 2>&1; then
  required_planning="$(sb_required_skills_normalize_configured_list "$config_file" "$required_planning" "$default_planning")"
elif [[ -z "$required_planning" ]]; then
  required_planning="$default_planning"
fi

# Env var overrides
state_file="${SILVER_BULLET_STATE_FILE:-$state_file}"
verify_tests_state_file="${SILVER_BULLET_VERIFY_TESTS_STATE_FILE:-$verify_tests_state_file}"

# Security: validate state file path stays within the host runtime state root (SB-002/SB-003)
if ! sb_runtime_path_is_state_scoped "$state_file"; then
  state_file="${SB_STATE_DIR}/state"
fi
if ! sb_runtime_path_is_state_scoped "$verify_tests_state_file"; then
  verify_tests_state_file="${SB_STATE_DIR}/verify-tests-state"
fi

# Security: validate trivial file path stays within the host runtime state root (SB-002/SB-003)
if ! sb_runtime_path_is_state_scoped "$trivial_file"; then
  trivial_file="${SB_STATE_DIR}/trivial"
fi

# --- Mid-session branch mismatch warning (F-09) ---
sb_branch_file="${SILVER_BULLET_BRANCH_FILE:-${SB_STATE_DIR}/branch}"
if ! sb_runtime_path_is_state_scoped "$sb_branch_file"; then
  sb_branch_file="${SB_STATE_DIR}/branch"
fi
if [[ -f "$sb_branch_file" && ! -L "$sb_branch_file" ]]; then
  stored_branch=$(cat "$sb_branch_file" 2>/dev/null || true)
  current_branch=$(git -C "$PWD" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  if [[ -n "$stored_branch" && -n "$current_branch" && "$stored_branch" != "$current_branch" ]]; then
    jq -n --arg s "$stored_branch" --arg c "$current_branch" \
      '{"hookSpecificOutput":{"message":"Warning: Branch mismatch -- state recorded for [\($s)] but current branch is [\($c)]. Restart the session or clear runtime context to reset."}}'
    # Warning only -- do not exit, let the rest of the hook proceed
  fi
fi

# --- Destructive command warning (F-04) ---
if [[ -n "$command_str" ]] && [[ ! -f "$trivial_file" || -L "$trivial_file" ]]; then
  if printf '%s' "$command_str" | grep -qE '\b(rm|mv)\b' && \
     ! printf '%s' "$command_str" | grep -qE "(${plugin_cache}|\.silver-bullet/|/tmp/|\.${SB_RUNTIME_NAME}/)"; then
    printf '{"hookSpecificOutput":{"message":"Warning: Destructive command detected (rm/mv on project files). Verify this is intentional before proceeding."}}'
    # Warning only -- do not block
  fi
fi
