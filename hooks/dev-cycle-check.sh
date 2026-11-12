#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
# shellcheck source=lib/hook-bootstrap.sh
[[ -n "$_lib_dir" ]] && source "${_lib_dir}/hook-bootstrap.sh"
[[ -f "$_lib_dir/cert-bypass.sh" ]] && source "$_lib_dir/cert-bypass.sh"
if [[ -f "$_lib_dir/plugin-cache-guard.sh" ]]; then
  # shellcheck source=lib/plugin-cache-guard.sh
  source "$_lib_dir/plugin-cache-guard.sh"
fi
if [[ ! -f "$_lib_dir/planning-floor.sh" ]]; then
  # A broken install must not turn the planning floor off silently.
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Silver Bullet hook libraries are missing (hooks/lib/planning-floor.sh). Reinstall the plugin."}}'
  exit 0
fi
# shellcheck source=lib/planning-floor.sh
source "$_lib_dir/planning-floor.sh"
# shellcheck source=lib/branch-scope.sh
source "$_lib_dir/branch-scope.sh"
DEFAULT_PLANNING="${DEFAULT_PLANNING:-silver-quality-gates silver-context silver-plan}"
DEVOPS_DEFAULT_PLANNING="${DEVOPS_DEFAULT_PLANNING:-silver-blast-radius devops-quality-gates silver-context silver-plan}"

# Pre+PostToolUse hook (matcher: Edit|Write|MultiEdit|NotebookEdit|apply_patch|Bash|exec_command|MCP file writes)
# Enforces the four-stage workflow gate — blocks source edits if planning skills are incomplete —
# and guards the files the gates themselves rest on.
#
# One analysis of the call (hooks/lib/shell-analysis.sh, payload on stdin) yields every write
# target. Targets are compared in canonical form (symlinks, '..', Windows spellings, case). The
# hook prints at most ONE JSON document: advisories are folded into it, so a deny is never preceded
# by another object the host would fail to parse.
#
#   PreToolUse   protections (any project), then the planning floor (SB projects only)
#   PostToolUse  only invalidates the fresh-test-run record after a source write

emit_block_jq_missing() {
  local reason="$1"
  # This runs only when jq is missing, so encode the reason without it (the shared emitter falls back).
  sb_emit_hook_decision PreToolUse deny "$reason"
}

# jq is required for JSON parsing (block SB-initiated projects; warn others)
if ! command -v jq >/dev/null 2>&1; then
  if declare -f sb_jq_enforcement_block_sb_initiated >/dev/null 2>&1; then
    sb_jq_enforcement_block_sb_initiated "dev-cycle-check" "emit_block_jq_missing"
  fi
  printf '{"systemMessage":"⚠️ Silver Bullet hooks require jq. Install: brew install jq (macOS) / apt install jq (Linux)"}'
  exit 0
fi

SB_DC_NOTICES=""
SB_DC_EMITTED=0
hook_event="PostToolUse"

# The single exit-time emitter: advisories collected so far, unless a deny already carried them.
dc_flush() {
  if [[ "$SB_DC_EMITTED" -eq 0 && -n "$SB_DC_NOTICES" ]]; then
    sb_emit_hook_message "$hook_event" "$SB_DC_NOTICES"
  fi
  SB_DC_EMITTED=1
}

