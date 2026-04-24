#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# Load shared workflow utilities (TD-1: single source of truth for Flow Log regex)
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -n "$_lib_dir" && -f "$_lib_dir/workflow-utils.sh" ]]; then
  source "$_lib_dir/workflow-utils.sh"
fi
if ! declare -f count_flow_log_rows >/dev/null 2>&1; then
  count_flow_log_rows() { grep -cE '^\| [0-9]+ \|' "$1" 2>/dev/null || echo 0; }
  count_complete_flow_rows() { grep -cE '^\| [^|]+\| [^|]+\| complete' "$1" 2>/dev/null || echo 0; }
fi

# Pre+PostToolUse hook (matcher: Edit|Write|Bash)
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
  elif [[ -n "$command_str" ]]; then
    # F-07: Block Bash commands that write to the plugin cache (bypass via shell instead of Edit/Write)
    if printf '%s' "$command_str" | grep -qE "$plugin_cache" && \
       printf '%s' "$command_str" | grep -qE '(>>|\s>[^>&=]|\btee\b|\bcp\b|\bmv\b|\brm\b|\bchmod\b|\bsed\b|\bperl\b|\binstall\b)'; then
      emit_block "🚫 THIRD-PARTY PLUGIN BOUNDARY VIOLATION via Bash command — Silver Bullet NEVER modifies upstream plugin files. See CLAUDE.md §8."
      exit 0
    fi
  fi

  # --- Silver Bullet hook self-protection ─────────────────────────────────────
  # Block edits to SB's own enforcement hooks. If Claude modifies its own hooks,
  # it disables the very enforcement mechanisms that ensure process compliance.
  if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    sb_hooks_dir="${CLAUDE_PLUGIN_ROOT}/hooks"
    if [[ -n "$file_path" ]]; then
      # Edit/Write targeting hooks directory or hooks.json
      if [[ "$file_path" == "${sb_hooks_dir}/"* ]] || [[ "$file_path" == "${CLAUDE_PLUGIN_ROOT}/hooks.json" ]]; then
        emit_block "Silver Bullet NEVER modifies its own enforcement hooks. This would disable process compliance. If you need to reconfigure, use /silver:init."
        exit 0
      fi
    elif [[ -n "$command_str" ]]; then
      # Bash write commands targeting hooks directory or hooks.json
      if printf '%s' "$command_str" | grep -qE "(${sb_hooks_dir}/|${CLAUDE_PLUGIN_ROOT}/hooks\.json)" && \
         printf '%s' "$command_str" | grep -qE '(>>|\s>[^>&=]|\btee\b|\bcp\b|\bmv\b|\brm\b|\bchmod\b|\bsed\b|\bperl\b|\binstall\b)'; then
        emit_block "Silver Bullet NEVER modifies its own enforcement hooks. This would disable process compliance. If you need to reconfigure, use /silver:init."
        exit 0
      fi
    fi
  fi

  # Fallback: detect hooks path by pattern if CLAUDE_PLUGIN_ROOT unavailable.
  # IMPORTANT: Only block paths that are provably inside ${HOME}/.claude/ (the installed
  # plugin location). Do NOT use a repo-name pattern — that would also match the silver-
  # bullet source repo's own hooks/ directory and prevent legitimate source edits.
  if [[ -z "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    # Check both file_path (Edit/Write) and command_str (Bash) for hooks path pattern
    if [[ -n "$file_path" ]] && [[ "$file_path" == "${HOME}/.claude/"* ]] &&        printf '%s' "$file_path" | grep -qE '/hooks/'; then
      emit_block "Silver Bullet NEVER modifies its own enforcement hooks. This would disable process compliance. If you need to reconfigure, use /silver:init."
      exit 0
    fi
    if [[ -n "$command_str" ]] && printf '%s' "$command_str" | grep -qE "${HOME}/.claude/[^ ]*/hooks/" && \
       printf '%s' "$command_str" | grep -qE '(>>|\s>[^>&=]|\btee\b|\bcp\b|\bmv\b|\brm\b|\bchmod\b|\bsed\b|\bperl\b|\binstall\b)'; then
      emit_block "Silver Bullet NEVER modifies its own enforcement hooks. This would disable process compliance. If you need to reconfigure, use /silver:init."
      exit 0
    fi
  fi

  # --- State file tamper prevention (SB-008) ──────────────────────────────────
  # Block direct Edit/Write to Silver Bullet state files and Bash write patterns.
  # This prevents bypassing enforcement by manipulating the state file directly.
  # Security note: if state/config files are unreadable, we emit a WARNING (not a
  # block) — blocking on unreadable state would lock users out. The outer
  # trap 'exit 0' ERR provides graceful degradation for all unexpected failures.
  SB_STATE_DIR_EARLY="${HOME}/.claude/.silver-bullet"

  if [[ -n "$file_path" ]]; then
    # Edit/Write targeting the state directory → hard block
    if [[ "$file_path" == "${SB_STATE_DIR_EARLY}/"* ]]; then
      emit_block "🚫 STATE TAMPER BLOCKED — Direct edits to Silver Bullet state files are not permitted.

Skills are recorded automatically when invoked via the Skill tool. Modifying state files directly bypasses workflow enforcement.

To reset the workflow state, remove the file from your terminal (not from Claude):
  rm ~/.claude/.silver-bullet/state"
      exit 0
    fi
  elif [[ -n "$command_str" ]]; then
    # Bash write to .silver-bullet/state -> block (branch and trivial are NOT state-managed)
    # QA-05: match only the first line (prevents heredoc body false-positives) and skip
    # git/gh commands entirely — those never write to state files but may mention the state
    # path in -m / --body string arguments, causing false-positive blocks (issue #36).
    # Also skip when the path appears only inside a quoted string literal (not a real redirect).
    cmd_first_line_tamper=$(printf '%s' "$command_str" | head -1)
    _state_in_dquote='"[^"]*\.claude/[^/]+/state[^"]*"'
    _state_in_squote="'[^']*\\.claude/[^/]+/state[^']*'"
    if ! printf '%s' "$cmd_first_line_tamper" | grep -qE '^\s*(git\s|gh\s)' && \
       ! printf '%s' "$cmd_first_line_tamper" | grep -qE "$_state_in_dquote" && \
       ! printf '%s' "$cmd_first_line_tamper" | grep -qE "$_state_in_squote" && \
       printf '%s' "$cmd_first_line_tamper" | grep -qE '(>>|\s>[^>&=]|\btee\b)[^<]*\.claude/[^/]+/state\b'; then
      emit_block "🚫 STATE TAMPER BLOCKED — Writing to Silver Bullet state files bypasses workflow enforcement.

Skills are recorded automatically when invoked via the Skill tool. Do not write to state files directly.

To reset workflow state intentionally, run in your terminal:
  rm ~/.claude/.silver-bullet/state"
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
  required_planning=""   # resolved below after reading active_workflow
  active_workflow="full-dev-cycle"
  SB_STATE_DIR="${HOME}/.claude/.silver-bullet"
  state_file="${SB_STATE_DIR}/state"
  trivial_file="${SB_STATE_DIR}/trivial"

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
    custom_planning=$(jq -r '(.skills.required_planning // []) | join(" ")' "$config_file")
    [[ -n "$custom_planning" ]] && required_planning="$custom_planning"
    cfg_state=$(jq -r '.state.state_file // ""' "$config_file")
    [[ -n "$cfg_state" ]] && state_file="${cfg_state/#\~/$HOME}"
    cfg_trivial=$(jq -r '.state.trivial_file // ""' "$config_file")
    [[ -n "$cfg_trivial" ]] && trivial_file="${cfg_trivial/#\~/$HOME}"
  fi

  # Set default required_planning based on workflow if not overridden by config
  # DevOps workflow: silver-blast-radius and devops-quality-gates replace silver-quality-gates
  if [[ -z "$required_planning" ]]; then
    if [[ "$active_workflow" == "devops-cycle" ]]; then
      required_planning="silver-blast-radius devops-quality-gates"
    else
      required_planning="silver-quality-gates"
    fi
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

  # --- Mid-session branch mismatch warning (F-09) ---
  branch_file="${SB_STATE_DIR}/branch"
  if [[ -f "$branch_file" && ! -L "$branch_file" ]]; then
    stored_branch=$(cat "$branch_file" 2>/dev/null || true)
    current_branch=$(git -C "$PWD" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    if [[ -n "$stored_branch" && -n "$current_branch" && "$stored_branch" != "$current_branch" ]]; then
      jq -n --arg s "$stored_branch" --arg c "$current_branch" \
        '{"hookSpecificOutput":{"message":"Warning: Branch mismatch -- state recorded for [\($s)] but current branch is [\($c)]. Run /compact to reset."}}'
      # Warning only -- do not exit, let the rest of the hook proceed
    fi
  fi

  # --- Destructive command warning (F-04) ---
  if [[ -n "$command_str" ]] && [[ ! -f "$trivial_file" || -L "$trivial_file" ]]; then
    if printf '%s' "$command_str" | grep -qE '\b(rm|mv)\b' && \
       ! printf '%s' "$command_str" | grep -qE "(${plugin_cache}|\.silver-bullet/|/tmp/|\.claude/)"; then
      printf '{"hookSpecificOutput":{"message":"Warning: Destructive command detected (rm/mv on project files). Verify this is intentional before proceeding."}}'
      # Warning only -- do not block
    fi
  fi

  # --- Check if file/command matches src_pattern ---
  if [[ -n "$file_path" ]]; then
    # Edit/Write tool — check file path
    if ! printf '%s' "$file_path" | grep -qE "$src_pattern"; then
      exit 0
    fi
    # Check exclude pattern (test files)
    if printf '%s' "$file_path" | grep -qE "$src_exclude_pattern"; then
      exit 0
    fi
  else
    # Bash tool — check if command string contains src_pattern
    if ! printf '%s' "$command_str" | grep -qE "$src_pattern"; then
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

    # Small Edit tool changes (combined old+new < 100 chars) are trivial (typo fixes)
    # Threshold reduced from 300 to 100 to prevent bypassing enforcement via incremental changes
    tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""')
    if [[ "$tool_name" == "Edit" ]]; then
      old_str_len=$(printf '%s' "$input" | jq -r '.tool_input.old_string // "" | length')
      new_str_len=$(printf '%s' "$input" | jq -r '.tool_input.new_string // "" | length')
      combined_len=$((old_str_len + new_str_len))
      if [[ $combined_len -gt 0 && $combined_len -lt 100 ]]; then
        printf '{"hookSpecificOutput":{"message":"ℹ️ Small edit (%d chars) — enforcement skipped for this edit."}}'  "$combined_len"
        exit 0
      fi
    fi
  fi

  # --- WORKFLOW.md path completion check (primary gate with legacy fallback) ---
  workflow_file="$PWD/.planning/WORKFLOW.md"
  if [[ -f "$workflow_file" && ! -L "$workflow_file" ]]; then
    # Parse Flow Log table: count completed and total paths
    path_complete_count=0
    path_total_count=0
    if path_complete_count=$(grep -cE '^\| [^|]+\| [^|]+\| complete' "$workflow_file" 2>/dev/null) && \
       path_total_count=$(count_flow_log_rows "$workflow_file"); then
      if [[ "$path_total_count" -gt 0 && "$path_complete_count" -eq "$path_total_count" ]]; then
        # All flows done — allow freely
        printf '{"hookSpecificOutput":{"message":"✅ All flows complete. Proceed freely."}}'
        exit 0
      elif [[ "$path_total_count" -gt 0 ]]; then
        # Partial progress — inform but fall through to legacy gate
        printf '{"hookSpecificOutput":{"message":"ℹ️ FLOW %s/%s — composable flows enforcement active. Legacy gate still applies." }}' \
          "$path_complete_count" "$path_total_count"
      fi
    fi
    # If parsing failed (malformed file), fall through to legacy logic silently
  fi
  # If WORKFLOW.md absent: fall through to legacy logic unchanged (per D-03)

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
  # Derive finalization_skills from config required_deploy; fall back to hardcoded defaults.
  finalization_skills="testing-strategy tech-debt documentation finishing-a-development-branch deploy-checklist"
  if [[ -n "$config_file" ]]; then
    cfg_finalization=$(jq -r '(.skills.required_deploy // []) | map(select(. != "code-review" and . != "requesting-code-review" and . != "receiving-code-review" and . != "silver-quality-gates")) | join(" ")' "$config_file" 2>/dev/null || true)
    [[ -n "$cfg_finalization" ]] && finalization_skills="$cfg_finalization"
  fi
  has_finalization=false
  for fs in $finalization_skills; do
    if has_skill "$fs"; then
      has_finalization=true
      break
    fi
  done

  if [[ "$has_finalization" == true ]] && ! has_skill "code-review"; then
    phase_skip_msg=$(printf '🚫 BLOCKED — Phase skip detected: finalization skills invoked before /code-review.\n\nYou must run /code-review BEFORE finalization steps (testing-strategy, documentation, etc.). This order is mandatory.\n\nRun /code-review now before continuing to edit source code.')
    emit_block "$phase_skip_msg"
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
