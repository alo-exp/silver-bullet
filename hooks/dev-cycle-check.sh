#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# Load shared workflow utilities (TD-1: single source of truth for Flow Log regex)
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -f "$_lib_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_lib_dir/runtime-paths.sh"
fi
if [[ -f "$_lib_dir/plugin-cache-guard.sh" ]]; then
  # shellcheck source=lib/plugin-cache-guard.sh
  source "$_lib_dir/plugin-cache-guard.sh"
fi
if [[ -f "$_lib_dir/required-skills.sh" ]]; then
  # shellcheck source=lib/required-skills.sh
  # shellcheck disable=SC1091
  source "$_lib_dir/required-skills.sh"
fi
DEFAULT_PLANNING="${DEFAULT_PLANNING:-silver-quality-gates}"
DEVOPS_DEFAULT_PLANNING="${DEVOPS_DEFAULT_PLANNING:-silver-blast-radius devops-quality-gates}"
if [[ -f "$_lib_dir/hook-audit.sh" ]]; then
  # shellcheck source=lib/hook-audit.sh
  source "$_lib_dir/hook-audit.sh"
fi
if [[ -f "$_lib_dir/tool-input.sh" ]]; then
  # shellcheck source=lib/tool-input.sh
  source "$_lib_dir/tool-input.sh"
fi
if [[ -n "$_lib_dir" && -f "$_lib_dir/workflow-utils.sh" ]]; then
  source "$_lib_dir/workflow-utils.sh"
fi
if ! declare -f count_flow_log_rows >/dev/null 2>&1; then
  count_flow_log_rows() { grep -cE '^\| [0-9]+ \|' "$1" 2>/dev/null || echo 0; }
  count_complete_flow_rows() { grep -cE '^\| [^|]+\| [^|]+\| (complete|skipped)' "$1" 2>/dev/null || echo 0; }
fi

# shellcheck source=lib/skill-discovery.sh
if [[ -f "$_lib_dir/skill-discovery.sh" ]]; then
  # shellcheck disable=SC1091
  source "$_lib_dir/skill-discovery.sh"
fi
if ! declare -f sb_skill_is_installed >/dev/null 2>&1; then
  sb_skill_is_installed() { return 0; }
fi

# Pre+PostToolUse hook (matcher: Edit|Write|MultiEdit|Bash)
# Enforces four-stage workflow gate — blocks source edits if planning skills incomplete.

# Security: restrict file creation permissions (user-only)
umask 0077

if [[ -f "$_lib_dir/jq-gate.sh" ]]; then
  # shellcheck source=lib/jq-gate.sh
  source "$_lib_dir/jq-gate.sh"
fi
if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
fi

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

