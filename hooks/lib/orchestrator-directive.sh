# shellcheck shell=bash
# Orchestrator directive — mechanical next-skill contract (P0/P3/P6).

sb_orchestrator_directive_file() {
  printf '%s/orchestrator-directive.json' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_orchestrator_override_log() {
  local root="${1:-$PWD}"
  printf '%s/.planning/orchestrator-override-log.jsonl' "$root"
}

# Map flow queue tokens to invocable skill names.
sb_orchestrator_flow_to_skill() {
  local flow="$1"
  case "$flow" in
    FLOW-QUALITY-GATE|FLOW-QUALITY-GATE-PRESHIP|QUALITY\ GATE|QUALITYGATE)
      printf 'silver-quality-gates'
      ;;
    FLOW-DEVOPS-QUALITY-GATE-PRESHIP|devops-quality-gates|DEVOPS-QUALITY-GATES)
      printf 'devops-quality-gates'
      ;;
    devops-skill-router|DEVOPS-SKILL-ROUTER)
      printf 'devops-skill-router'
      ;;
    FLOW-DESIGN-HANDOFF|DESIGN-HANDOFF|DESIGN\ HANDOFF)
      printf 'silver-handoff'
      ;;
    FLOW-BOOTSTRAP|BOOTSTRAP)
      printf 'silver-init'
      ;;
    FLOW-ORIENT|ORIENT)
      printf 'silver-context'
      ;;
    FLOW-CLARIFY|CLARIFY)
      printf 'silver-clarify'
      ;;
    FLOW-DECIDE|DECIDE)
      printf 'silver-deep-research'
      ;;
    FLOW-SPECIFY|SPECIFY)
      printf 'silver-spec'
      ;;
    FLOW-PLAN|PLAN)
      printf 'silver-plan'
      ;;
    FLOW-DESIGN-CONTRACT|DESIGN-CONTRACT|DESIGN\ CONTRACT)
      printf 'silver-ui-contract'
      ;;
    FLOW-EXECUTE|EXECUTE)
      printf 'silver-execute'
      ;;
    FLOW-UI-QUALITY|UI-QUALITY|UI\ QUALITY)
      printf 'silver-ui-review'
      ;;
    FLOW-REVIEW|REVIEW)
      printf 'silver-review'
      ;;
    FLOW-REVIEW-REQUEST|REVIEW-REQUEST|REVIEW\ REQUEST)
      printf 'silver-review-request'
      ;;
    FLOW-REVIEW-TRIAGE|REVIEW-TRIAGE|REVIEW\ TRIAGE)
      printf 'silver-review-triage'
      ;;
    FLOW-VERIFY|VERIFY)
      printf 'silver-verify'
      ;;
    FLOW-SECURE|SECURE)
      printf 'security'
      ;;
    FLOW-SHIP|SHIP)
      printf 'silver-ship'
      ;;
    FLOW-DEBUG|DEBUG)
      printf 'silver-debug'
      ;;
    FLOW-DOCUMENT|DOCUMENT)
      printf 'silver-ensure-docs'
      ;;
    FLOW-RELEASE|RELEASE)
      printf 'silver-create-release'
      ;;
    FLOW-BLAST-RADIUS|BLAST-RADIUS|BLAST\ RADIUS)
      printf 'silver-blast-radius'
      ;;
    FLOW-VALIDATE|VALIDATE)
      printf 'silver-validate'
      ;;
    security|SECURITY)
      printf 'security'
      ;;
    silver-*)
      printf '%s' "$flow"
      ;;
    FLOW-*)
      local slug="${flow#FLOW-}"
      slug="$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]')"
      case "$slug" in
        quality-gate|quality-gate-preship) printf 'silver-quality-gates' ;;
        devops-quality-gate-preship) printf 'devops-quality-gates' ;;
        design-handoff) printf 'silver-handoff' ;;
        devops-skill-router) printf 'devops-skill-router' ;;
        secure) printf 'security' ;;
        *) printf 'silver-%s' "$slug" ;;
      esac
      ;;
    *-*)
      printf 'silver-%s' "$flow"
      ;;
    *)
      printf 'silver-%s' "$(printf '%s' "$flow" | tr '[:upper:]' '[:lower:]')"
      ;;
  esac
}

