#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook (matcher: Edit|Write|Bash)
# Enforces four-stage workflow gate — blocks source edits if planning skills incomplete.

# Security: restrict file creation permissions (user-only)
umask 0077

# jq is required for JSON parsing
if ! command -v jq >/dev/null 2>&1; then
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
    if [[ "$hook_event" == "PreToolUse" ]]; then
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
    else
      printf '{"decision":"block","reason":%s,"hookSpecificOutput":{"message":%s}}' "$json_reason" "$json_reason"
    fi
  }

  # --- Determine file path or command based on tool type ---
  file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_response.filePath // ""')
  command_str=""

  if [[ -z "$file_path" ]]; then
    # Bash tool — extract command
    command_str=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
    [[ -z "$command_str" ]] && exit 0
  fi

  # --- Third-party plugin boundary (§8) — HARD STOP on upstream plugin edits ---
  plugin_cache="${HOME}/.claude/plugins/cache"
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
  fi

  # --- Resolve config file by walking up from file's directory (or $PWD for Bash) ---
  config_file=""
  if [[ -n "$file_path" ]]; then
    search_dir=$(dirname "$file_path")
  else
    search_dir="$PWD"
  fi
  while true; do
    if [[ -f "$search_dir/.silver-bullet.json" ]]; then
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
  required_planning="quality-gates"
  active_workflow="full-dev-cycle"
  SB_STATE_DIR="${HOME}/.claude/.silver-bullet"
  state_file="${SB_STATE_DIR}/state"
  trivial_file="${SB_STATE_DIR}/trivial"

  if [[ -n "$config_file" ]]; then
    src_pattern=$(jq -r '.project.src_pattern // "/src/"' "$config_file")
    src_exclude_pattern=$(jq -r '.project.src_exclude_pattern // "__tests__|\\.test\\."' "$config_file")
    # Validate exclude pattern: reject patterns > 200 chars (ReDoS mitigation)
    if [[ ${#src_exclude_pattern} -gt 200 ]]; then
      src_exclude_pattern='__tests__|\.test\.'
    fi
    active_workflow=$(jq -r '.project.active_workflow // "full-dev-cycle"' "$config_file")
    custom_planning=$(jq -r '(.skills.required_planning // []) | join(" ")' "$config_file")
    [[ -n "$custom_planning" ]] && required_planning="$custom_planning"
    cfg_state=$(jq -r '.state.state_file // ""' "$config_file")
    [[ -n "$cfg_state" ]] && state_file="${cfg_state/#\~/$HOME}"
    cfg_trivial=$(jq -r '.state.trivial_file // ""' "$config_file")
    [[ -n "$cfg_trivial" ]] && trivial_file="${cfg_trivial/#\~/$HOME}"
  fi

  # Env var overrides
  state_file="${SILVER_BULLET_STATE_FILE:-$state_file}"

  # Security: validate state file path stays within ~/.claude/ (SB-002/SB-003)
  case "$state_file" in
    "$HOME"/.claude/*) ;;
    *) state_file="${SB_STATE_DIR}/state" ;;
  esac

  # Security: validate trivial file path stays within ~/.claude/ (SB-002/SB-003)
  case "$trivial_file" in
    "$HOME"/.claude/*) ;;
    *) trivial_file="${SB_STATE_DIR}/trivial" ;;
  esac

  # --- Check if file/command matches src_pattern ---
  if [[ -n "$file_path" ]]; then
    # Edit/Write tool — check file path
    if ! printf '%s' "$file_path" | grep -q "$src_pattern"; then
      exit 0
    fi
    # Check exclude pattern (test files)
    if printf '%s' "$file_path" | grep -qE "$src_exclude_pattern"; then
      exit 0
    fi
  else
    # Bash tool — check if command string contains src_pattern
    if ! printf '%s' "$command_str" | grep -q "$src_pattern"; then
      exit 0
    fi
    # Check exclude pattern for Bash commands too
    if printf '%s' "$command_str" | grep -qE "$src_exclude_pattern"; then
      exit 0
    fi
  fi

  # --- Check trivial file override ---
  if [[ -f "$trivial_file" && ! -L "$trivial_file" ]]; then
    exit 0
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

    # Small Edit tool changes (combined old+new < 300 chars) are trivial
    tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""')
    if [[ "$tool_name" == "Edit" ]]; then
      old_str_len=$(printf '%s' "$input" | jq -r '.tool_input.old_string // "" | length')
      new_str_len=$(printf '%s' "$input" | jq -r '.tool_input.new_string // "" | length')
      combined_len=$((old_str_len + new_str_len))
      if [[ $combined_len -gt 0 && $combined_len -lt 300 ]]; then
        printf '{"hookSpecificOutput":{"message":"ℹ️ Small edit (%d chars) — enforcement skipped for this edit."}}'  "$combined_len"
        exit 0
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
    printf '%s\n' "$completed_skills" | grep -qx "$1" 2>/dev/null
  }

  # --- Check required planning skills ---
  missing_skills=""
  for skill in $required_planning; do
    if ! has_skill "$skill"; then
      if [[ -n "$missing_skills" ]]; then
        missing_skills="$missing_skills $skill"
      else
        missing_skills="$skill"
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
    emit_block "$stage_a_msg"
    exit 0
  fi

  # --- Phase skip detection (after HARD STOP so Stage A always fires first) ---
  finalization_skills="testing-strategy tech-debt documentation finishing-a-development-branch deploy-checklist"
  has_finalization=false
  for fs in $finalization_skills; do
    if has_skill "$fs"; then
      has_finalization=true
      break
    fi
  done

  if [[ "$has_finalization" == true ]] && ! has_skill "code-review"; then
    printf '{"hookSpecificOutput":{"message":"⚠️ Phase skip detected: finalization skills invoked before code-review. Consider running code-review first."}}'
    exit 0
  fi

  if ! has_skill "code-review"; then
    # Stage B: all planning done, no code-review — BLOCK source edits
    block_msg="🚫 BLOCKED — Code review required before further source edits. Planning is complete but you must run /code-review before editing source code. Non-source operations (reading, commits, skill invocations) are still allowed."
    emit_block "$block_msg"
    exit 0
  fi

  if ! has_skill "finishing-a-development-branch"; then
    # Stage C: has code-review, finalization remaining
    printf '{"hookSpecificOutput":{"message":"✅ Code review done. Finalization remaining — run /testing-strategy, /tech-debt, /documentation, /finishing-a-development-branch, /deploy-checklist when ready."}}'
    exit 0
  fi

  # Stage D: all phases complete
  printf '{"hookSpecificOutput":{"message":"✅ All workflow phases complete. Proceed freely."}}'
  exit 0
}

# Run main, catch any errors
if ! main; then
  printf '{"hookSpecificOutput":{"message":"⚠️ dev-cycle-check.sh encountered an error — continuing without blocking."}}'
  exit 0
fi
