# shellcheck shell=bash
# Orchestrator parent mode — parent session delegates via Task workers only.

_sb_orch_parent_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${_sb_orch_parent_lib_dir}/orchestrator-io.sh" ]]; then
  # shellcheck source=lib/orchestrator-io.sh
  source "${_sb_orch_parent_lib_dir}/orchestrator-io.sh"
fi

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

# agent id the host puts in the payload of every hook call made inside a subagent
# (Claude Code: agent_id/agent_type on PreToolUse, PostToolUse and SubagentStop). The main
# session's payloads never carry it, so it is the one per-call signal a parent cannot
# acquire by spawning something (R4-02). Only top-level fields count: tool_input content
# is written by the model and proves nothing.
sb_orchestrator_payload_agent_id() {
  local payload="${1:-}"
  [[ -n "$payload" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  printf '%s' "$payload" | jq -r '
    if type == "object" then ((.agent_id // .agentId // "") | if type == "string" then . else "" end) else "" end
  ' 2>/dev/null || true
}

# Worker subagent session: explicit env, or a payload that carries a subagent id.
#   sb_orchestrator_is_worker_session [HOOK_PAYLOAD_JSON]
# The payload defaults to $SB_ORCH_HOOK_INPUT. A missing id never means worker, and there is
# no global "a worker was spawned" marker any more: it could not tell the parent from a
# worker, from two parallel workers, or from a spawn that never started.
sb_orchestrator_is_worker_session() {
  [[ "${SB_ORCHESTRATOR_WORKER:-}" == "1" || "${SB_ORCHESTRATOR_WORKER:-}" == "true" ]] && return 0
  [[ "${SB_ORCHESTRATOR_PARENT:-}" == "0" ]] && return 0
  # Explicit parent env wins over a payload id.
  [[ "${SB_ORCHESTRATOR_PARENT:-}" == "1" || "${SB_ORCHESTRATOR_PARENT:-}" == "true" ]] && return 1
  local agent_id
  agent_id="$(sb_orchestrator_payload_agent_id "${1:-${SB_ORCH_HOOK_INPUT:-}}")"
  [[ -n "$agent_id" ]]
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
# Parent-mode enforcement needs the host to say who a worker is. Claude Code does (agent_id on every
# subagent call); Codex does not yet, so there a worker is indistinguishable from the parent and
# enforcing parent mode would deny a worker's own edits. On such hosts parent mode is INACTIVE (a
# clean no-op) unless SB_ORCHESTRATOR_PARENT=1 forces it.
sb_orchestrator_host_identifies_workers() {
  case "${SILVER_BULLET_RUNTIME:-claude}" in
    claude) return 0 ;;
    *) return 1 ;;
  esac
}

# shellcheck disable=SC2120  # optional payload argument; hooks usually set SB_ORCH_HOOK_INPUT instead
sb_orchestrator_is_parent_session() {
  if sb_orchestrator_is_worker_session "${1:-}"; then
    return 1
  fi
  if ! sb_orchestrator_host_identifies_workers \
     && [[ "${SB_ORCHESTRATOR_PARENT:-}" != "1" && "${SB_ORCHESTRATOR_PARENT:-}" != "true" ]]; then
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
    FLOW-DECIDE|DECIDE|silver-deep-research) printf 'DECIDE' ;;
    FLOW-SPECIFY|SPECIFY|silver-spec|silver-ingest) printf 'SPECIFY' ;;
    devops-skill-router) printf 'DEVOPS-SKILL-ROUTER' ;;
    FLOW-REVIEW-REQUEST|REVIEW-REQUEST|REVIEW\ REQUEST|silver-review-request) printf 'REVIEW-REQUEST' ;;
    FLOW-REVIEW-TRIAGE|REVIEW-TRIAGE|REVIEW\ TRIAGE|silver-review-triage) printf 'REVIEW-TRIAGE' ;;
    silver-branch-finish) printf 'BRANCH-FINISH' ;;
    silver-completion-audit) printf 'COMPLETION-AUDIT' ;;
    FLOW-PLAN|PLAN|silver-plan) printf 'PLAN' ;;
    silver-new-workflow) printf 'NEW-WORKFLOW' ;;
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
    # Delivery-floor skills run inside their atom's worker template (the directive names the skill).
    silver-triage) printf 'REVIEW-TRIAGE' ;;
    tdd) printf 'EXECUTE' ;;
    verify-tests) printf 'VERIFY' ;;
    silver-validate) printf 'VALIDATE' ;;
    silver-fast) printf 'FAST' ;;
    silver|silver-orchestrator) printf 'ROUTER' ;;
    silver-agent-codex|silver-agent-cursor|silver-agent-claude|silver-agent-opencode|silver-agent-pi) printf 'AGENT-DELEGATE' ;;
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

