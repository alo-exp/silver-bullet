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
    FLOW-DEVOPS-QUALITY-GATE-PRESHIP)
      printf 'devops-quality-gates'
      ;;
    security|SECURITY)
      printf 'security'
      ;;
    silver-*)
      printf '%s' "$flow"
      ;;
    *)
      if [[ "$flow" == *-* ]]; then
        printf 'silver-%s' "$flow"
      else
        printf 'silver-%s' "$(printf '%s' "$flow" | tr '[:upper:]' '[:lower:]')"
      fi
      ;;
  esac
}

sb_orchestrator_directive_write() {
  local next_skill="$1"
  local args="${2:-}"
  local reason="${3:-Orchestrator queued next flow}"
  local blocking="${4:-true}"
  local next_worker_template="${5:-}"
  [[ -n "$next_skill" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1

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
  printf '%s' "$json" >"${file}.tmp" 2>/dev/null && mv "${file}.tmp" "$file"
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
  printf '%s\n' "$state_contents" | grep -Fqx -- "$expected" 2>/dev/null
}

sb_orchestrator_directive_context_block() {
  local file
  file="$(sb_orchestrator_directive_file)"
  [[ -f "$file" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  jq -r '
    if (.next_skill // "") == "" then empty else
      "SB ORCHESTRATOR DIRECTIVE (mandatory next action)\n" +
      "  next_skill: " + .next_skill + "\n" +
      (if (.next_worker_template // "") != "" and .next_worker_template != null then
        "  next_worker_template: " + .next_worker_template + ".md\n"
      else "" end) +
      (if (.args // "") != "" then "  args: " + .args + "\n" else "" end) +
      "  reason: " + (.reason // "queued flow") + "\n" +
      (if .blocking == true then
        "  blocking: true — parent: spawn Task worker with template; worker: invoke /" + .next_skill + " before Edit/Write/Bash. SB OVERRIDE: <reason> for audited bypass."
      else
        "  blocking: false — recommended next skill."
      end)
    end
  ' "$file" 2>/dev/null || true
}

sb_orchestrator_log_override() {
  local repo_root="$1"
  local reason="$2"
  local skill="${3:-}"
  [[ -n "$repo_root" && -d "$repo_root/.planning" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  local logfile now
  logfile="$(sb_orchestrator_override_log "$repo_root")"
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  mkdir -p "$(dirname "$logfile")" 2>/dev/null || true
  jq -nc \
    --arg at "$now" \
    --arg reason "$reason" \
    --arg skill "$skill" \
    '{at:$at, kind:"directive-override", reason:$reason, expected_skill:$skill}' \
    >>"$logfile" 2>/dev/null || true
}

sb_orchestrator_prompt_has_override() {
  local prompt="$1"
  printf '%s' "$prompt" | grep -qiE 'SB[[:space:]]+OVERRIDE:' 
}

sb_orchestrator_extract_override_reason() {
  local prompt="$1"
  printf '%s' "$prompt" | sed -n 's/.*[Ss][Bb][[:space:]]*OVERRIDE:[[:space:]]*//p' | head -1
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
    route) skill="silver"; reason="Per-prompt outcome: route via /silver" ;;
    scope) skill="silver-context"; reason="Per-prompt outcome: define scope via silver:context" ;;
    verify) skill="silver-verify"; reason="Per-prompt outcome: run verification before completion" ;;
    *) return 0 ;;
  esac
  sb_orchestrator_directive_write "$skill" "" "$reason" true
}
