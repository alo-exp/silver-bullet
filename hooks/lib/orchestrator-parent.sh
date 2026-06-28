# shellcheck shell=bash
# Orchestrator parent mode — parent session delegates via Task workers only.

# Returns orchestrator_mode from config (default: parent). Only "parent" is valid.
sb_orchestrator_mode_from_config() {
  local config_file="${1:-}"
  [[ -n "$config_file" && -f "$config_file" ]] || { printf 'parent'; return 0; }
  command -v jq >/dev/null 2>&1 || { printf 'parent'; return 0; }
  local mode
  mode="$(jq -r '.orchestrator_mode // "parent"' "$config_file" 2>/dev/null || echo parent)"
  [[ "$mode" == "parent" ]] || mode="parent"
  printf '%s' "$mode"
}

sb_orchestrator_worker_marker_file() {
  printf '%s/orchestrator-worker-active.json' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

# Worker subagent session — env var, explicit parent=0, or fresh Task spawn marker file.
sb_orchestrator_is_worker_session() {
  [[ "${SB_ORCHESTRATOR_WORKER:-}" == "1" || "${SB_ORCHESTRATOR_WORKER:-}" == "true" ]] && return 0
  [[ "${SB_ORCHESTRATOR_PARENT:-}" == "0" ]] && return 0
  # Explicit parent env wins over a stale Task spawn marker.
  [[ "${SB_ORCHESTRATOR_PARENT:-}" == "1" || "${SB_ORCHESTRATOR_PARENT:-}" == "true" ]] && return 1

  local marker_file spawned_at now_epoch spawn_epoch ttl
  marker_file="$(sb_orchestrator_worker_marker_file)"
  [[ -f "$marker_file" && ! -L "$marker_file" ]] || return 1

  spawned_at=""
  if command -v jq >/dev/null 2>&1; then
    spawned_at="$(jq -r '.spawned_at // ""' "$marker_file" 2>/dev/null || true)"
  fi
  if [[ -z "$spawned_at" ]]; then
    grep -qE '"spawned_at"[[:space:]]*:[[:space:]]*"[^"]+"' "$marker_file" 2>/dev/null || return 1
    spawned_at="$(grep -oE '"spawned_at"[[:space:]]*:[[:space:]]*"[^"]+"' "$marker_file" 2>/dev/null | head -1 | sed -E 's/.*"([^"]+)"$/\1/' || true)"
  fi
  ttl="${SB_ORCHESTRATOR_WORKER_MARKER_TTL_SECONDS:-7200}"
  if [[ -z "$spawned_at" ]]; then
    return 1
  fi

  now_epoch="$(date +%s)"
  if date -ju -f "%Y-%m-%dT%H:%M:%SZ" "$spawned_at" +%s >/dev/null 2>&1; then
    spawn_epoch="$(date -ju -f "%Y-%m-%dT%H:%M:%SZ" "$spawned_at" +%s 2>/dev/null || echo 0)"
  elif date -j -f "%Y-%m-%dT%H:%M:%SZ" "$spawned_at" +%s >/dev/null 2>&1; then
    spawn_epoch="$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$spawned_at" +%s 2>/dev/null || echo 0)"
  else
    spawn_epoch="$(date -d "$spawned_at" +%s 2>/dev/null || echo 0)"
  fi
  [[ "$spawn_epoch" -gt 0 ]] || return 1
  if (( now_epoch - spawn_epoch < ttl )); then
    return 0
  fi
  return 1
}

# True when current PWD walk finds SB boundary (.silver-bullet.json + silver-bullet.md).
# Never uses project-root cache — stale cache must not activate orchestrator enforcement.
sb_orchestrator_workspace_has_boundary() {
  local config_file=""
  if declare -f sb_find_project_config_walk_only >/dev/null 2>&1; then
    config_file="$(sb_find_project_config_walk_only 2>/dev/null || true)"
  fi
  [[ -n "$config_file" && -f "$config_file" ]]
}

# True when orchestrator guard blocks may apply in the current workspace.
sb_orchestrator_guard_applies_to_workspace() {
  local repo_root=""
  sb_orchestrator_workspace_has_boundary || return 1
  if declare -f sb_find_project_root_walk_only >/dev/null 2>&1; then
    repo_root="$(sb_find_project_root_walk_only 2>/dev/null || true)"
  fi
  [[ -n "$repo_root" ]] || return 1
  if sb_orchestrator_parent_queue_pending 2>/dev/null; then
    sb_orchestrator_state_applies_to_project "$repo_root" || return 1
  fi
  return 0
}