# Record that the parent asked for a worker (orchestrator-worker-active.json). This is evidence
# for the e2e scorers and diagnostics only: it says nothing about WHO is calling a hook, so no
# gate may use it to classify a session (see sb_orchestrator_is_worker_session).
sb_orchestrator_mark_worker_spawn() {
  local skill="$1"
  local template="${2:-}"
  local args="${3:-}"
  [[ -n "$skill" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  [[ -n "$template" ]] || template="$(sb_orchestrator_worker_template_for_skill "$skill")"
  local now json
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  json="$(jq -n \
    --arg skill "$skill" \
    --arg template "$template" \
    --arg args "$args" \
    --arg at "$now" \
    '{skill:$skill, template:$template, args:$args, spawned_at:$at}')"
  sb_orchestrator_atomic_write "$(sb_orchestrator_worker_marker_file)" "$json"
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
# skill record — parent already routed; workers cannot meaningfully invoke /sb.
sb_orchestrator_worker_allows_bash() {
  local tool_name="$1"
  sb_orchestrator_is_worker_session "${2:-}" || return 1
  case "$tool_name" in
    Bash|exec_command|Shell) return 0 ;;
    *) return 1 ;;
  esac
}

# Host-native delegation tool label for parent context and guard messages.
sb_orchestrator_spawn_tool_label() {
  case "${SILVER_BULLET_RUNTIME:-cursor}" in
    codex) printf '%s' 'spawn_agent (multi_agent_v1.spawn_agent)' ;;
    claude) printf '%s' 'Agent (Claude subagent)' ;;
    *) printf '%s' 'Task worker' ;;
  esac
}

# Parent-allowed PreToolUse tools (read-only + delegation).
sb_orchestrator_parent_tool_allowed() {
  local tool_name="$1"
  case "$tool_name" in
    Task|Subagent|Agent|spawn_agent|multi_agent_v1.spawn_agent|Read|Grep|Glob|SemanticSearch|WebSearch|WebFetch|AskQuestion|SwitchMode|UpdateCurrentStep|CallMcpTool|FetchMcpResource)
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

# ---------------------------------------------------------------------------
# Parent Bash policy (R4-03). Command shape comes from the shared classifier
# (hooks/lib/shell-analysis.sh, F2); this file keeps no command-text patterns of its own.
#   1. strictly read-only (SB_SA_READ_ONLY)              -> allowed
#   2. exactly ONE real command (wrappers env/sh -c/NAME=value peeled off), no redirect
#      or other write, whose program is one of the sanctioned parent tools -> allowed
#   3. everything else                                    -> denied
# A classifier failure (python3 missing, helper crash) is denied with a message that says
# how to proceed, never waved through.
# ---------------------------------------------------------------------------

# The classifier lives next to this file.
_sb_orch_parent_load_analysis() {
  declare -f sb_shell_analysis_load >/dev/null 2>&1 || {
    # shellcheck source=shell-analysis.sh
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/shell-analysis.sh" 2>/dev/null || return 1
  }
  sb_shell_analysis_load "$1"
}

