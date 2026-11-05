# shellcheck shell=bash
# Per-prompt outcome checklist — session state under ${SB_RUNTIME_STATE_DIR}/outcomes-session.json

sb_outcomes_session_file() {
  [[ -n "${SB_RUNTIME_STATE_DIR:-}" ]] || return 1
  printf '%s/outcomes-session%s.json' "$SB_RUNTIME_STATE_DIR" "${SB_SESSION_KEY:+-$SB_SESSION_KEY}"
}

# R2-19: the checklist is derived from recorded skills and plan files, never from what an agent
# writes into the JSON. Every hook write is sealed with a sha256 sidecar; a file whose digest no
# longer matches (or whose sidecar is gone) was changed outside the hooks, so it is reset to
# pending, the tamper is logged, and only hook-observed evidence can complete it again.
sb_outcomes_sha256_of() {
  local out
  if command -v sha256sum >/dev/null 2>&1; then
    out="$(sha256sum -- "$1" 2>/dev/null)" || return 1
  elif command -v shasum >/dev/null 2>&1; then
    out="$(shasum -a 256 -- "$1" 2>/dev/null)" || return 1
  elif command -v openssl >/dev/null 2>&1; then
    out="$(openssl dgst -sha256 -r -- "$1" 2>/dev/null)" || return 1
  else
    return 1
  fi
  printf '%s' "${out%% *}"
}

sb_outcomes_seal() {
  local outfile digest
  outfile="$(sb_outcomes_session_file)" || return 0
  [[ -f "$outfile" ]] || return 0
  digest="$(sb_outcomes_sha256_of "$outfile")" || return 0
  printf '%s\n' "$digest" >"${outfile}.sha256" 2>/dev/null || true
}

# A deleted checklist is tamper, not "never created" (R2-19): the seal or the instruction ledger
# of the same session proves a prompt was seeded. The checklist comes back all pending.
sb_outcomes_restore_deleted() {
  local outfile="$1" ledger
  ledger="${SB_RUNTIME_STATE_DIR}/instruction-ledger${SB_SESSION_KEY:+-$SB_SESSION_KEY}.json"
  [[ -f "${outfile}.sha256" || -f "$ledger" ]] || return 0
  printf '%s\toutcomes-session.json deleted; checklist restored as pending\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"${SB_RUNTIME_STATE_DIR}/outcomes-tamper.log" 2>/dev/null || true
  jq -n --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
    prompt_id: "restored", started_at: $at, prompt_preview: "(checklist deleted outside the hooks)",
    outcomes: [
      {id:"route", label:"Route via /sb or approved workflow composer", status:"pending", evidence:"", decision_class:"autonomous_default"},
      {id:"scope", label:"Define concrete deliverables for this prompt", status:"pending", evidence:"", decision_class:"autonomous_default"},
      {id:"verify", label:"Run verification before claiming completion", status:"pending", evidence:"", decision_class:"autonomous_default"}
    ]}' >"$outfile" 2>/dev/null
  sb_outcomes_seal
}

# Reset an outcomes file that was changed or deleted outside the hooks. No sha256 tool: cannot verify, allow.
sb_outcomes_reject_tampered() {
  local outfile digest stored
  outfile="$(sb_outcomes_session_file)" || return 0
  command -v jq >/dev/null 2>&1 || return 0
  if [[ ! -f "$outfile" ]]; then
    sb_outcomes_restore_deleted "$outfile"
    return 0
  fi
  digest="$(sb_outcomes_sha256_of "$outfile")" || return 0
  stored="$(head -1 "${outfile}.sha256" 2>/dev/null || true)"
  [[ "$stored" == "$digest" ]] && return 0
  printf '%s\toutcomes-session.json changed outside the hooks; checklist reset to pending\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"${SB_RUNTIME_STATE_DIR}/outcomes-tamper.log" 2>/dev/null || true
  sb_outcomes_jq_update "$outfile" '(.outcomes // []) |= map(.status = "pending" | .evidence = "")
    | del(.informational)'
  sb_outcomes_seal
}