# Parent orchestrator session — config parent mode and not a worker subagent.
sb_orchestrator_is_parent_session() {
  if sb_orchestrator_is_worker_session; then
    return 1
  fi
  local config_file=""
  if declare -f sb_find_project_config_walk_only >/dev/null 2>&1; then
    config_file="$(sb_find_project_config_walk_only 2>/dev/null || true)"
  fi
  # No walk-resolved config — not parent (cache-only resolution must not default parent).
  [[ -n "$config_file" ]] || return 1
  [[ "${SB_ORCHESTRATOR_PARENT:-}" == "1" || "${SB_ORCHESTRATOR_PARENT:-}" == "true" ]] && return 0
  [[ "$(sb_orchestrator_mode_from_config "$config_file")" == "parent" ]]
}

# Map flow/skill token to worker prompt template basename (without path).
sb_orchestrator_worker_template_for_skill() {
  local skill="$1"
  case "$skill" in
    FLOW-BOOTSTRAP|BOOTSTRAP|silver-init) printf 'BOOTSTRAP' ;;
    FLOW-ORIENT|ORIENT|silver-context|silver-scan) printf 'ORIENT' ;;
    FLOW-CLARIFY|CLARIFY|silver-clarify) printf 'CLARIFY' ;;
    FLOW-DECIDE|DECIDE|silver-research) printf 'DECIDE' ;;
    FLOW-SPECIFY|SPECIFY|silver-spec|silver-ingest) printf 'SPECIFY' ;;
    devops-skill-router) printf 'DEVOPS-SKILL-ROUTER' ;;
    FLOW-REVIEW-REQUEST|REVIEW-REQUEST|REVIEW\ REQUEST|silver-review-request) printf 'REVIEW-REQUEST' ;;
    FLOW-REVIEW-TRIAGE|REVIEW-TRIAGE|REVIEW\ TRIAGE|silver-review-triage) printf 'REVIEW-TRIAGE' ;;
    silver-branch-finish) printf 'BRANCH-FINISH' ;;
    silver-completion-audit) printf 'COMPLETION-AUDIT' ;;
    FLOW-PLAN|PLAN|silver-plan) printf 'PLAN' ;;
    FLOW-DESIGN-CONTRACT|DESIGN-CONTRACT|DESIGN\ CONTRACT|silver-ui-contract) printf 'DESIGN-CONTRACT' ;;
    FLOW-EXECUTE|EXECUTE|silver-execute) printf 'EXECUTE' ;;
    FLOW-UI-QUALITY|UI-QUALITY|UI\ QUALITY|silver-ui-review) printf 'UI-QUALITY' ;;
    FLOW-REVIEW|REVIEW|silver-review) printf 'REVIEW' ;;
    security) printf 'SECURITY' ;;
    FLOW-SECURE|SECURE|silver-secure) printf 'SECURE' ;;
    FLOW-VERIFY|VERIFY|silver-verify) printf 'VERIFY' ;;
    FLOW-QUALITY-GATE|QUALITY-GATE|QUALITY\ GATE|silver-quality-gates|devops-quality-gates) printf 'QUALITY-GATE' ;;
    FLOW-SHIP|SHIP|silver-ship) printf 'SHIP' ;;
    FLOW-DEBUG|DEBUG|silver-debug|silver-forensics) printf 'DEBUG' ;;
    FLOW-DESIGN-HANDOFF|DESIGN-HANDOFF|DESIGN\ HANDOFF|silver-handoff) printf 'DESIGN-HANDOFF' ;;
    FLOW-DOCUMENT|DOCUMENT|silver-ensure-docs) printf 'DOCUMENT' ;;
    FLOW-RELEASE|RELEASE|silver-release|silver-create-release) printf 'RELEASE' ;;
    silver-blast-radius) printf 'BLAST-RADIUS' ;;
    silver-validate) printf 'VALIDATE' ;;
    silver-fast) printf 'FAST' ;;
    silver|silver-orchestrator) printf 'ROUTER' ;;
    *)
      if [[ "$skill" == silver-* ]]; then
        printf '%s' "$(printf '%s' "${skill#silver-}" | tr '[:lower:]' '[:upper:]')"
      else
        printf '%s' "$(printf '%s' "$skill" | tr '[:lower:]' '[:upper:]')"
      fi
      ;;
  esac
}

# Resolve worker template path: project copy first, then plugin/repo templates.
sb_orchestrator_worker_template_path() {
  local repo_root="$1"
  local template_name="$2"
  local rel=".silver-bullet/orchestrator-workers/${template_name}.md"
  if [[ -n "$repo_root" && -f "$repo_root/$rel" ]]; then
    printf '%s' "$repo_root/$rel"
    return 0
  fi
  rel="templates/orchestrator-workers/${template_name}.md"
  if [[ -n "$repo_root" && -f "$repo_root/$rel" ]]; then
    printf '%s' "$repo_root/$rel"
    return 0
  fi
  return 1
}