sb_orchestrator_ensure_worker_template_mapper() {
  declare -f sb_orchestrator_worker_template_for_skill >/dev/null 2>&1 && return 0
  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || lib_dir=""
  if [[ -n "$lib_dir" && -f "$lib_dir/orchestrator-parent.sh" ]]; then
    # shellcheck source=lib/orchestrator-parent.sh
    source "$lib_dir/orchestrator-parent.sh"
  fi
}

sb_orchestrator_directive_write() {
  local next_skill="$1"
  local args="${2:-}"
  local reason="${3:-Orchestrator queued next flow}"
  local blocking="${4:-true}"
  local next_worker_template="${5:-}"
  [[ -n "$next_skill" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  [[ -n "$next_worker_template" ]] || sb_orchestrator_ensure_worker_template_mapper
  if [[ -z "$next_worker_template" ]] && declare -f sb_orchestrator_worker_template_for_skill >/dev/null 2>&1; then
    next_worker_template="$(sb_orchestrator_worker_template_for_skill "$next_skill")"
  fi

  local now file dir json
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  file="$(sb_orchestrator_directive_file)"
  dir="$(dirname "$file")"
  mkdir -p "$dir" 2>/dev/null || true

  json="$(jq -n \
    --arg next_skill "$next_skill" \
    --arg args "$args" \
    --arg reason "$reason" \
    --arg next_worker_template "$next_worker_template" \
    --argjson blocking "$([[ "$blocking" == true || "$blocking" == 1 ]] && echo true || echo false)" \
    --arg updated_at "$now" \
    '{
      next_skill: $next_skill,
      args: $args,
      reason: $reason,
      next_worker_template: (if $next_worker_template != "" then $next_worker_template else null end),
      blocking: $blocking,
      updated_at: $updated_at
    }' 2>/dev/null || true)"
  [[ -n "$json" ]] || return 1
  printf '%s\n' "$json" >"${file}.tmp" 2>/dev/null && mv "${file}.tmp" "$file"
}

# Write directive including scheduler batch_dispatch handoff metadata (parent Task contract).
sb_orchestrator_directive_write_batch() {
  local next_skill="$1"
  local args="${2:-}"
  local reason="${3:-Orchestrator queued next flow}"
  local blocking="${4:-true}"
  local next_worker_template="${5:-}"
  local batch_json="${6:-}"
  [[ -n "$next_skill" && -n "$batch_json" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  [[ -n "$next_worker_template" ]] || sb_orchestrator_ensure_worker_template_mapper
  if [[ -z "$next_worker_template" ]] && declare -f sb_orchestrator_worker_template_for_skill >/dev/null 2>&1; then
    next_worker_template="$(sb_orchestrator_worker_template_for_skill "$next_skill")"
  fi

  local now file dir json batch_parsed
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  file="$(sb_orchestrator_directive_file)"
  dir="$(dirname "$file")"
  mkdir -p "$dir" 2>/dev/null || true
  batch_parsed="$(jq -c . <<<"$batch_json" 2>/dev/null || true)"
  [[ -n "$batch_parsed" ]] || return 1

  json="$(jq -n \
    --arg next_skill "$next_skill" \
    --arg args "$args" \
    --arg reason "$reason" \
    --arg next_worker_template "$next_worker_template" \
    --argjson blocking "$([[ "$blocking" == true || "$blocking" == 1 ]] && echo true || echo false)" \
    --argjson batch_dispatch "$batch_parsed" \
    --arg updated_at "$now" \
    '{
      next_skill: $next_skill,
      args: $args,
      reason: $reason,
      next_worker_template: (if $next_worker_template != "" then $next_worker_template else null end),
      blocking: $blocking,
      batch_dispatch: $batch_dispatch,
      updated_at: $updated_at
    }' 2>/dev/null || true)"
  [[ -n "$json" ]] || return 1
  printf '%s\n' "$json" >"${file}.tmp" 2>/dev/null && mv "${file}.tmp" "$file"
}

sb_orchestrator_directive_clear() {
  local file
  file="$(sb_orchestrator_directive_file)"
  rm -f -- "$file" 2>/dev/null || true
}

sb_orchestrator_directive_read() {
  local file
  file="$(sb_orchestrator_directive_file)"
  [[ -f "$file" ]] || return 1
  cat "$file"
}

sb_orchestrator_directive_next_skill() {
  local file
  file="$(sb_orchestrator_directive_file)"
  [[ -f "$file" ]] || return 1
  jq -r '.next_skill // ""' "$file" 2>/dev/null || true
}

sb_orchestrator_directive_is_blocking() {
  local file
  file="$(sb_orchestrator_directive_file)"
  [[ -f "$file" ]] || return 1
  jq -e '.blocking == true' "$file" >/dev/null 2>&1
}

sb_orchestrator_directive_skill_recorded() {
  local expected="$1"
  local state_contents="$2"
  [[ -n "$expected" && -n "$state_contents" ]] || return 1
  if declare -f sb_required_skill_is_recorded >/dev/null 2>&1; then
    sb_required_skill_is_recorded "$state_contents" "$expected"
    return $?
  fi
  grep -Fqx -- "$expected" <<<"$state_contents" 2>/dev/null
}

sb_orchestrator_directive_context_block() {
  local file block spawn_label
  file="$(sb_orchestrator_directive_file)"
  [[ -f "$file" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  block="$(jq -r '
    if (.next_skill // "") == "" then empty else
      "SB ORCHESTRATOR DIRECTIVE (mandatory next action)\n" +
      "  next_skill: " + .next_skill + "\n" +
      (if (.next_worker_template // "") != "" and .next_worker_template != null then
        "  next_worker_template: " + .next_worker_template + ".md\n"
      else "" end) +
      (if (.batch_dispatch // null) != null then
        "  batch_dispatch: " + (.batch_dispatch.dispatch_mode // "sequential") +
        " batch (" + ((.batch_dispatch.handoffs // []) | length | tostring) + " handoff(s); " +
        ((.batch_dispatch.handoffs // []) | map(select(.join_status != "joined")) | length | tostring) + " pending join)\n"
      else "" end) +
      (if (.args // "") != "" then "  args: " + .args + "\n" else "" end) +
      "  reason: " + (.reason // "queued flow") + "\n" +
      (if .blocking == true then
        "  blocking: true — parent: spawn Task worker with template; worker: invoke /" + .next_skill + " before Edit/Write/Bash. Start a user message with the words SB OVERRIDE, a colon and a reason for an audited bypass."
      else
        "  blocking: false — recommended next skill."
      end)
    end
  ' "$file" 2>/dev/null || true)"
  [[ -n "$block" ]] || return 0
  if declare -f sb_orchestrator_spawn_tool_label >/dev/null 2>&1; then
    spawn_label="$(sb_orchestrator_spawn_tool_label)"
    block="${block//spawn Task worker/spawn ${spawn_label}}"
  fi
  printf '%s\n' "$block"
}

# sha256 of stdin as hex (GNU, BSD/macOS and OpenSSL fallbacks). Status 1 when none exists.
sb_orchestrator_sha256() {
  local out
  if command -v sha256sum >/dev/null 2>&1; then
    out="$(sha256sum 2>/dev/null)" || return 1
  elif command -v shasum >/dev/null 2>&1; then
    out="$(shasum -a 256 2>/dev/null)" || return 1
  elif command -v openssl >/dev/null 2>&1; then
    out="$(openssl dgst -sha256 -r 2>/dev/null)" || return 1
  else
    return 1
  fi
  printf '%s' "${out%% *}"
}

# sb_orchestrator_log_override REPO_ROOT REASON [SKILL] [PROVENANCE_JSON]
# Append one audited override record. Fail closed (status 1, nothing cleared by the caller) when
# the record cannot be written: no project root, no jq, a symlinked .planning/ or log (R4-14), an
# unwritable log, or no sha256 tool. Each line carries the caller's provenance (session_id, host,
# hook event, transcript path, prompt hash) and `prev`, the sha256 of the previous line, so a line
# removed or edited afterwards breaks the chain. The record is mirrored into the runtime state dir.
sb_orchestrator_log_override() {
  local repo_root="${1:-}" reason="${2:-}" skill="${3:-}" prov="${4:-}"
  [[ -n "$prov" ]] || prov='{}'
  [[ -n "$repo_root" && -d "$repo_root" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  local logfile now prev line
  logfile="$(sb_orchestrator_override_log "$repo_root")"
  [[ ! -L "$repo_root/.planning" && ! -L "$logfile" ]] || return 1
  mkdir -p "$repo_root/.planning" 2>/dev/null || return 1
  prev="genesis"
  if [[ -s "$logfile" ]]; then
    prev="$(tail -n 1 "$logfile" 2>/dev/null | sb_orchestrator_sha256)" || return 1
  fi
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  line="$(jq -nc \
    --arg at "$now" \
    --arg reason "$reason" \
    --arg skill "$skill" \
    --arg prev "$prev" \
    --argjson prov "$prov" \
    '{at:$at, kind:"directive-override", reason:$reason, expected_skill:$skill, prev:$prev} + $prov' 2>/dev/null)" || return 1
  printf '%s\n' "$line" >>"$logfile" 2>/dev/null || return 1
  if [[ -n "${SB_RUNTIME_STATE_DIR:-}" && -d "$SB_RUNTIME_STATE_DIR" && ! -L "$SB_RUNTIME_STATE_DIR/orchestrator-override-log.jsonl" ]]; then
    printf '%s\n' "$line" >>"$SB_RUNTIME_STATE_DIR/orchestrator-override-log.jsonl" 2>/dev/null || true
  fi
  return 0
}

# SB OVERRIDE is the user's own words (R4-12): the FIRST non-blank line of the message must be
# `SB OVERRIDE: <reason>`, upper case, with a real reason on that line (8+ characters, not a
# `<placeholder>`). A mention later in the text, inside a quoted/pasted block, in lower case or
# with no reason (the guard's own denial text says `SB OVERRIDE: <reason>`) is not an override.
sb_orchestrator_extract_override_reason() {
  local prompt="${1:-}" first reason
  first="$(printf '%s\n' "$prompt" | awk 'NF { print; exit }')"
  local marker_re='^[[:space:]]*SB OVERRIDE:[[:space:]]*(.*)$'
  [[ "$first" =~ $marker_re ]] || return 0
  reason="${BASH_REMATCH[1]}"
  reason="${reason%"${reason##*[![:space:]]}"}"
  [[ ${#reason} -ge 8 ]] || return 0
  [[ "$reason" == "<"*">" ]] && return 0
  printf '%s' "$reason"
}

sb_orchestrator_prompt_has_override() {
  [[ -n "$(sb_orchestrator_extract_override_reason "${1:-}")" ]]
}

# sb_orchestrator_override_apply INPUT_JSON PROMPT REPO_ROOT
# Honour an SB OVERRIDE found in a real UserPromptSubmit payload (R4-07/R4-13/R4-14):
#   - the payload must carry the host's session_id, and a transcript_path that is a regular file
#     when given (a bare synthetic {"prompt": ...} piped in by the agent is refused);
#   - the audit record (with provenance) must be written before anything is cleared;
#   - it then clears the pending directive AND abandons the flow queue, so the parent Stop gate
#     no longer holds the session. It does NOT lift parent-mode tool restrictions or other
#     PreToolUse gates (docs/ORCHESTRATOR.md).
# Status 0 honoured; 1 not an override; 2 override refused (SB_OVERRIDE_REFUSAL says why).
sb_orchestrator_override_apply() {
  local input="${1:-}" prompt="${2:-}" repo_root="${3:-}" reason sid transcript host prov phash
  SB_OVERRIDE_REFUSAL=""
  reason="$(sb_orchestrator_extract_override_reason "$prompt")"
  [[ -n "$reason" ]] || return 1
  sid="$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null || true)"
  transcript="$(printf '%s' "$input" | jq -r '.transcript_path // ""' 2>/dev/null || true)"
  if [[ -z "$sid" ]]; then
    SB_OVERRIDE_REFUSAL="the prompt payload has no host session_id, so it cannot be verified as your own message"
    return 2
  fi
  if [[ -n "$transcript" && ! -f "$transcript" ]]; then
    SB_OVERRIDE_REFUSAL="the payload's transcript_path is not a readable file"
    return 2
  fi
  host="${SB_RUNTIME_NAME:-${SILVER_BULLET_RUNTIME:-unknown}}"
  phash="$(printf '%s' "$prompt" | sb_orchestrator_sha256)" || phash=""
  prov="$(jq -nc --arg sid "$sid" --arg host "$host" --arg tp "$transcript" --arg ph "$phash" \
    '{session_id:$sid, host:$host, hook_event:"UserPromptSubmit", transcript_path:$tp, prompt_sha256:$ph}' 2>/dev/null)" || prov='{}'
  if ! sb_orchestrator_log_override "$repo_root" "$reason" "$(sb_orchestrator_directive_next_skill 2>/dev/null || true)" "$prov"; then
    SB_OVERRIDE_REFUSAL="the audit record could not be written to .planning/orchestrator-override-log.jsonl"
    return 2
  fi
  sb_orchestrator_directive_clear
  if declare -f sb_orchestrator_clear_queue >/dev/null 2>&1; then
    sb_orchestrator_clear_queue
  fi
  return 0
}

# Write directive from orchestrator.json current_flow when present.
sb_orchestrator_sync_directive_from_state() {
  local orch_file reason skill args
  orch_file="$(sb_orchestrator_state_file 2>/dev/null || printf '%s/orchestrator.json' "${SB_RUNTIME_STATE_DIR:-/tmp}")"
  [[ -f "$orch_file" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  skill="$(jq -r '.current_flow // ""' "$orch_file" 2>/dev/null || true)"
  [[ -n "$skill" && "$skill" != "null" ]] || return 0

  skill="$(sb_orchestrator_flow_to_skill "$skill")"
  args="$(jq -r '.active_intent // ""' "$orch_file" 2>/dev/null | head -c 200 || true)"
  reason="Orchestrator queue — complete ${skill} before other tools"
  sb_orchestrator_directive_write "$skill" "$args" "$reason" true
}

# Map first pending outcome id to a skill directive.
sb_orchestrator_directive_from_pending_outcome() {
  local outfile
  outfile="$(sb_outcomes_session_file 2>/dev/null || printf '%s/outcomes-session.json' "${SB_RUNTIME_STATE_DIR:-/tmp}")"
  [[ -f "$outfile" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  local oid skill reason
  oid="$(jq -r '[.outcomes[] | select(.status != "done")][0].id // ""' "$outfile" 2>/dev/null || true)"
  case "$oid" in
    route) skill="silver"; reason="Per-prompt outcome: route via /sb" ;;
    scope) skill="silver-context"; reason="Per-prompt outcome: define scope via sb:context" ;;
    verify) skill="silver-verify"; reason="Per-prompt outcome: run verification before completion" ;;
    *) return 0 ;;
  esac
  sb_orchestrator_directive_write "$skill" "" "$reason" true
}

# Standalone on-demand delegation bootstrap (outside composer flow_queue).
sb_orchestrator_seed_delegation_directive() {
  local host="$1" task_id="$2" brief_path="$3" ownership_scope_json="${4:-[]}"
  [[ "$host" == "codex" || "$host" == "cursor" || "$host" == "claude" || "$host" == "opencode" || "$host" == "pi" ]] || return 1
  [[ -n "$task_id" && -n "$brief_path" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  local skill args_json reason
  skill="silver-agent-${host}"
  args_json="$(jq -n \
    --arg atomic_flow_id "AF-AGENT-DELEGATE" \
    --arg host "$host" \
    --arg task_id "$task_id" \
    --arg brief_path "$brief_path" \
    --argjson ownership_scope "$ownership_scope_json" \
    '{atomic_flow_id:$atomic_flow_id,host:$host,task_id:$task_id,brief_path:$brief_path,ownership_scope:$ownership_scope}')"
  reason="Delegation AF — spawn AGENT-DELEGATE worker for ${host}"

  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "${lib_dir}/agent-delegation-state.sh" ]]; then
    # shellcheck source=lib/agent-delegation-state.sh
    source "${lib_dir}/agent-delegation-state.sh"
    if declare -f sb_agent_delegation_activate >/dev/null 2>&1; then
      sb_agent_delegation_activate "$host" "$task_id" "$(dirname "$brief_path")" "$ownership_scope_json" ""
    fi
  fi

  sb_orchestrator_directive_write "$skill" "$args_json" "$reason" true "AGENT-DELEGATE"
}