# Wrap everything in a function so any failure is caught
main() {
  trap dc_flush EXIT
  nl=$'\n'
  if declare -f sb_cert_run_bypass_active >/dev/null 2>&1 && sb_cert_run_bypass_active; then
    exit 0
  fi

  # Read JSON from stdin
  input=$(cat)

  # Detect hook event type (PreToolUse vs PostToolUse)
  payload_invalid=false
  hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse"' 2>/dev/null) || payload_invalid=true
  [[ -n "$hook_event" ]] || hook_event="PostToolUse"

  # PostToolUse has three jobs, each with a cheap precondition: drop the fresh-test-run record,
  # remove an unblessed trivial marker, and keep the integrity record in step with what the
  # sanctioned writers (the file tools, a running contract-writing skill) changed. Nothing to do
  # for any of them: no analysis at all.
  if [[ "$hook_event" != "PreToolUse" && "$payload_invalid" != true ]]; then
    marker_early="${SILVER_BULLET_VERIFY_TESTS_STATE_FILE:-${SB_RUNTIME_STATE_DIR}/verify-tests-state}"
    sb_runtime_path_is_state_scoped "$marker_early" || marker_early="${SB_RUNTIME_STATE_DIR}/verify-tests-state"
    post_work=false
    [[ -e "$marker_early" || -e "${SB_RUNTIME_STATE_DIR}/unlock-hint" || -e "${SB_RUNTIME_STATE_DIR}/trivial" || -L "${SB_RUNTIME_STATE_DIR}/trivial" ]] && post_work=true
    case "$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null)" in
      Edit | Write | MultiEdit | NotebookEdit | apply_patch | mcp__*) post_work=true ;;
    esac
    [[ "$post_work" == true ]] || exit 0
  fi

  # Advisory-only output: collected, emitted once with the verdict (or alone at exit)
  emit_advisory() {
    SB_DC_NOTICES="${SB_DC_NOTICES:+$SB_DC_NOTICES$nl}$1"
  }

  # Emit a deny (PreToolUse only: PostToolUse never blocks), carrying the advisories
  emit_block() {
    local reason="$1"
    sb_hook_audit_record "dev-cycle-check" "$hook_event" "deny" "$reason" "${audit_target:-}"
    SB_DC_EMITTED=1
    sb_emit_hook_decision "$hook_event" deny "$reason" "" "$SB_DC_NOTICES"
  }

  # --- Analyse the call once --------------------------------------------------
  sb_pf_tool_input_load "$input"
  tool_name="${SB_TI_TOOL_NAME:-}"
  [[ -n "$tool_name" ]] || tool_name="$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null)"
  tool_kind="${SB_TI_TOOL_KIND:-}"
  [[ "${SB_TI_STATUS:-}" == "empty" ]] && exit 0
  if [[ "${SB_TI_STATUS:-}" == "parse_failed" && -z "${SB_TI_TOOL_NAME:-}" ]]; then
    # The payload itself is not valid JSON: the host's call cannot be judged. Inside an SB project
    # that is a deny with a message, not a silent allow.
    [[ -n "$(sb_find_project_config_walk_only 2>/dev/null)" ]] || exit 0
    hook_event="PreToolUse"
    emit_block "$(sb_pf_unanalysable_message)"
    exit 0
  fi

  parse_failed_shell=false
  is_shell=false
  if sb_tool_is_shell_like "$tool_name"; then is_shell=true; fi
  case "$tool_name" in
    Edit | Write | MultiEdit | NotebookEdit | apply_patch) ;;
    *)
      if [[ "$is_shell" != true ]]; then
        # An MCP tool counts only when its name says it writes (a read tool carries paths too).
        [[ "$tool_kind" == mcp || "$tool_name" == mcp__* ]] || exit 0
        sb_pf_mcp_write_tool "$tool_name" || exit 0
      fi
      ;;
  esac

  if ! sb_tool_input_ok; then
    if [[ "$is_shell" == true && "${SB_TI_STATUS:-}" == "parse_failed" && -n "${SB_TI_TOOL_NAME:-}" ]]; then
      # Shell syntax the analyser rejects: the complete commands before the error are analysed, and
      # every path-like word of the command is treated as a possible write (below).
      parse_failed_shell=true
    elif [[ "$is_shell" == true ]]; then
      # python3 is missing, or the payload is not valid: the planning floor cannot tell what the
      # command writes. Inside an SB project that is a deny — except for a plainly read-only command.
      [[ -n "$(sb_find_project_config_walk_only 2>/dev/null || true)" ]] || exit 0
      cmd_fallback="$(printf '%s' "$input" | jq -r '.tool_input | objects | (.command // .cmd // "") | strings' 2>/dev/null)"
      sb_pf_plain_read_only "$cmd_fallback" && exit 0
      [[ "$hook_event" == "PreToolUse" ]] || exit 0
      emit_block "$(sb_pf_unanalysable_message)"
      exit 0
    elif [[ "$tool_name" == "apply_patch" ]]; then
      # A patch needs the helper; the file tools' path fields are plain JSON.
      [[ "$hook_event" == "PreToolUse" ]] || exit 0
      [[ -n "$(sb_find_project_config_walk_only 2>/dev/null || true)" ]] || exit 0
      emit_block "$(sb_pf_unanalysable_message)"
      exit 0
    else
      SB_TI_TOOL_KIND="edit"
    fi
  fi

  # A command the analyser reports as code it cannot read (an exceeded budget, eval of computed
  # text, a shell fed by a pipe...) may write anything: refuse it inside an SB project unless it is
  # plainly read-only (R1-06, review blocker 1).
  if [[ "$is_shell" == true && "$hook_event" == "PreToolUse" ]]; then
    unseen_why="$(sb_pf_unseen_reason)"
    if [[ -n "$unseen_why" ]] && [[ -n "$(sb_find_project_config_walk_only 2>/dev/null)" ]]; then
      emit_block "$(sb_pf_unseen_message "$unseen_why")"
      exit 0
    fi
  fi

  # Everything this call writes: "via<TAB>canonical path"
  records="$(sb_pf_write_records "$input")"
  opaque_records=""
  script_records=""
  if [[ "$is_shell" == true ]]; then
    opaque_records="$(sb_pf_opaque_records)"
    if [[ "$parse_failed_shell" == true ]]; then opaque_records="$(sb_pf_opaque_records all)"; fi
    skill_adapter="${SB_SA_SKILL_ADAPTER:-false}"
    shell_command="${SB_TI_COMMAND:-}"
    invoked_script="${SB_SA_INVOKED_SCRIPT:-}"
    # The body of a script the command runs is analysed too: its writes are this command's writes.
    if [[ -n "$invoked_script" && -f "$invoked_script" ]]; then
      script_body="$(cat "$invoked_script" 2>/dev/null)"
      script_dir="$(dirname "$invoked_script")"
      sb_shell_analysis_load "$script_body" "$script_dir"
      script_records="$(SB_TI_TOOL_KIND=shell sb_pf_write_records "")"
      if [[ "$script_dir" != "$PWD" ]]; then
        sb_shell_analysis_load "$script_body" "$PWD"
        script_records="$script_records"$'\n'"$(SB_TI_TOOL_KIND=shell sb_pf_write_records "")"
      fi
      records="$records"$'\n'"$script_records"
    fi
  else
    skill_adapter=false
    shell_command=""
  fi
  records="$(printf '%s\n' "$records" | awk 'NF && !seen[$0]++')"
  # --- Third-party plugin boundary (§8) — HARD STOP on upstream plugin edits ---------------
  plugin_cache="${SB_RUNTIME_PLUGIN_CACHE_ROOT}"
  audit_target=""
  if [[ "$hook_event" == "PreToolUse" ]]; then
    state_dir_canon="$(sb_pf_canon "${SB_RUNTIME_STATE_DIR}")"
    registry_canon="$(sb_pf_canon "$(sb_plugin_cache_registry_file)")"
    _sb_hooks_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    sb_plugin_root="${SB_PLUGIN_ROOT:-$(cd "${_sb_hooks_script}/.." && pwd)}"
    sb_plugin_root="$(sb_pf_canon "$sb_plugin_root")"
    runtime_root="$(sb_pf_canon "${SB_RUNTIME_HOME_ROOT}")"
    # A source checkout can live inside a host runtime worktree, so runtime-root ancestry alone is
    # not proof that this is an installed plugin copy. A direct .git marker identifies the source
    # checkout while preserving protection for packaged installations.
    sb_source_checkout=false
    [[ -e "${sb_plugin_root}/.git" ]] && sb_source_checkout=true
    installed_copy=false
    if [[ "$_sb_hooks_script" == "${SB_RUNTIME_HOME_ROOT}"* ]] && [[ "$sb_source_checkout" != true ]]; then installed_copy=true; fi
    cache_targets=()
    while IFS=$'\t' read -r via target; do
      [[ -n "$target" ]] || continue
      audit_target="$target"

      if sb_path_is_within "$target" "$plugin_cache"; then
        if [[ "$is_shell" == true ]]; then
          cache_targets+=("$target")
        else
          emit_block "🚫 THIRD-PARTY PLUGIN BOUNDARY VIOLATION — You are attempting to edit a file inside the plugin cache:
$(basename "$target")

Silver Bullet NEVER modifies upstream plugin files. Implement the change in Silver Bullet's own layer instead:
  • Workflow instruction (templates/workflows/*.md)
  • Hook (hooks/*.sh)
  • Silver Bullet skill (skills/*/SKILL.md)

See CLAUDE.md §8 for details."
          exit 0
        fi
      fi

      # The host's plugin registry: rewriting it would corrupt the user's configuration and is how
      # an uninstall exemption could be faked (R2-31).
      if [[ "$target" == "$registry_canon" ]]; then
        emit_block "🚫 PLUGIN REGISTRY PROTECTED — ${SB_RUNTIME_HOME_ROOT}/plugins/installed_plugins.json belongs to the host. Install or uninstall plugins with the host's own commands, not by editing the registry."
        exit 0
      fi

      # Silver Bullet's own installed hooks (when running from an installed plugin copy).
      if { [[ "$installed_copy" == true ]] && { sb_path_is_within "$target" "${sb_plugin_root}/hooks" || [[ "$target" == "${sb_plugin_root}/hooks.json" ]]; }; } \
        || { [[ "$sb_source_checkout" != true ]] && sb_path_is_within "$target" "$runtime_root" && [[ "$target" == */hooks/* ]]; }; then
        emit_block "Silver Bullet NEVER modifies its own enforcement hooks. This would disable process compliance. If you need to reconfigure, use /sb:init."
        exit 0
      fi

      # State tamper prevention (SB-008): the state directory holds the skill records and every
      # gate's memory. Only the hooks write there; a few benign sentinels stay open to the agent.
      # Deleting a directory above it counts as deleting it.
      in_state=false
      if sb_path_is_within "$target" "$state_dir_canon"; then in_state=true; fi
      case "$via" in
        rm | rmdir | unlink | "git rm" | "find -delete" | "mv source")
          case "$state_dir_canon/" in "$target"/*) in_state=true ;; esac
          ;;
      esac
      if [[ "$in_state" == true ]]; then
        sentinel_ok=false
        if [[ "$target" == "$state_dir_canon" && "$via" == "mkdir" ]]; then sentinel_ok=true; fi
        case "${target##*/}" in
          session-init | stack-compression-mutex | sb-friction-log.md | roadmap-edit-override)
            [[ "$(dirname "$target")" == "$state_dir_canon" ]] && sentinel_ok=true
            ;;
        esac
        if [[ "$sentinel_ok" != true ]]; then
          emit_block "🚫 STATE TAMPER BLOCKED — Silver Bullet state files are written only by its hooks; writing, moving or deleting them bypasses workflow enforcement.

Skills are recorded automatically when invoked through the active runtime's SB-recognized skill invocation channel. Overrides and the trivial marker are the user's to create, from their own terminal.

To reset workflow state intentionally, run in your terminal (not from the agent):
      rm ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state"
          exit 0
        fi
      fi
    done <<<"$records"

    if [[ "$is_shell" == true ]]; then
      if [[ ${#cache_targets[@]} -gt 0 ]]; then
        uninstall_ok=false
        if declare -f sb_plugin_cache_command_is_uninstall_cleanup >/dev/null 2>&1 \
          && sb_plugin_cache_command_is_uninstall_cleanup "$shell_command" "${cache_targets[@]}"; then
          uninstall_ok=true
        fi
        if [[ "$uninstall_ok" != true ]]; then
          emit_block "🚫 THIRD-PARTY PLUGIN BOUNDARY VIOLATION via Bash command — Silver Bullet NEVER modifies upstream plugin files. See CLAUDE.md §8."
          exit 0
        fi
      fi
    fi
  fi

  # --- Which project do these writes belong to? ---------------------------------------------
  # A project is a directory holding BOTH .silver-bullet.json and silver-bullet.md (a stale
  # project-root cache never counts). Outside one this hook enforces nothing (R2-06).
  config_for_dir() {
    local found
    found="$(sb_find_project_config_walk_only_from "$1" 2>/dev/null)" || found=""
    if [[ -z "$found" ]]; then
      # The contract files are gone but the project has a record: it is still a project.
      found="$(sb_integrity_record_root "$1")"
      [[ -z "$found" ]] || found="$found/.silver-bullet.json"
    fi
    printf '%s' "$found"
  }
  targets_in_scope=""
  targets_all_non_logic=true
  scope_config=""
  scope_root=""
  scope_workflow="full-dev-cycle"
  logic_edit=false
  protected_hit=""
  protected_root=""
  a_root=""
  a_tags=""
  last_cfg_dir=""
  last_cfg=""
  loaded_cfg=""
  while IFS=$'\t' read -r via target; do
    [[ -n "$target" ]] || continue
    tdir="$(dirname "$target")"
    # A directory a tree-writing command fills is looked up as itself: it may BE a project root.
    if [[ -d "$target" ]] && sb_pf_tree_via "$via"; then tdir="$target"; fi
    if [[ "$tdir" == "$last_cfg_dir" ]]; then
      cfg="$last_cfg"
    else
      cfg="$(config_for_dir "$tdir")"
      last_cfg_dir="$tdir"
      last_cfg="$cfg"
    fi
    [[ -n "$cfg" ]] || continue
    root="$(sb_pf_canon "$(dirname "$cfg")")"
    a_root="$root"
    case "$target" in
      "$root/.silver-bullet.json") a_tags="${a_tags:+$a_tags }config" ;;
      "$root/silver-bullet.md") a_tags="${a_tags:+$a_tags }md" ;;
      "$root/.silver-bullet.prompt.json") a_tags="${a_tags:+$a_tags }prompt" ;;
      "$root/CLAUDE.md" | "$root/AGENTS.md") a_tags="${a_tags:+$a_tags }instr:${target##*/}" ;;
      "$root/.planning/ROADMAP.md" | "$root/.planning/STATE.md" | "$root/.planning/PROJECT.md") a_tags="${a_tags:+$a_tags }plan:${target##*/}" ;;
    esac
    # The enforcement contract files: changing them rewrites every gate (R1-07, R2-04). A
    # directory-capable write into a directory above them counts.
    while IFS= read -r cf; do
      cf="$(sb_pf_canon "$cf")"
      if [[ "$target" == "$cf" ]]; then protected_hit="$target"; protected_root="$root"; fi
      if sb_pf_extract_via "$via" && [[ "$cf" == "$target"/* ]]; then protected_hit="$cf"; protected_root="$root"; fi
    done < <(sb_pf_config_files "$root")
    if [[ "$cfg" != "$loaded_cfg" ]]; then
      sb_pf_src_load "$cfg"
      loaded_cfg="$cfg"
    fi
    # A tree written at the project root (tar -x, unzip, patch, git apply, git am) is production source.
    if sb_pf_tree_via "$via" && [[ "$target" == "$root" ]]; then
      [[ -z "$scope_config" ]] && { scope_config="$cfg"; scope_root="$root"; scope_workflow="$SB_PF_WORKFLOW"; }
      targets_in_scope="$targets_in_scope"$'\n'"$target"
      targets_all_non_logic=false
      logic_edit=true
      continue
    fi
    sb_pf_src_in_scope "$target" "$root" || continue
    [[ -z "$scope_config" ]] && { scope_config="$cfg"; scope_root="$root"; scope_workflow="$SB_PF_WORKFLOW"; }
    targets_in_scope="$targets_in_scope"$'\n'"$target"
    if ! sb_pf_is_non_logic "$target" "$SB_PF_WORKFLOW"; then
      targets_all_non_logic=false
      case "$target" in
        *.py | *.ts | *.tsx | *.js | *.jsx | *.go | *.rs | *.sh | *.rb | *.java | *.kt | *.swift | *.tf | *.hcl | *.c | *.cpp | *.h) logic_edit=true ;;
      esac
    fi
  done <<<"$records$nl$opaque_records"

  if [[ -n "$protected_hit" && "$hook_event" == "PreToolUse" ]]; then
    # The skills that legitimately rewrite these files (sb:init, sb:update, sb:add, sb:devops,
    # sb:migrate: SB_PF_CONTRACT_WRITER_SKILLS) unlock them; nobody else changes them.
    unlock_kind=md
    case "$protected_hit" in */.silver-bullet.json) unlock_kind=json ;; esac
    # The unlock is an entry of the verified record, not a file anyone can write.
    sb_integrity_verify "$protected_root" ""
    if ! sb_pf_contract_unlocked "$unlock_kind"; then
      audit_target="$protected_hit"
      emit_block "🚫 ENFORCEMENT CONTRACT PROTECTED — $(basename "$protected_hit") defines which gates run and what they require; rewriting, moving or deleting it disables process compliance.

Change it through the owning skill (/sb:init, /sb:update, /sb:add, /sb:devops, /sb:migrate), or have the user edit it directly in their own terminal. To read it, use cat, grep or jq."
      exit 0
    fi
  fi

  # --- PostToolUse: keep the integrity record in step with the sanctioned writers -----------
  if [[ "$hook_event" != "PreToolUse" ]]; then
    post_root="$(sb_integrity_root "$PWD")"
    if [[ -n "$post_root" ]]; then
      sb_integrity_verify "$post_root" ""
      # A file tool wrote an artifact: the gates that allowed it vouch for it. A shell command never does.
      if [[ "$is_shell" != true && -n "$a_tags" && "$a_root" == "$post_root" ]]; then
        # shellcheck disable=SC2086  # the tags are a word list
        sb_integrity_baseline "$post_root" entry $a_tags
      fi
      # A contract-writing skill is running: its edits to the files it owns are expected.
      unlock_tags="$(sb_contract_unlock_tags)"
      if [[ -n "$unlock_tags" ]]; then
        # shellcheck disable=SC2086  # the tags are a word list
        sb_integrity_baseline "$post_root" entry $unlock_tags
      fi
      sb_integrity_verify "$post_root" ""
      sb_integrity_restore_safe
      # The hint only wakes this hook up; the unlock itself lives in the record.
      if [[ -z "$SB_IV_UNLOCK_SKILL" ]]; then rm -f -- "${SB_RUNTIME_STATE_DIR}/unlock-hint"; fi
    fi
  fi

  [[ -n "$targets_in_scope" ]] || exit 0
  [[ "$skill_adapter" == true ]] && exit 0
  targets_in_scope="$(printf '%s\n' "$targets_in_scope" | awk 'NF && !seen[$0]++')"

  # --- Read the gate values from the integrity record (never from the live file) --------------
  config_file="$scope_config"
  active_workflow="$scope_workflow"
  SB_STATE_DIR="${SB_RUNTIME_STATE_DIR}"
  state_file="${SB_STATE_DIR}/state"
  # The legacy trivial marker (the DEFAULT path only) counts only while the record blesses it (R2-04).
  verify_tests_state_file="${SB_STATE_DIR}/verify-tests-state"
  sb_integrity_verify "$scope_root" ""
  if [[ "$active_workflow" == "devops-cycle" ]]; then
    required_planning="${SB_IV_REQUIRED_PLANNING_DEVOPS:-$SB_IV_REQUIRED_PLANNING}"
  else
    required_planning="$SB_IV_REQUIRED_PLANNING"
  fi
  [[ -z "$SB_IV_STATE_FILE" ]] || state_file="${SB_IV_STATE_FILE/#\~/$HOME}"

  # Current-version configs can explicitly set the planning floor. Legacy
  # configs are normalized to inherit the current default SB planning gates.
  default_planning="$DEFAULT_PLANNING"
  if [[ "$active_workflow" == "devops-cycle" ]]; then
    default_planning="$DEVOPS_DEFAULT_PLANNING"
  fi
  required_planning="$(sb_required_skills_normalize_configured_list "$config_file" "$required_planning" "$default_planning")"

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

  # --- Trivial marker: honoured only while the record blesses it -------------------------------
  sb_integrity_restore_safe
  if [[ "$SB_IV_TRIVIAL_OK" == true ]]; then
    exit 0
  fi

  # --- The contract the record vouches for changed outside a sanctioned skill -------------------
  if [[ "$hook_event" == "PreToolUse" ]]; then
    if [[ "$SB_IV_STATUS" == unbaselined ]]; then
      audit_target="$scope_root"
      emit_block "🚫 PROJECT NOT BASELINED — Silver Bullet has no integrity record for this project, so the strict defaults apply (planning floor unsatisfied, the template's required lists, no trivial bypass) and source edits stop.

Restart the session (session start records this project's contract files; a new worktree, a fresh clone or a project created inside another one needs its own session start) or run /sb:init. Details: ${SB_RUNTIME_STATE_DIR}/seal-events.log"
      exit 0
    fi
    for _div in $SB_IV_DIVERGED; do
      case "$_div" in
        config | md | prompt | record)
          audit_target="$scope_root"
          emit_block "🚫 ENFORCEMENT CONTRACT CHANGED — $_div no longer matches what Silver Bullet recorded${SB_IV_WHY:+ ($SB_IV_WHY)} (a command or an editor changed it outside a sanctioned skill), so the gates fall back to the strict defaults and source edits stop.

Revert the change (git checkout -- the file), run the owning skill (/sb:update, /sb:init, /sb:add, /sb:devops, /sb:migrate), or restart the session so session start re-records the files. Details: ${SB_RUNTIME_STATE_DIR}/seal-events.log"
          exit 0
          ;;
        instr:* | plan:*)
          emit_advisory "ℹ️ ${_div#*:} changed outside a file tool since it was recorded (logged in seal-events.log)."
          ;;
      esac
    done
  fi

  # --- PostToolUse: the edit has landed — the fresh-test-run record is stale ---------------
  if [[ "$hook_event" != "PreToolUse" ]]; then
    rm -f -- "$verify_tests_state_file" 2>/dev/null || true
    exit 0
  fi

  # --- Mid-session branch mismatch warning (F-09) -----------------------------------------
  current_branch=$(git -C "$PWD" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  current_toplevel=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)
  if sb_branch_scope_mismatch "$current_branch" "$current_toplevel"; then
    emit_advisory "Warning: Branch mismatch -- state recorded for [${SB_BRANCH_SCOPE_STORED_BRANCH}] but current branch is [${current_branch}]. Restart the session or clear runtime context to reset."
    # Warning only -- do not exit, let the rest of the hook proceed
  fi

  # --- Destructive command warning (F-04) -------------------------------------------------
  if [[ "$is_shell" == true ]]; then
    runtime_dir_frag="/.${SB_RUNTIME_NAME}/"
    while IFS=$'\t' read -r via target; do
      case "$via" in rm | "mv source") ;; *) continue ;; esac
      # Project files only: scratch space, caches and Silver Bullet's own directories are not.
      case "$target" in
        "$scope_root"/*) ;;
        *) continue ;;
      esac
      case "$target" in
        */.silver-bullet/* | *"$runtime_dir_frag"*) continue ;;
      esac
      emit_advisory "Warning: Destructive command detected (rm/mv on project files). Verify this is intentional before proceeding."
      break
    done <<<"$records"
  fi

  # --- Auto-detect trivial changes (per-edit, no persistent bypass) ------------------------
  if [[ "$targets_all_non_logic" == true ]]; then
    emit_advisory "ℹ️ Non-logic file — enforcement skipped for this edit."
    exit 0
  fi

  # Small edit changes (combined old+new < 100 chars) are trivial (typo fixes) — within a small
  # cumulative per-session budget, so code cannot be written as a sequence of tiny edits.
  if [[ "$tool_name" == "Edit" ]]; then
    combined_len=$(printf '%s' "$input" | jq -r '.tool_input | ((.old_string // "") | length) + ((.new_string // "") | length)' 2>/dev/null)
    if [[ "$combined_len" =~ ^[0-9]+$ && $combined_len -gt 0 && $combined_len -lt 100 ]]; then
      session_id=$(printf '%s' "$input" | jq -r '.session_id // "nosession"' 2>/dev/null)
      budget_file="${SB_STATE_DIR}/small-edit-budget"
      used=0
      if [[ -f "$budget_file" && ! -L "$budget_file" && "$(sed -n '1p' "$budget_file" 2>/dev/null)" == "$session_id" ]]; then
        used="$(sed -n '2p' "$budget_file" 2>/dev/null)"
        [[ "$used" =~ ^[0-9]+$ ]] || used=0
      fi
      if [[ $((used + combined_len)) -le 300 ]]; then
        if [[ ! -L "$budget_file" ]]; then
          printf '%s\n%s\n' "$session_id" "$((used + combined_len))" >"$budget_file" 2>/dev/null
        fi
        emit_advisory "ℹ️ Small edit ($combined_len chars) — enforcement skipped for this edit."
        exit 0
      fi
    fi
  fi

  # --- Composed-workflow admission control (Pass 2) ----------------------------------------
  # When a composed workflow is active in `.planning/workflows/<id>.md`, the call must belong to
  # one of them before any non-trivial source edit can reach the legacy planning gate. The active
  # workflow is the persisted/only one (hooks cannot see variables exported in the agent's shell).
  wf_dir="$scope_root/.planning/workflows"
  active_workflows=()
  if [[ -d "$wf_dir" && ! -L "$wf_dir" ]]; then
    shopt -s nullglob
    for _wf in "$wf_dir"/*.md; do
      [[ -f "$_wf" && ! -L "$_wf" ]] && active_workflows+=("$_wf")
    done
    shopt -u nullglob
  fi
  if [[ ${#active_workflows[@]} -gt 0 ]]; then
    active_id="$(sb_pf_workflow_id "$wf_dir" "$shell_command")"
    if [[ -z "$active_id" ]]; then
      active_names=""
      for _wf in "${active_workflows[@]}"; do
        active_names+="  • $(basename "$_wf" .md)"$'\n'
      done
      emit_block "$(printf '🛑 WORKFLOW ADMISSION — several composed workflows are active and none is selected.\n\nActive composed workflow(s):\n%s\nComplete the stale ones with scripts/workflows.sh complete <id> (stale workflows are auto-archived on session start), or resume the matching one with /sb.' "$active_names")"
      exit 0
    fi
    if ! [[ "$active_id" =~ ^[0-9]{8}T[0-9]{6}Z-[a-z0-9]+-[a-z0-9-]+$ ]]; then
      emit_block "$(printf '🛑 WORKFLOW ADMISSION — the active workflow id has invalid format: %s\n\nExpected: <UTCcompact>-<6char>-<composer>' "$active_id")"
      exit 0
    fi
    active_file="$wf_dir/$active_id.md"
    if [[ ! -f "$active_file" || -L "$active_file" ]]; then
      emit_block "$(printf '🛑 WORKFLOW ADMISSION — no active workflow file matches %s.\n\nUse /sb to resume the active composed workflow, or start a new composed workflow before editing source code.' "$active_id")"
      exit 0
    fi
  elif [[ "$logic_edit" == true ]]; then
    # F-06: no composed workflow — logic src edits that bypass /sb routing
    emit_advisory '🛑 WORKFLOW ADVISORY — logic source edit with no active composed workflow. Start /sb:fast (Tier 2+) or a composer workflow before application code changes. Tier 1 applies only to docs/config typo fixes.'
  fi

  # --- Read state file and determine stage -------------------------------------------------
  # Only what the hooks recorded counts: lines appended by anything else are not sealed.
  completed_skills="$(sb_state_seal_trusted "$state_file")"

  # Helper: check if a skill is in the completed list
  has_skill() {
    sb_required_skill_is_recorded "$completed_skills" "$1"
  }

  # --- Check required planning skills ------------------------------------------------------
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

  # --- Four-stage gate ---------------------------------------------------------------------
  audit_target="$(printf '%s\n' "$targets_in_scope" | sed -n '1p')"
  if [[ -n "$missing_skills" ]]; then
    # Stage A: missing planning skills — HARD STOP
    missing_display=""
    for ms in $missing_skills; do
      missing_display="${missing_display}❌ ${ms}"$'\n'
    done
    stage_a_msg=$(printf '🚫 HARD STOP — Planning incomplete. Missing skills:\n%s\nRun the missing planning skills before editing source code.' "$missing_display")
    if [[ -n "$unavailable_skills" ]]; then
      unavailable_display=""
      for us in $unavailable_skills; do
        unavailable_display="${unavailable_display}⚠️ ${us} (not installed anywhere invocable)"$'\n'
      done
      stage_a_msg=$(printf '%s\n\nIgnored required skills:\n%s\nInstall them if you want them enforced.' "$stage_a_msg" "$unavailable_display")
    fi
    emit_block "$stage_a_msg"
    exit 0
  fi

  if [[ -n "$unavailable_skills" ]]; then
    unavailable_display=""
    for us in $unavailable_skills; do
      unavailable_display="${unavailable_display}⚠️ ${us} (not installed anywhere invocable)"$'\n'
    done
    stage_a_msg=$(printf '⚠️ Planning skills not installed anywhere invocable, so they were not enforced:\n%s\nProceeding with source edits.' "$unavailable_display")
    sb_hook_audit_record "dev-cycle-check" "$hook_event" "allow" "$stage_a_msg" "$audit_target"
    emit_advisory "$stage_a_msg"
    exit 0
  fi

  # --- Phase skip detection (after HARD STOP so Stage A always fires first) ----------------
  # Derive post-review/finalization skills from config required_deploy; fall back to
  # hardcoded defaults. Context/plan/execute/verify/review are normal lifecycle
  # lifecycle markers and must not be treated as phase-skip evidence.
  finalization_skills="silver-branch-finish silver-create-release silver-completion-audit tdd"
  cfg_finalization=""
  for _fs in $SB_IV_REQUIRED_DEPLOY; do
    case "$_fs" in
      silver-quality-gates | silver-blast-radius | devops-quality-gates | silver-context | silver-plan | silver-execute | silver-verify | silver-review | silver-review-request | silver-review-triage | requesting-code-review | receiving-code-review) ;;
      *) cfg_finalization="${cfg_finalization:+$cfg_finalization }$_fs" ;;
    esac
  done
  [[ -n "$cfg_finalization" ]] && finalization_skills="$cfg_finalization"
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
      sb_hook_audit_record "dev-cycle-check" "$hook_event" "allow" "Planning verified, but finalization markers exist before silver-review." "$audit_target"
      emit_advisory "⚠️ Planning verified, but finalization markers exist before silver-review. Source edits are allowed so fixes can proceed; final delivery remains blocked until review/verification gates pass in order."
    else
      sb_hook_audit_record "dev-cycle-check" "$hook_event" "allow" "Planning verified. Implementation edits allowed." "$audit_target"
      emit_advisory "✅ Planning verified. Implementation edits allowed. Code review, verification, and finalization remain required before delivery."
    fi
    exit 0
  fi

  if ! has_skill "silver-branch-finish"; then
    # Stage C: has silver-review, finalization remaining
    sb_hook_audit_record "dev-cycle-check" "$hook_event" "allow" "SB code review recorded. Source edits remain allowed." "$audit_target"
    emit_advisory "✅ SB code review recorded. Source edits remain allowed; finalization, verification, and delivery gates still apply."
    exit 0
  fi

  # Stage D: all phases complete
  sb_hook_audit_record "dev-cycle-check" "$hook_event" "allow" "All workflow phases complete. Proceed freely." "$audit_target"
  emit_advisory "✅ All workflow phases complete. Proceed freely."
  exit 0
}

# Run main in a command substitution: its output is exactly one document (or none), whatever path
# it exits through, and the host-facing exit status is main's.
out="$(main)"
printf '%s' "$out"
exit 0