# Effective argv (JSON array) when the analysed command is one lone command, possibly behind
# env / NAME=value / "sh -c" / "sh script" wrappers; prints nothing and returns 1 otherwise.
# Chains, pipes, command substitutions and backgrounded extras add commands and so fail.
_sb_orch_parent_lone_argv() {
  printf '%s' "${SB_SA_JSON:-}" | jq -ce '
    def base: split("/") | last;
    (.commands // []) as $c
    | def step($i):
        ($c[$i].argv // []) as $a
        | if ($a | length) == 0 then null
          elif ($a[0] | base) == "env" then
            ([$a[1:] | to_entries[]
              | select((.value | startswith("-") | not) and (.value | test("^[A-Za-z_][A-Za-z0-9_]*=") | not))][0].key) as $k
            | if $k == null then null
              elif ($c[$i + 1].argv // null) == $a[(1 + $k):] then step($i + 1)
              else null end
          elif (["bash", "sh", "zsh", "dash", "ksh"] | index($a[0] | base)) != null then
            ([$a[1:] | to_entries[] | select(.value | test("^-[A-Za-z]*c[A-Za-z]*$"))][0].key) as $ck
            | if $ck != null then
                (if $c[$i + 1] != null then step($i + 1) else null end)
              else
                ([$a[1:] | to_entries[] | select(.value | startswith("-") | not)][0].key) as $sk
                | if $sk == null or $i != ($c | length) - 1 then null else $a[(1 + $sk):] end
              end
          elif $i != ($c | length) - 1 then null
          else $a end;
      step(0)
    | select(. != null and length > 0)' 2>/dev/null
}

# No assignment/env prefix may change how a sanctioned command starts or which program it finds
# (BASH_ENV=, PATH=, LD_PRELOAD= ... make a trusted name run something else). F2 drops plain
# NAME=value words from argv, so the prefix is read from its rtk_unwrapped field and from `env`
# entries; the same is applied to every sh -c payload (nested).
_sb_orch_parent_prefix_free() {
  local payload payloads
  [[ -z "${SB_SA_RTK_UNWRAPPED:-}" ]] || return 1
  if printf '%s' "${SB_SA_JSON:-}" | jq -e '[.commands[]? | select((.argv[0] // "") | split("/") | last == "env")] | length > 0' >/dev/null 2>&1; then
    return 1
  fi
  payloads="$(printf '%s' "${SB_SA_JSON:-}" | jq -r '
    .commands[]? | .argv as $a
    | select((["bash", "sh", "zsh", "dash", "ksh"] | index(($a[0] // "") | split("/") | last)) != null)
    | ([$a[1:] | to_entries[] | select(.value | test("^-[A-Za-z]*c[A-Za-z]*$"))][0].key) as $k
    | select($k != null) | ($a[$k + 2] // empty) | @base64' 2>/dev/null)"
  while IFS= read -r payload; do
    [[ -n "$payload" ]] || continue
    payload="$(printf '%s' "$payload" | base64 -d 2>/dev/null)"
    # Each payload is a strictly shorter string than its parent command, so the recursion ends.
    sb_shell_analysis_load "$payload"
    [[ "$SB_TI_STATUS" == "ok" ]] && _sb_orch_parent_prefix_free || return 1
  done <<<"$payloads"
  return 0
}

# `bash <script> invoke-skill ...`: the script must be this plugin's own scripts/silver-bullet, not
# a file the project or the agent put under that name. Direct and `bash -c` forms are unaffected.
_sb_orch_parent_script_form_ok() {
  local script plugin_script
  script="$(printf '%s' "${SB_SA_JSON:-}" | jq -r '
    (.commands[0].argv // []) as $a
    | if (["bash", "sh", "zsh", "dash", "ksh"] | index(($a[0] // "") | split("/") | last)) == null then empty
      elif any($a[1:][]; test("^-[A-Za-z]*c[A-Za-z]*$")) then empty
      else ([$a[1:][] | select(startswith("-") | not)][0] // empty) end' 2>/dev/null)"
  [[ -n "$script" ]] || return 0
  plugin_script="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/silver-bullet"
  [[ "$(cd "$(dirname "$script")" 2>/dev/null && pwd)/$(basename "$script")" == "$plugin_script" ]]
}

# Skill named by a lone "silver-bullet invoke-skill <skill>" call, else nothing (rc 1).
sb_orchestrator_extract_invoke_skill_adapter() {
  local command_str="$1" argv
  [[ -n "$command_str" ]] || return 1
  _sb_orch_parent_load_analysis "$command_str" || return 1
  [[ "$SB_TI_STATUS" == "ok" && -z "$SB_SA_WRITE_PATHS" ]] || return 1
  argv="$(_sb_orch_parent_lone_argv)" || return 1
  jq -er '
    if ((.[0] | split("/") | last) == "silver-bullet") and .[1] == "invoke-skill" and (.[2] // "") != ""
    then .[2] else empty end' <<<"$argv" 2>/dev/null
}

# A delegate script (scripts/agent-<host>-delegate.sh, scripts/agent-<host>/invoke.sh) run as
# a lone command, only through the degraded-fallback switch.
sb_orchestrator_parent_delegate_bash_allowed() {
  local command_str="$1" argv
  [[ -n "$command_str" ]] || return 1
  [[ "${SB_AGENT_DELEGATE_DIRECT_FALLBACK:-0}" == "1" ]] || return 1
  _sb_orch_parent_load_analysis "$command_str" || return 1
  [[ "$SB_TI_STATUS" == "ok" && -z "$SB_SA_WRITE_PATHS" ]] || return 1
  argv="$(_sb_orch_parent_lone_argv)" || return 1
  _sb_orch_parent_prefix_free || return 1
  jq -e '
    .[0] as $p
    | any(["codex", "cursor", "claude", "opencode", "pi"][];
          . as $h | ($p == "scripts/agent-" + $h + "-delegate.sh" or ($p | endswith("/scripts/agent-" + $h + "-delegate.sh"))
                     or $p == "scripts/agent-" + $h + "/invoke.sh" or ($p | endswith("/scripts/agent-" + $h + "/invoke.sh"))))
    ' <<<"$argv" >/dev/null 2>&1
}

# Parent may clear own-scope instruction ledger via the sanctioned resolve CLI (#264): the
# script as a lone command with one of its documented sub-commands (or none, which prints help).
sb_orchestrator_parent_resolve_ledger_bash_allowed() {
  local command_str="$1" argv
  [[ -n "$command_str" ]] || return 1
  _sb_orch_parent_load_analysis "$command_str" || return 1
  [[ "$SB_TI_STATUS" == "ok" && -z "$SB_SA_WRITE_PATHS" ]] || return 1
  argv="$(_sb_orch_parent_lone_argv)" || return 1
  _sb_orch_parent_prefix_free || return 1
  jq -e '
    .[0] as $p
    | ($p == "scripts/resolve-instruction-ledger.sh" or ($p | endswith("/scripts/resolve-instruction-ledger.sh")))
      and ((.[1] // "list") | IN("list", "done", "deferred", "help", "--help", "-h"))
    ' <<<"$argv" >/dev/null 2>&1
}

# Reason of the last sb_orchestrator_parent_bash_allowed denial that is not the plain
# "forbidden in parent mode" (classifier failure); empty otherwise.
# shellcheck disable=SC2034  # read by orchestrator-directive-guard.sh
SB_ORCH_PARENT_BASH_DENY_REASON=""

# sb_orchestrator_parent_bash_allowed COMMAND: see the policy above.
sb_orchestrator_parent_bash_allowed() {
  local command_str="$1" adapter_skill
  SB_ORCH_PARENT_BASH_DENY_REASON=""
  [[ -n "$command_str" ]] || return 1
  _sb_orch_parent_load_analysis "$command_str" || {
    # shellcheck disable=SC2034  # SB_TI_ERROR is read by sb_shell_analysis_helper_message
    SB_TI_STATUS="helper_unavailable" SB_TI_ERROR="the shell classifier library is missing"
  }
  case "$SB_TI_STATUS" in
    ok) ;;
    helper_unavailable)
      # shellcheck disable=SC2034  # result variable read by callers
      SB_ORCH_PARENT_BASH_DENY_REASON="$(sb_shell_analysis_helper_message 2>/dev/null || printf 'Silver Bullet cannot inspect this Bash call: python3 is a required prerequisite.')"
      return 1
      ;;
    *) return 1 ;;
  esac
  [[ "$SB_SA_READ_ONLY" == "true" ]] && return 0

  adapter_skill="$(sb_orchestrator_extract_invoke_skill_adapter "$command_str" 2>/dev/null || true)"
  if [[ -n "$adapter_skill" ]]; then
    # extract just analysed this command: the globals still describe it.
    _sb_orch_parent_prefix_free && _sb_orch_parent_script_form_ok || return 1
    sb_orchestrator_parent_skill_allowed "$adapter_skill"
    return $?
  fi
  sb_orchestrator_parent_delegate_bash_allowed "$command_str" && return 0
  sb_orchestrator_parent_resolve_ledger_bash_allowed "$command_str"
}

# Parent may only invoke router/orchestrator skills directly — flow atoms via Task workers.
sb_orchestrator_parent_skill_allowed() {
  local skill="$1"
  local canonical="$skill"
  if declare -f sb_skill_canonical_name >/dev/null 2>&1; then
    canonical="$(sb_skill_canonical_name "$skill")"
  else
    case "$skill" in
      sb) canonical="silver" ;;
      sb:*) canonical="silver-${skill#sb:}" ;;
      sb-*) canonical="silver-${skill#sb-}" ;;
      *)
        canonical="${skill#sb:}"
        canonical="${canonical//:/-}"
        ;;
    esac
  fi
  case "$canonical" in
    silver|silver-orchestrator|silver-agent-codex|silver-agent-cursor|silver-agent-claude|silver-agent-opencode|silver-agent-pi) return 0 ;;
    *) return 1 ;;
  esac
}

# Parent context block for session injection.
sb_orchestrator_parent_context_block() {
  sb_orchestrator_is_parent_session || return 0
  local spawn_label
  spawn_label="$(sb_orchestrator_spawn_tool_label)"
  printf '%s\n' \
    "SB ORCHESTRATOR PARENT MODE (mandatory)" \
    "  You are the parent orchestrator — NEVER Edit/Write/Bash on project source." \
    "  Read orchestrator-directive.json → spawn ${spawn_label} with templates/orchestrator-workers/<TEMPLATE>.md" \
    "  On worker completion: flow-advance queues next_worker_template + next_skill → spawn next worker." \
    "  Ask the user ONLY for locked decisions (decision_class in outcomes)."
}
