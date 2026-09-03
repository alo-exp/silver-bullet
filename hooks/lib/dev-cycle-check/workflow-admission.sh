#!/usr/bin/env bash
# dev-cycle-check module — auto-split
# --- Composed-workflow admission control (Pass 2) ---
# When a composed workflow is active in `.planning/workflows/<id>.md`, the
# current session must present a matching SB_WORKFLOW_ID before any
# non-trivial source edit can reach the legacy planning gate. This is the
# admission check that prevents direct edits from bypassing /silver-routed
# workflows. Legacy skill markers remain the fallback when no composed
# workflow is active at all.
if [[ "$hook_event" == "PreToolUse" ]]; then
  repo_root=$(dcc_resolve_repo_root 2>/dev/null || true)
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
          active_id="$(dcc_workflow_id_from_shell_assignment "$command_str" 2>/dev/null || true)"
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