# Wrap everything in a function so any failure is caught
main() {
  # Read JSON from stdin
  input=$(cat)

  # Detect hook event type (PreToolUse vs PostToolUse)
  hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse"')

  # Emit a block in the correct format for the hook event type
  emit_block() {
    local reason="$1"
    local json_reason
    json_reason=$(printf '%s' "$reason" | jq -Rs '.')
    sb_hook_audit_record "dev-cycle-check" "$hook_event" "deny" "$reason" "${file_path:-${command_str:-}}"
    if [[ "$hook_event" == "PreToolUse" ]]; then
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
      if [[ "${SB_KAY_HOOK_BRIDGE_INVOKED:-}" == "1" ]]; then
        printf '%s\n' "$reason" >&2
        exit 2
      fi
    else
      printf '{"decision":"block","reason":%s,"hookSpecificOutput":{"message":%s}}' "$json_reason" "$json_reason"
    fi
  }

  resolve_repo_root() {
    local d="$PWD"
    while [[ "$d" != "/" && -n "$d" ]]; do
      if [[ -d "$d/.planning" || -d "$d/.git" ]]; then
        printf '%s' "$d"
        return 0
      fi
      d=$(dirname "$d")
    done
    return 1
  }

  # --- Determine file path or command based on tool type ---
  if declare -f sb_tool_file_path >/dev/null 2>&1; then
    file_path="$(sb_tool_file_path "$input")"
  else
    file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_response.filePath // ""')
  fi
  command_str=""

  if [[ -z "$file_path" ]]; then
    # Shell-like tool — extract command
    if declare -f sb_tool_command_string >/dev/null 2>&1; then
      command_str="$(sb_tool_command_string "$input")"
    else
      command_str=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
    fi
    [[ -z "$command_str" ]] && exit 0
  fi
  if declare -f sb_tool_name >/dev/null 2>&1; then
    tool_name="$(sb_tool_name "$input")"
  else
    tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""')
  fi
  patch_file_paths=()
  if [[ "$tool_name" == "apply_patch" ]] && declare -f sb_tool_patch_paths >/dev/null 2>&1; then
    while IFS= read -r patch_path; do
      [[ -n "$patch_path" ]] && patch_file_paths+=("$patch_path")
    done < <(sb_tool_patch_paths "$input" 2>/dev/null || true)
    if [[ -z "$file_path" && ${#patch_file_paths[@]} -gt 0 ]]; then
      file_path="${patch_file_paths[0]}"
    fi
  fi
  if [[ -z "$file_path" ]] && declare -f sb_tool_is_shell_like >/dev/null 2>&1; then
    sb_tool_is_shell_like "$tool_name" || exit 0
  fi

  shell_script_path=""
  shell_script_dir="$PWD"
  shell_script_body=""
  shell_write_targets=()
  shell_in_scope_targets=()
  shell_target_scope_fallback=false

  collect_shell_write_targets() {
    local payload="$1"
    local base_dir="$2"
    local target_path
    [[ -n "$payload" ]] || return 0
    if ! declare -f sb_shell_candidate_write_paths >/dev/null 2>&1; then
      return 0
    fi
    while IFS= read -r target_path; do
      [[ -n "$target_path" ]] || continue
      shell_write_targets+=("$target_path")
    done < <(sb_shell_candidate_write_paths "$payload" "$base_dir" 2>/dev/null || true)
  }

  shell_writes_to_exact_path() {
    local expected="$1"
    local target_path
    for target_path in "${shell_write_targets[@]:-}"; do
      [[ "$target_path" == "$expected" ]] && return 0
    done
    return 1
  }

  shell_writes_under_prefix() {
    local prefix="${1%/}"
    local target_path
    for target_path in "${shell_write_targets[@]:-}"; do
      [[ "$target_path" == "$prefix" || "$target_path" == "$prefix"/* ]] && return 0
    done
    return 1
  }

  if [[ -z "$file_path" && -n "$command_str" ]]; then
    if declare -f sb_shell_invoked_script_path >/dev/null 2>&1; then
      shell_script_path="$(sb_shell_invoked_script_path "$command_str" "$PWD" 2>/dev/null || true)"
    fi
    if [[ -n "$shell_script_path" && -f "$shell_script_path" ]]; then
      shell_script_dir="$(dirname "$shell_script_path")"
      shell_script_body="$(cat "$shell_script_path" 2>/dev/null || true)"
    fi
    collect_shell_write_targets "$command_str" "$PWD"
    if [[ -n "$shell_script_body" ]]; then
      collect_shell_write_targets "$shell_script_body" "$PWD"
      collect_shell_write_targets "$shell_script_body" "$shell_script_dir"
    fi
  fi

  # --- Third-party plugin boundary (§8) — HARD STOP on upstream plugin edits ---
  plugin_cache="${SB_RUNTIME_PLUGIN_CACHE_ROOT}"
  plugin_boundary_is_uninstall_cleanup() {
    if [[ -n "${command_str:-}" ]] && declare -f sb_plugin_cache_command_is_uninstall_cleanup >/dev/null 2>&1; then
      sb_plugin_cache_command_is_uninstall_cleanup "$command_str" "${shell_write_targets[@]:-}"
      return $?
    fi
    return 1
  }
  if [[ -n "$file_path" ]] && [[ "$file_path" == "$plugin_cache"/* ]]; then
    msg="🚫 THIRD-PARTY PLUGIN BOUNDARY VIOLATION — You are attempting to edit a file inside the plugin cache:
$(basename "$file_path")

Silver Bullet NEVER modifies upstream plugin files. Implement the change in Silver Bullet's own layer instead:
  • Workflow instruction (templates/workflows/*.md)
  • Hook (hooks/*.sh)
  • Silver Bullet skill (skills/*/SKILL.md)

See CLAUDE.md §8 for details."
    emit_block "$msg"
    exit 0
  elif [[ -n "$command_str" ]]; then
    # F-07: Block Bash commands that write into the plugin cache.
    # Read-only access to upstream templates is allowed so Silver Bullet can
    # copy them into the project workspace during initialization.
    # Uninstall cleanup is allowed when installed_plugins.json no longer references the path (#222).
    if shell_writes_under_prefix "$plugin_cache"; then
      if ! plugin_boundary_is_uninstall_cleanup; then
        emit_block "🚫 THIRD-PARTY PLUGIN BOUNDARY VIOLATION via Bash command — Silver Bullet NEVER modifies upstream plugin files. See CLAUDE.md §8."
        exit 0
      fi
    fi
    if printf '%s' "$command_str" | grep -qE "$plugin_cache"; then
      plugin_write_pattern='([[:space:]](>>|>)[[:space:]]*"?'"$plugin_cache"'|\b(cp|mv|rm|chmod|install|tee)\b.*"?'"$plugin_cache"'|\b(sed|perl)\b.*-i.*"?'"$plugin_cache"')'
      if printf '%s' "$command_str" | grep -qE "$plugin_write_pattern"; then
        if ! plugin_boundary_is_uninstall_cleanup; then
          emit_block "🚫 THIRD-PARTY PLUGIN BOUNDARY VIOLATION via Bash command — Silver Bullet NEVER modifies upstream plugin files. See CLAUDE.md §8."
          exit 0
        fi
      fi
    fi
  fi

  # --- Silver Bullet hook self-protection ─────────────────────────────────────
  # Block edits to SB's own enforcement hooks when running from an installed plugin copy.
  _sb_hooks_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ "$_sb_hooks_script" == "${SB_RUNTIME_HOME_ROOT}"* ]]; then
    sb_plugin_root="${SB_PLUGIN_ROOT:-$(cd "${_sb_hooks_script}/.." && pwd)}"
    sb_hooks_dir="${sb_plugin_root}/hooks"
    if [[ -n "$file_path" ]]; then
      if [[ "$file_path" == "${sb_hooks_dir}/"* ]] || [[ "$file_path" == "${sb_plugin_root}/hooks.json" ]]; then
        emit_block "Silver Bullet NEVER modifies its own enforcement hooks. This would disable process compliance. If you need to reconfigure, use /silver:init."
        exit 0
      fi
    elif [[ -n "$command_str" ]]; then
      if shell_writes_under_prefix "$sb_hooks_dir" || shell_writes_to_exact_path "${sb_plugin_root}/hooks.json" || \
         { printf '%s' "$command_str" | grep -qE "(${sb_hooks_dir}/|${sb_plugin_root}/hooks\.json)" && \
           printf '%s' "$command_str" | grep -qE '(>>|\s>[^>&=]|\btee\b|\bcp\b|\bmv\b|\brm\b|\bchmod\b|\bsed\b[^$]*-i|\bperl\b[^$]*-i|\binstall\b)'; }; then
        emit_block "Silver Bullet NEVER modifies its own enforcement hooks. This would disable process compliance. If you need to reconfigure, use /silver:init."
        exit 0
      fi
    fi
  fi

  # Fallback: detect hooks path by pattern under the host runtime home.
  # IMPORTANT: Only block paths that are provably inside the host runtime root (the installed
  # plugin location). Do NOT use a repo-name pattern — that would also match the silver-
  # bullet source repo's own hooks/ directory and prevent legitimate source edits.
  # Check both file_path (Edit/Write) and command_str (Bash) for hooks path pattern
  if [[ -n "$file_path" ]] && [[ "$file_path" == "${SB_RUNTIME_HOME_ROOT}/"* ]] &&        printf '%s' "$file_path" | grep -qE '/hooks/'; then
    emit_block "Silver Bullet NEVER modifies its own enforcement hooks. This would disable process compliance. If you need to reconfigure, use /silver:init."
    exit 0
  fi
  if [[ -n "$command_str" ]] && { \
    { shell_writes_under_prefix "${SB_RUNTIME_HOME_ROOT}" && \
      printf '%s\n%s' "$command_str" "$shell_script_body" | grep -qE '/hooks/'; } || \
    { printf '%s' "$command_str" | grep -qE "${SB_RUNTIME_HOME_ROOT}/[^ ]*/hooks/" && \
      printf '%s' "$command_str" | grep -qE '(>>|\s>[^>&=]|\btee\b|\bcp\b|\bmv\b|\brm\b|\bchmod\b|\bsed\b[^$]*-i|\bperl\b[^$]*-i|\binstall\b)'; }; \
  }; then
    emit_block "Silver Bullet NEVER modifies its own enforcement hooks. This would disable process compliance. If you need to reconfigure, use /silver:init."
    exit 0
  fi

  # --- State file tamper prevention (SB-008) ──────────────────────────────────
  # Block direct Edit/Write to Silver Bullet state files and Bash write patterns.
  # This prevents bypassing enforcement by manipulating the state file directly.
  # Security note: if state/config files are unreadable, we emit a WARNING (not a
  # block) — blocking on unreadable state would lock users out. The outer
  # trap 'exit 0' ERR provides graceful degradation for all unexpected failures.
  SB_STATE_DIR_EARLY="${SB_RUNTIME_STATE_DIR}"
  _runtime_root_regex=$(printf '%s' "${SB_RUNTIME_HOME_ROOT}" | sed 's/[[][\\.^$*+?(){}|]/\\&/g')
  _state_dir_regex=$(printf '%s' "${SB_RUNTIME_STATE_DIR}" | sed 's/[[][\\.^$*+?(){}|]/\\&/g')

  if [[ -n "$file_path" ]]; then
    # Edit/Write targeting the state directory → hard block
    if [[ "$file_path" == "${SB_STATE_DIR_EARLY}/"* ]]; then
      emit_block "🚫 STATE TAMPER BLOCKED — Direct edits to Silver Bullet state files are not permitted.

Skills are recorded automatically when invoked through the active runtime's SB-recognized skill invocation channel. Modifying state files directly bypasses workflow enforcement.

To reset the workflow state, remove the file from your terminal (not from Claude):
      rm ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state"
      exit 0
    fi
  elif [[ -n "$command_str" ]]; then
    # Bash write to the state file -> block. Plain mentions in git/gh message
    # strings are allowed; only real redirections / tee writes are blocked.
    cmd_first_line_tamper=$(printf '%s' "$command_str" | head -1)
    state_path="${SB_STATE_DIR_EARLY}/state"
    if ! printf '%s' "$cmd_first_line_tamper" | grep -qE '^\s*(git\s|gh\s)' && \
       { { printf '%s' "$cmd_first_line_tamper" | grep -qE '(>>|\s>[^>&=]|\btee\b)' && \
           printf '%s' "$cmd_first_line_tamper" | grep -qF "$state_path"; } || \
         shell_writes_to_exact_path "$state_path"; }; then
      emit_block "🚫 STATE TAMPER BLOCKED — Writing to Silver Bullet state files bypasses workflow enforcement.

Skills are recorded automatically when invoked through the active runtime's SB-recognized skill invocation channel. Do not write to state files directly.

To reset workflow state intentionally, run in your terminal:
      rm ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state"
      exit 0
    fi
  fi

  # --- Resolve config file by walking up from file's directory (or $PWD for Bash) ---
  config_file=""
  if [[ -n "$file_path" ]]; then
    search_dir=$(dirname "$file_path")
  else
    search_dir="$PWD"
  fi
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
  matches_src_scope() {
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

  collect_shell_in_scope_targets() {
    shell_in_scope_targets=()
    local target_path
    for target_path in "${shell_write_targets[@]:-}"; do
      if ! matches_src_scope "$target_path" "$src_pattern"; then
        continue
      fi
      if printf '%s' "$target_path" | grep -qE "$src_exclude_pattern"; then
        continue
      fi
      shell_in_scope_targets+=("$target_path")
    done
  }

  shell_payload_looks_read_only() {
    local payload="$1"
    declare -f sb_shell_command_looks_read_only >/dev/null 2>&1 || return 1
    sb_shell_command_looks_read_only "$payload" >/dev/null 2>&1
  }

  shell_payload_is_sb_skill_adapter_invocation() {
    local payload="$1"
    [[ -n "$payload" ]] || return 1
    # Codex invokes SB skills through the package-local adapter. The adapter is
    # the workflow continuation channel, not a source edit; concrete redirects
    # and writes are still handled by shell_write_targets before this check.
    [[ "$payload" != *$'\n'* ]] || return 1
    python3 - "$payload" <<'PY' >/dev/null 2>&1
import pathlib
import re
import shlex
import sys

payload = sys.argv[1]
assignment_re = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$")
try:
    lexer = shlex.shlex(payload, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    tokens = list(lexer)
except Exception:
    raise SystemExit(1)

if not tokens:
    raise SystemExit(1)
if any(token in {";", "|", "||", "&", "&&", ">", ">>", "<", "<<"} for token in tokens):
    raise SystemExit(1)

idx = 0
if tokens[idx] == "env":
    idx += 1
while idx < len(tokens) and assignment_re.match(tokens[idx]):
    idx += 1
if idx + 1 >= len(tokens):
    raise SystemExit(1)

command = tokens[idx]
if not (command == "scripts/silver-bullet" or command.endswith("/scripts/silver-bullet")):
    raise SystemExit(1)
if tokens[idx + 1] != "invoke-skill":
    raise SystemExit(1)

print("adapter")
PY
  }

  workflow_id_from_shell_assignment() {
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

  # --- Check if file/command matches src_pattern ---
  if [[ ${#patch_file_paths[@]} -gt 0 ]]; then
    patch_in_scope=false
    for patch_path in "${patch_file_paths[@]}"; do
      if matches_src_scope "$patch_path" "$src_pattern" && ! printf '%s' "$patch_path" | grep -qE "$src_exclude_pattern"; then
        file_path="$patch_path"
        patch_in_scope=true
        break
      fi
    done
    [[ "$patch_in_scope" == true ]] || exit 0
  elif [[ -n "$file_path" ]]; then
    # File edit/write event — check file path
    if ! matches_src_scope "$file_path" "$src_pattern"; then
      exit 0
    fi
    # Check exclude pattern (test files)
    if printf '%s' "$file_path" | grep -qE "$src_exclude_pattern"; then
      exit 0
    fi
  else
    shell_payload_is_sb_skill_adapter_invocation "$command_str" && exit 0
    collect_shell_in_scope_targets
    if [[ ${#shell_write_targets[@]} -gt 0 ]]; then
      # When we can resolve concrete write targets, scope Bash enforcement to the
      # actual destination paths instead of matching arbitrary file content.
      [[ ${#shell_in_scope_targets[@]} -gt 0 ]] || exit 0
    else
      if [[ -n "$shell_script_body" ]]; then
        shell_payload_looks_read_only "$shell_script_body" && exit 0
      else
        shell_payload_looks_read_only "$command_str" && exit 0
      fi
      # Fallback for opaque shell commands where no concrete write target can be
      # resolved from the command text or sourced script bodies.
      if ! matches_src_scope "$command_str" "$src_pattern"; then
        exit 0
      fi
      # Check exclude pattern for Bash commands too
      if printf '%s' "$command_str" | grep -qE "$src_exclude_pattern"; then
        exit 0
      fi
      shell_target_scope_fallback=true
    fi
  fi

  # --- Check trivial file override ---
  if [[ -f "$trivial_file" && ! -L "$trivial_file" ]]; then
    exit 0
  fi

  # --- Invalidate fresh test execution when the source actually changed ---
  # PostToolUse on Edit/Write/MultiEdit means the edit has already landed and
  # the release gate must be refreshed before final delivery.
  if [[ "$hook_event" == "PostToolUse" ]]; then
    invalidate_verify_tests=false
    if [[ -n "$file_path" ]]; then
      case "$tool_name" in
        Edit|Write|MultiEdit|apply_patch)
          invalidate_verify_tests=true
          ;;
      esac
    elif [[ -n "$command_str" ]]; then
      if [[ ${#shell_in_scope_targets[@]} -gt 0 ]]; then
        invalidate_verify_tests=true
      elif [[ "$shell_target_scope_fallback" == true ]] && \
           printf '%s' "$command_str" | grep -qE '(>>|[[:space:]]>[^>&=]|\btee\b|\bcp\b|\bmv\b|\binstall\b|\bsed\b[^$]*-i|\bperl\b[^$]*-i)'; then
        invalidate_verify_tests=true
      fi
    fi
    if [[ "$invalidate_verify_tests" == true ]]; then
      rm -f -- "$verify_tests_state_file" 2>/dev/null || true
    fi
  fi

  # --- Auto-detect trivial changes (per-edit, no persistent bypass) ---
  if [[ -n "$file_path" ]]; then
    # Non-logic file extensions inside src/ are trivial
    # EXCEPTION: In devops-cycle, .yml/.yaml/.json are infrastructure code — NOT exempt
    if [[ "$active_workflow" == "devops-cycle" ]]; then
      case "$file_path" in
        *.md|*.txt|*.css|*.svg|*.env|*.env.*|*.ini|*.cfg|*.conf|*.lock)
          printf '{"hookSpecificOutput":{"message":"ℹ️ Non-logic file — enforcement skipped for this edit."}}'
          exit 0
          ;;
      esac
    else
      case "$file_path" in
        *.json|*.yml|*.yaml|*.md|*.txt|*.css|*.svg|*.env|*.env.*|*.toml|*.ini|*.cfg|*.conf|*.lock)
          printf '{"hookSpecificOutput":{"message":"ℹ️ Non-logic file — enforcement skipped for this edit."}}'
          exit 0
          ;;
      esac
    fi

    # Small edit changes (combined old+new < 100 chars) are trivial (typo fixes)
    # Threshold reduced from 300 to 100 to prevent bypassing enforcement via incremental changes
    if [[ "$tool_name" == "Edit" ]]; then
      old_str_len=$(printf '%s' "$input" | jq -r '.tool_input.old_string // "" | length')
      new_str_len=$(printf '%s' "$input" | jq -r '.tool_input.new_string // "" | length')
      combined_len=$((old_str_len + new_str_len))
      if [[ $combined_len -gt 0 && $combined_len -lt 100 ]]; then
        printf '{"hookSpecificOutput":{"message":"ℹ️ Small edit (%d chars) — enforcement skipped for this edit."}}'  "$combined_len"
        exit 0
      fi
    fi
  elif [[ ${#shell_in_scope_targets[@]} -gt 0 ]]; then
    shell_non_logic_only=true
    for target_path in "${shell_in_scope_targets[@]}"; do
      if [[ "$active_workflow" == "devops-cycle" ]]; then
        case "$target_path" in
          *.md|*.txt|*.css|*.svg|*.env|*.env.*|*.ini|*.cfg|*.conf|*.lock) ;;
          *) shell_non_logic_only=false ;;
        esac
      else
        case "$target_path" in
          *.json|*.yml|*.yaml|*.md|*.txt|*.css|*.svg|*.env|*.env.*|*.toml|*.ini|*.cfg|*.conf|*.lock) ;;
          *) shell_non_logic_only=false ;;
        esac
      fi
      [[ "$shell_non_logic_only" == true ]] || break
    done
    if [[ "$shell_non_logic_only" == true ]]; then
      printf '{"hookSpecificOutput":{"message":"ℹ️ Non-logic file — enforcement skipped for this edit."}}'
      exit 0
    fi
  fi

  # --- Composed-workflow admission control (Pass 2) ---
  # When a composed workflow is active in `.planning/workflows/<id>.md`, the
  # current session must present a matching SB_WORKFLOW_ID before any
  # non-trivial source edit can reach the legacy planning gate. This is the
  # admission check that prevents direct edits from bypassing /silver-routed
  # workflows. Legacy skill markers remain the fallback when no composed
  # workflow is active at all.
  if [[ "$hook_event" == "PreToolUse" ]]; then
    repo_root=$(resolve_repo_root 2>/dev/null || true)
    active_workflows=()
    if [[ -n "$repo_root" ]]; then
      wf_dir="$repo_root/.planning/workflows"
      if [[ -d "$wf_dir" && ! -L "$wf_dir" ]]; then
        shopt -s nullglob
        for _wf in "$wf_dir"/*.md; do
          [[ -f "$_wf" && ! -L "$_wf" ]] && active_workflows+=("$_wf")
        done
        shopt -u nullglob

        if [[ ${#active_workflows[@]} -gt 0 ]]; then
          active_id="${SB_WORKFLOW_ID:-}"
          if [[ -z "$active_id" && -n "$command_str" ]]; then
            active_id="$(workflow_id_from_shell_assignment "$command_str" 2>/dev/null || true)"
          fi
          if [[ -z "$active_id" ]]; then
            active_names=""
            for _wf in "${active_workflows[@]}"; do
              active_names+="  • $(basename "$_wf" .md)"$'\n'
            done
            emit_block "$(printf '🛑 WORKFLOW ADMISSION — active composed workflow(s) exist, but SB_WORKFLOW_ID is unset.\n\nActive composed workflow(s):\n%s\nUse /silver to resume the matching composed workflow before making source edits.' "$active_names")"
            exit 0
          fi

          if ! [[ "$active_id" =~ ^[0-9]{8}T[0-9]{6}Z-[a-z0-9]+-[a-z0-9-]+$ ]]; then
            emit_block "$(printf '🛑 WORKFLOW ADMISSION — SB_WORKFLOW_ID has invalid format: %s\n\nExpected: <UTCcompact>-<6char>-<composer>' "$active_id")"
            exit 0
          fi

          active_file="$wf_dir/$active_id.md"
          if [[ ! -f "$active_file" || -L "$active_file" ]]; then
            emit_block "$(printf '🛑 WORKFLOW ADMISSION — no active workflow file matches SB_WORKFLOW_ID=%s.\n\nUse /silver to resume the active composed workflow, or start a new composed workflow before editing source code.' "$active_id")"
            exit 0
          fi
        fi
      fi

      # F-06: no composed workflow — block logic src edits that bypass /silver routing
      if [[ ${#active_workflows[@]} -eq 0 ]]; then
        if [[ -n "$config_file" ]] && declare -f sb_project_is_initiated >/dev/null 2>&1; then
          if sb_project_is_initiated "$config_file"; then
            logic_edit=false
            if [[ -n "$file_path" ]]; then
              case "$file_path" in
                *.py|*.ts|*.tsx|*.js|*.jsx|*.go|*.rs|*.sh|*.rb|*.java|*.kt|*.swift|*.tf|*.hcl|*.c|*.cpp|*.h)
                  logic_edit=true ;;
              esac
            elif [[ ${#shell_in_scope_targets[@]} -gt 0 ]]; then
              logic_edit=true
            fi
            if [[ "$logic_edit" == true ]]; then
              jq -n --arg m '🛑 WORKFLOW ADVISORY — logic source edit with no active composed workflow. Start /silver:fast (Tier 2+) or a composer workflow before application code changes. Tier 1 applies only to docs/config typo fixes.' \
                '{"hookSpecificOutput":{"message":$m}}'
            fi
          fi
        fi
      fi
    fi
  fi

  # --- Read state file and determine stage ---
  completed_skills=""
  if [[ -f "$state_file" ]]; then
    completed_skills=$(cat "$state_file")
  fi

  # Helper: check if a skill is in the completed list
  has_skill() {
    if declare -F sb_required_skill_is_recorded >/dev/null 2>&1; then
      sb_required_skill_is_recorded "$completed_skills" "$1"
      return $?
    fi
    printf '%s\n' "$completed_skills" | grep -Fqx -- "$1" 2>/dev/null
  }

  # --- Check required planning skills ---
  missing_skills=""
  unavailable_skills=""
  for skill in $required_planning; do
    if ! has_skill "$skill"; then
      if sb_skill_is_installed "$skill"; then
        if [[ -n "$missing_skills" ]]; then
          missing_skills="$missing_skills $skill"
        else
          missing_skills="$skill"
        fi
      else
        if [[ -n "$unavailable_skills" ]]; then
          unavailable_skills="$unavailable_skills $skill"
        else
          unavailable_skills="$skill"
        fi
      fi
    fi
  done

  # --- Four-stage gate ---
  if [[ -n "$missing_skills" ]]; then
    # Stage A: missing planning skills — HARD STOP
    missing_display=""
    for ms in $missing_skills; do
      missing_display="${missing_display}❌ ${ms}\\n"
    done
    stage_a_msg=$(printf '🚫 HARD STOP — Planning incomplete. Missing skills:\n%s\nRun the missing planning skills before editing source code.' "$missing_display")
    if [[ -n "$unavailable_skills" ]]; then
      unavailable_display=""
      for us in $unavailable_skills; do
        unavailable_display="${unavailable_display}⚠️ ${us} (not installed anywhere invocable)\n"
      done
      stage_a_msg=$(printf '%s\n\nIgnored required skills:\n%s\nInstall them if you want them enforced.' "$stage_a_msg" "$unavailable_display")
    fi
    emit_block "$stage_a_msg"
    exit 0
  fi

  if [[ -n "$unavailable_skills" ]]; then
    unavailable_display=""
    for us in $unavailable_skills; do
      unavailable_display="${unavailable_display}⚠️ ${us} (not installed anywhere invocable)\n"
    done
    stage_a_msg=$(printf '⚠️ Planning skills not installed anywhere invocable, so they were not enforced:\n%s\nProceeding with source edits.' "$unavailable_display")
    sb_hook_audit_record "dev-cycle-check" "$hook_event" "allow" "$stage_a_msg" "${file_path:-${command_str:-}}"
    jq -n --arg m "$stage_a_msg" '{"hookSpecificOutput":{"message":$m}}'
    exit 0
  fi

  # --- Phase skip detection (after HARD STOP so Stage A always fires first) ---
  # Derive post-review/finalization skills from config required_deploy; fall back to
  # hardcoded defaults. Context/plan/execute/verify/review are normal lifecycle
  # lifecycle markers and must not be treated as phase-skip evidence.
  finalization_skills="silver-branch-finish silver-create-release silver-completion-audit tdd"
  if [[ -n "$config_file" ]]; then
    cfg_finalization=$(jq -r '(.skills.required_deploy // []) | map(select(
      . != "silver-quality-gates"
      and . != "silver-blast-radius"
      and . != "devops-quality-gates"
      and . != "silver-context"
      and . != "silver-plan"
      and . != "silver-execute"
      and . != "silver-verify"
      and . != "silver-review"
      and . != "silver-review-request"
      and . != "silver-review-triage"
      and . != "requesting-code-review"
      and . != "receiving-code-review"
    )) | join(" ")' "$config_file" 2>/dev/null || true)
    [[ -n "$cfg_finalization" ]] && finalization_skills="$cfg_finalization"
  fi
  has_finalization=false
  for fs in $finalization_skills; do
    if has_skill "$fs"; then
      has_finalization=true
      break
    fi
  done

  if ! has_skill "silver-review"; then
    # Stage B: planning done, implementation window open. Code review is a
    # post-implementation/final-delivery gate and must not block execution.
    if [[ "$has_finalization" == true ]]; then
      sb_hook_audit_record "dev-cycle-check" "$hook_event" "allow" "Planning verified, but finalization markers exist before silver-review." "${file_path:-${command_str:-}}"
      printf '{"hookSpecificOutput":{"message":"⚠️ Planning verified, but finalization markers exist before silver-review. Source edits are allowed so fixes can proceed; final delivery remains blocked until review/verification gates pass in order."}}'
    else
      sb_hook_audit_record "dev-cycle-check" "$hook_event" "allow" "Planning verified. Implementation edits allowed." "${file_path:-${command_str:-}}"
      printf '{"hookSpecificOutput":{"message":"✅ Planning verified. Implementation edits allowed. Code review, verification, and finalization remain required before delivery."}}'
    fi
    exit 0
  fi

  if ! has_skill "silver-branch-finish"; then
    # Stage C: has silver-review, finalization remaining
    sb_hook_audit_record "dev-cycle-check" "$hook_event" "allow" "SB code review recorded. Source edits remain allowed." "${file_path:-${command_str:-}}"
    printf '{"hookSpecificOutput":{"message":"✅ SB code review recorded. Source edits remain allowed; finalization, verification, and delivery gates still apply."}}'
    exit 0
  fi

  # Stage D: all phases complete
  sb_hook_audit_record "dev-cycle-check" "$hook_event" "allow" "All workflow phases complete. Proceed freely." "${file_path:-${command_str:-}}"
  printf '{"hookSpecificOutput":{"message":"✅ All workflow phases complete. Proceed freely."}}'
  exit 0
}

# Run main, catch any errors
if ! main; then
  printf '{"hookSpecificOutput":{"message":"⚠️ dev-cycle-check.sh encountered an error — continuing without blocking."}}'
  exit 0
fi
