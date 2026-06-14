# shellcheck shell=bash
# Per-prompt outcome checklist — session state under ${SB_RUNTIME_STATE_DIR}/outcomes-session.json

sb_outcomes_session_file() {
  printf '%s/outcomes-session.json' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_outcomes_prompt_id() {
  local prompt="$1"
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$prompt" | shasum -a 256 2>/dev/null | awk '{print substr($1,1,12)}'
  else
    printf '%s' "$prompt" | cksum 2>/dev/null | awk '{print $1}'
  fi
}

# Seed default outcomes for a user prompt (idempotent per prompt_id).
sb_outcomes_seed_for_prompt() {
  local prompt="$1"
  local outfile
  local pid now existing
  outfile="$(sb_outcomes_session_file)"
  pid="$(sb_outcomes_prompt_id "$prompt")"
  [[ -n "$pid" ]] || return 0

  if [[ -f "$outfile" ]] && command -v jq >/dev/null 2>&1; then
    existing=$(jq -r '.prompt_id // ""' "$outfile" 2>/dev/null || true)
    [[ "$existing" == "$pid" ]] && return 0
  fi

  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  if command -v jq >/dev/null 2>&1; then
    jq -n \
      --arg pid "$pid" \
      --arg at "$now" \
      --arg preview "$(printf '%.120s' "$prompt")" \
      '{
        prompt_id: $pid,
        started_at: $at,
        prompt_preview: $preview,
        outcomes: [
          {id:"route", label:"Route via /silver or approved workflow composer", status:"pending", evidence:"", decision_class:"autonomous_default"},
          {id:"scope", label:"Define concrete deliverables for this prompt", status:"pending", evidence:"", decision_class:"autonomous_default"},
          {id:"verify", label:"Run verification before claiming completion", status:"pending", evidence:"", decision_class:"autonomous_default"}
        ]
      }' >"$outfile" 2>/dev/null || true
  fi
}

# Auto-evaluate outcomes from session evidence; returns non-zero when block required.
sb_outcomes_auto_evaluate() {
  local state_contents="$1"
  local trivial_file="$2"
  local outfile
  outfile="$(sb_outcomes_session_file)"

  [[ -f "$trivial_file" && ! -L "$trivial_file" ]] && return 0
  [[ -z "$state_contents" ]] && return 0
  [[ -f "$outfile" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  # route: any skill recorded
  if [[ -n "$state_contents" ]]; then
    jq '(.outcomes[] | select(.id=="route") | .status) = "done"
        | (.outcomes[] | select(.id=="route") | .evidence) = "skill state non-empty"' \
      "$outfile" >"${outfile}.tmp" 2>/dev/null && mv "${outfile}.tmp" "$outfile"
  fi

  # verify: verify-tests marker or silver-verify recorded
  if printf '%s\n' "$state_contents" | grep -Fqx 'verify-tests' 2>/dev/null \
     || printf '%s\n' "$state_contents" | grep -Fqx 'silver-verify' 2>/dev/null; then
    jq '(.outcomes[] | select(.id=="verify") | .status) = "done"
        | (.outcomes[] | select(.id=="verify") | .evidence) = "verification skill or verify-tests recorded"' \
      "$outfile" >"${outfile}.tmp" 2>/dev/null && mv "${outfile}.tmp" "$outfile"
  fi

  # scope: active workflow file or PLAN.md touched this session (proxy: workflow dir)
  if [[ -d ".planning/workflows" ]]; then
  shopt -s nullglob
    if [[ $(find .planning/workflows -maxdepth 1 -name '*.md' -print 2>/dev/null | wc -l | tr -d ' ') -gt 0 ]]; then
      jq '(.outcomes[] | select(.id=="scope") | .status) = "done"
          | (.outcomes[] | select(.id=="scope") | .evidence) = "active composed workflow tracker"' \
        "$outfile" >"${outfile}.tmp" 2>/dev/null && mv "${outfile}.tmp" "$outfile"
    fi
  shopt -u nullglob
  fi
}

sb_outcomes_pending_summary() {
  local outfile
  outfile="$(sb_outcomes_session_file)"
  [[ -f "$outfile" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  jq -r '
    [.outcomes[] | select(.status != "done")]
    | if length == 0 then empty else
        "Outstanding per-prompt outcomes:\n" +
        (map("  - " + .label + (if .evidence != "" then " (" + .evidence + ")" else "" end)) | join("\n"))
      end
  ' "$outfile" 2>/dev/null || true
}

# Returns 0 if all outcomes done, 1 if block needed.
sb_outcomes_all_done() {
  local outfile
  outfile="$(sb_outcomes_session_file)"
  [[ -f "$outfile" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  local pending
  pending=$(jq '[.outcomes[] | select(.status != "done")] | length' "$outfile" 2>/dev/null || echo 0)
  [[ "${pending:-0}" -eq 0 ]]
}