# Write active worker marker when parent spawns Task for a flow skill.
sb_orchestrator_mark_worker_spawn() {
  local skill="$1"
  local template="${2:-}"
  local args="${3:-}"
  [[ -n "$skill" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  [[ -n "$template" ]] || template="$(sb_orchestrator_worker_template_for_skill "$skill")"
  local now file dir json
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  file="$(sb_orchestrator_worker_marker_file)"
  dir="$(dirname "$file")"
  mkdir -p "$dir" 2>/dev/null || true
  json="$(jq -n \
    --arg skill "$skill" \
    --arg template "$template" \
    --arg args "$args" \
    --arg at "$now" \
    '{skill:$skill, template:$template, args:$args, spawned_at:$at}')"
  printf '%s' "$json" >"${file}.tmp" 2>/dev/null && mv "${file}.tmp" "$file"
}

sb_orchestrator_clear_worker_marker() {
  rm -f -- "$(sb_orchestrator_worker_marker_file)" 2>/dev/null || true
}

# Pending = non-empty current_flow in orchestrator state.
sb_orchestrator_parent_queue_pending() {
  local file
  file="$(sb_orchestrator_state_file 2>/dev/null || printf '%s/orchestrator.json' "${SB_RUNTIME_STATE_DIR:-/tmp}")"
  [[ -f "$file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  local cur
  cur="$(jq -r '.current_flow // ""' "$file" 2>/dev/null || true)"
  [[ -n "$cur" && "$cur" != "null" ]]
}

sb_orchestrator_normalize_repo_root() {
  local root="$1"
  [[ -n "$root" ]] || return 1
  if command -v realpath >/dev/null 2>&1; then
    realpath "$root" 2>/dev/null || printf '%s' "$root"
    return 0
  fi
  (cd "$root" 2>/dev/null && pwd) || printf '%s' "$root"
}

# True when orchestrator.json current_flow applies to the given project root.
# Prevents cross-project stale state from blocking Stop in unrelated repos/tests.
sb_orchestrator_state_applies_to_project() {
  local repo_root="$1"
  [[ -n "$repo_root" ]] || return 1
  sb_orchestrator_parent_queue_pending || return 1

  local file stored_root wid wf_file norm_stored norm_current
  file="$(sb_orchestrator_state_file 2>/dev/null || true)"
  [[ -f "$file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  stored_root="$(jq -r '.repo_root // ""' "$file" 2>/dev/null || true)"
  if [[ -n "$stored_root" && "$stored_root" != "null" ]]; then
    norm_stored="$(sb_orchestrator_normalize_repo_root "$stored_root")"
    norm_current="$(sb_orchestrator_normalize_repo_root "$repo_root")"
    [[ "$norm_stored" == "$norm_current" ]]
    return $?
  fi

  wid="$(jq -r '.workflow_id // ""' "$file" 2>/dev/null || true)"
  if [[ -n "$wid" && "$wid" != "null" ]]; then
    wf_file="$repo_root/.planning/workflows/$wid.md"
    [[ -f "$wf_file" && ! -L "$wf_file" ]]
    return $?
  fi

  # No repo_root or workflow_id — cannot prove this queue belongs to the current project.
  return 1
}

# Orchestrator-spawned workers may use Bash for delivery ops without a prior
# skill record — parent already routed; workers cannot meaningfully invoke /silver.
sb_orchestrator_worker_allows_bash() {
  local tool_name="$1"
  sb_orchestrator_is_worker_session || return 1
  case "$tool_name" in
    Bash|exec_command|Shell) return 0 ;;
    *) return 1 ;;
  esac
}

# Parent-allowed PreToolUse tools (read-only + delegation).
sb_orchestrator_parent_tool_allowed() {
  local tool_name="$1"
  case "$tool_name" in
    Task|Subagent|Agent|Read|Grep|Glob|SemanticSearch|WebSearch|WebFetch|AskQuestion|SwitchMode|UpdateCurrentStep|CallMcpTool|FetchMcpResource)
      return 0
      ;;
    Skill)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Parent may only invoke router/orchestrator skills directly — flow atoms via Task workers.
sb_orchestrator_parent_skill_allowed() {
  local skill="$1"
  local canonical="$skill"
  if declare -f sb_skill_canonical_name >/dev/null 2>&1; then
    canonical="$(sb_skill_canonical_name "$skill")"
  else
    canonical="${skill#silver:}"
    canonical="${canonical//:/-}"
  fi
  case "$canonical" in
    silver|silver-orchestrator) return 0 ;;
    *) return 1 ;;
  esac
}

# Parent context block for session injection.
sb_orchestrator_parent_context_block() {
  sb_orchestrator_is_parent_session || return 0
  printf '%s\n' \
    "SB ORCHESTRATOR PARENT MODE (mandatory)" \
    "  You are the parent orchestrator — NEVER Edit/Write/Bash on project source." \
    "  Read orchestrator-directive.json → spawn Task worker with templates/orchestrator-workers/<TEMPLATE>.md" \
    "  On worker completion: flow-advance queues next_worker_template + next_skill → spawn next worker." \
    "  Ask the user ONLY for locked decisions (decision_class in outcomes)."
}