# Atomically apply a jq filter to a JSON file (unique mktemp; no fixed .tmp path).
sb_outcomes_jq_update() {
  local outfile="$1"
  local filter="$2"
  local tmp
  [[ -f "$outfile" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  tmp="$(mktemp "${outfile}.XXXXXX" 2>/dev/null)" || return 0
  if jq "$filter" "$outfile" >"$tmp" 2>/dev/null; then
    mv -f -- "$tmp" "$outfile" 2>/dev/null || rm -f -- "$tmp"
    sb_outcomes_seal
  else
    rm -f -- "$tmp"
  fi
}

sb_outcomes_prompt_id() {
  local prompt="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$prompt" | sha256sum 2>/dev/null | awk '{print substr($1,1,12)}'
  elif command -v shasum >/dev/null 2>&1; then
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
    if declare -f sb_prompt_is_informational_query >/dev/null 2>&1 \
      && sb_prompt_is_informational_query "$prompt"; then
      jq -n \
        --arg pid "$pid" \
        --arg at "$now" \
        --arg preview "$(printf '%.120s' "$prompt")" \
        '{
          prompt_id: $pid,
          started_at: $at,
          prompt_preview: $preview,
          informational: true,
          outcomes: [
            {id:"route", label:"Route via /sb or approved workflow composer", status:"done", evidence:"informational query — no routing required", decision_class:"autonomous_default"},
            {id:"scope", label:"Define concrete deliverables for this prompt", status:"done", evidence:"informational query", decision_class:"autonomous_default"},
            {id:"verify", label:"Run verification before claiming completion", status:"done", evidence:"informational query", decision_class:"autonomous_default"}
          ]
        }' >"$outfile" 2>/dev/null || true
      sb_outcomes_seal
      return 0
    fi
    jq -n \
      --arg pid "$pid" \
      --arg at "$now" \
      --arg preview "$(printf '%.120s' "$prompt")" \
      '{
        prompt_id: $pid,
        started_at: $at,
        prompt_preview: $preview,
        outcomes: [
          {id:"route", label:"Route via /sb or approved workflow composer", status:"pending", evidence:"", decision_class:"autonomous_default"},
          {id:"scope", label:"Define concrete deliverables for this prompt", status:"pending", evidence:"", decision_class:"autonomous_default"},
          {id:"verify", label:"Run verification before claiming completion", status:"pending", evidence:"", decision_class:"autonomous_default"}
        ]
      }' >"$outfile" 2>/dev/null || true
    sb_outcomes_seal
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

  # route: composer or router skill recorded (not merely planning-floor skills)
  if grep -qE '^(silver|silver-feature|silver-ui|silver-devops|silver-bugfix|silver-fast|silver-deep-research|silver-release|silver-migrate|silver-init)$' <<<"$state_contents" 2>/dev/null; then
    sb_outcomes_jq_update "$outfile" \
      '(.outcomes[] | select(.id=="route") | .status) = "done"
        | (.outcomes[] | select(.id=="route") | .evidence) = "workflow composer or /sb router recorded"'
  fi

  # verify: verify-tests marker or silver-verify recorded
  if grep -Fqx 'verify-tests' <<<"$state_contents" 2>/dev/null \
     || grep -Fqx 'silver-verify' <<<"$state_contents" 2>/dev/null; then
    sb_outcomes_jq_update "$outfile" \
      '(.outcomes[] | select(.id=="verify") | .status) = "done"
        | (.outcomes[] | select(.id=="verify") | .evidence) = "verification skill or verify-tests recorded"'
  fi

  # scope: active workflow with composer metadata OR PLAN.md with substantive body
  local scope_done=false
  if grep -Fqx 'silver-execute' <<<"$state_contents" 2>/dev/null; then
    scope_done=true
  fi
  if [[ "$scope_done" != true && -d ".planning/workflows" ]]; then
    shopt -s nullglob
    for _wf in .planning/workflows/*.md; do
      [[ -f "$_wf" && ! -L "$_wf" ]] || continue
      if grep -qE '^composer:' "$_wf" 2>/dev/null; then
        scope_done=true
        break
      fi
      _wf_body="$(grep -vE '^#|^$|^\s*$' "$_wf" 2>/dev/null | head -5 | tr -d '[:space:]' || true)"
      if [[ -n "$_wf_body" ]]; then
        scope_done=true
        break
      fi
    done
    shopt -u nullglob
  fi
  if [[ "$scope_done" != true ]]; then
    shopt -s nullglob
    for _plan in .planning/PLAN.md .planning/phases/*/PLAN.md; do
      [[ -f "$_plan" && ! -L "$_plan" ]] || continue
      _plan_body="$(grep -vE '^#|^$|^\s*$|^\|[-: ]+\|' "$_plan" 2>/dev/null | head -10 | tr -d '[:space:]' || true)"
      if [[ -n "$_plan_body" ]] \
         && grep -qiE 'acceptance|task|wave|verification|dependency|deliverable' "$_plan" 2>/dev/null; then
        scope_done=true
        break
      fi
    done
    shopt -u nullglob
  fi
  if [[ "$scope_done" == true ]]; then
    sb_outcomes_jq_update "$outfile" \
      '(.outcomes[] | select(.id=="scope") | .status) = "done"
        | (.outcomes[] | select(.id=="scope") | .evidence) = "composed workflow, PLAN.md, or silver-execute recorded"'
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
  if ! command -v jq >/dev/null 2>&1; then
    # Fail closed when outcomes session exists but jq cannot evaluate completion.
    grep -q '"status"[[:space:]]*:[[:space:]]*"pending"' "$outfile" 2>/dev/null && return 1
    return 0
  fi
  local pending
  pending=$(jq '[.outcomes[] | select(.status != "done")] | length' "$outfile" 2>/dev/null) || return 1
  [[ "${pending:-0}" -eq 0 ]]
}
