#!/usr/bin/env bash
# dev-cycle-check module — auto-split
# --- Check if file/command matches src_pattern ---
if [[ ${#patch_file_paths[@]} -gt 0 ]]; then
  patch_in_scope=false
  for patch_path in "${patch_file_paths[@]}"; do
    if dcc_matches_src_scope "$patch_path" "$src_pattern" && ! printf '%s' "$patch_path" | grep -qE "$src_exclude_pattern"; then
      file_path="$patch_path"
      patch_in_scope=true
      break
    fi
  done
  [[ "$patch_in_scope" == true ]] || exit 0
elif [[ -n "$file_path" ]]; then
  # File edit/write event — check file path
  if ! dcc_matches_src_scope "$file_path" "$src_pattern"; then
    exit 0
  fi
  # Check exclude pattern (test files)
  if printf '%s' "$file_path" | grep -qE "$src_exclude_pattern"; then
    exit 0
  fi
else
  dcc_shell_payload_is_sb_skill_adapter_invocation "$command_str" && exit 0
  dcc_collect_shell_in_scope_targets
  if [[ ${#shell_write_targets[@]} -gt 0 ]]; then
    # When we can resolve concrete write targets, scope Bash enforcement to the
    # actual destination paths instead of matching arbitrary file content.
    [[ ${#shell_in_scope_targets[@]} -gt 0 ]] || exit 0
  else
    if [[ -n "$shell_script_body" ]]; then
      dcc_shell_payload_looks_read_only "$shell_script_body" && exit 0
    else
      dcc_shell_payload_looks_read_only "$command_str" && exit 0
    fi
    # Fallback for opaque shell commands where no concrete write target can be
    # resolved from the command text or sourced script bodies.
    dcc_shell_command_shows_write_intent "$command_str" || exit 0
    if ! dcc_matches_src_scope "$command_str" "$src_pattern"; then
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
