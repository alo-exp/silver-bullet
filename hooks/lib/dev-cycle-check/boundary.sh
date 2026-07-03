#!/usr/bin/env bash
# dev-cycle-check module — auto-split
# --- Third-party plugin boundary (§8) — HARD STOP on upstream plugin edits ---
plugin_cache="${SB_RUNTIME_PLUGIN_CACHE_ROOT}"
dcc_plugin_boundary_is_uninstall_cleanup() {
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
  if dcc_shell_writes_under_prefix "$plugin_cache"; then
    if ! dcc_plugin_boundary_is_uninstall_cleanup; then
      emit_block "🚫 THIRD-PARTY PLUGIN BOUNDARY VIOLATION via Bash command — Silver Bullet NEVER modifies upstream plugin files. See CLAUDE.md §8."
      exit 0
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
    if dcc_shell_writes_under_prefix "$sb_hooks_dir" || dcc_shell_writes_to_exact_path "${sb_plugin_root}/hooks.json" || \
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
  { dcc_shell_writes_under_prefix "${SB_RUNTIME_HOME_ROOT}" && \
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

dcc_sb_state_sentinel_path_allowed() {
  local candidate="$1"
  [[ -n "$candidate" ]] || return 1
  case "$(basename "$candidate")" in
    planning-edit-override|roadmap-edit-override|trivial|planning-edit-override-audit.log|roadmap-edit-override-audit.log)
      [[ "$candidate" == "${SB_STATE_DIR_EARLY}/"* ]] && return 0
      ;;
  esac
  return 1
}

dcc_sb_bash_touches_state_sentinel_only() {
  local cmd="$1"
  local target
  if ! printf '%s' "$cmd" | grep -qE '(^|[[:space:]])touch([[:space:]]|$)'; then
    return 1
  fi
  target=$(printf '%s' "$cmd" | sed -nE 's/.*\btouch\b[[:space:]]+([^;&|]+).*/\1/p' | head -1 | tr -d "'\"")
  dcc_sb_state_sentinel_path_allowed "$target"
}

if [[ -n "$file_path" ]]; then
  # Edit/Write targeting the state directory → hard block (except explicit sentinels)
  if [[ "$file_path" == "${SB_STATE_DIR_EARLY}/"* ]]; then
    if dcc_sb_state_sentinel_path_allowed "$file_path"; then
      exit 0
    fi
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
  if ! dcc_sb_bash_touches_state_sentinel_only "$command_str" && \
     ! printf '%s' "$cmd_first_line_tamper" | grep -qE '^\s*(git\s|gh\s)' && \
     { { printf '%s' "$cmd_first_line_tamper" | grep -qE '(>>|\s>[^>&=]|\btee\b)' && \
         printf '%s' "$cmd_first_line_tamper" | grep -qF "$state_path"; } || \
       dcc_shell_writes_to_exact_path "$state_path"; }; then
    emit_block "🚫 STATE TAMPER BLOCKED — Writing to Silver Bullet state files bypasses workflow enforcement.

Skills are recorded automatically when invoked through the active runtime's SB-recognized skill invocation channel. Do not write to state files directly.

To reset workflow state intentionally, run in your terminal:
    rm ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state"
    exit 0
  fi
fi
