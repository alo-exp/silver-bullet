# shellcheck shell=bash
# Phase 103 intent ledger — nested parent/child tree in session state.

sb_instruction_ledger_file() {
  printf '%s/instruction-ledger.json' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_instruction_ledger_prompt_id() {
  local prompt="$1"
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$prompt" | shasum -a 256 2>/dev/null | awk '{print substr($1,1,12)}'
  else
    printf '%s' "$prompt" | cksum 2>/dev/null | awk '{print $1}'
  fi
}

sb_instruction_ledger_jq_update() {
  local outfile="$1"
  local filter="$2"
  local tmp
  [[ -f "$outfile" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  tmp="$(mktemp "${outfile}.XXXXXX" 2>/dev/null)" || return 0
  if jq "$filter" "$outfile" >"$tmp" 2>/dev/null; then
    mv -f -- "$tmp" "$outfile" 2>/dev/null || rm -f -- "$tmp"
  else
    rm -f -- "$tmp"
  fi
}

# Extract bullet lines (markdown -, *, • or numbered) into JSON array via jq.
sb_instruction_ledger_parse_bullets() {
  local prompt="$1"
  command -v jq >/dev/null 2>&1 || return 1
  printf '%s' "$prompt" | jq -Rs '
    split("\n")
    | map(select(length > 0))
    | map(select(test("^[[:space:]]*([-*•]|[0-9]+[.)])[[:space:]]")))
    | map(sub("^[[:space:]]*([-*•]|[0-9]+[.)])[[:space:]]*"; ""))
    | map(select(length > 0))
  ' 2>/dev/null
}

sb_instruction_ledger_bullet_count() {
  local prompt="$1"
  local bullets
  bullets="$(sb_instruction_ledger_parse_bullets "$prompt" 2>/dev/null || echo '[]')"
  jq 'length' <<<"$bullets" 2>/dev/null || echo 0
}

# Seed nested ledger when prompt has >= min_bullets list items (default 3).
sb_instruction_ledger_seed_from_prompt() {
  local prompt="$1"
  local min_bullets="${2:-3}"
  local outfile pid now bullets count existing children_json
  outfile="$(sb_instruction_ledger_file)"
  [[ -n "$prompt" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  if declare -f sb_prompt_is_informational_query >/dev/null 2>&1 \
    && sb_prompt_is_informational_query "$prompt"; then
    return 0
  fi

  bullets="$(sb_instruction_ledger_parse_bullets "$prompt" 2>/dev/null || echo '[]')"
  count="$(jq 'length' <<<"$bullets" 2>/dev/null || echo 0)"
  [[ "${count:-0}" -ge "$min_bullets" ]] || return 0

  pid="$(sb_instruction_ledger_prompt_id "$prompt")"
  [[ -n "$pid" ]] || return 0

  if [[ -f "$outfile" ]]; then
    existing="$(jq -r '.prompt_id // ""' "$outfile" 2>/dev/null || true)"
    [[ "$existing" == "$pid" ]] && return 0
  fi

  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  children_json="$(jq -n --argjson labels "$bullets" '
    [$labels[] | {id: (. | @base64 | .[0:8]), label: ., status: "pending", evidence: "", children: []}]
  ' 2>/dev/null || echo '[]')"

  jq -n \
    --arg pid "$pid" \
    --arg at "$now" \
    --arg preview "$(printf '%.200s' "$prompt")" \
    --argjson children "$children_json" \
    '{
      prompt_id: $pid,
      started_at: $at,
      prompt_preview: $preview,
      intents: [
        {
          id: "root",
          label: "User multi-item request",
          status: "pending",
          evidence: "",
          children: $children
        }
      ]
    }' >"$outfile" 2>/dev/null || true
}

sb_instruction_ledger_all_resolved() {
  local outfile
  outfile="$(sb_instruction_ledger_file)"
  [[ -f "$outfile" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  jq -e '
    def pending_nodes:
      .. | objects | select(has("status")) | select(.status == "pending");
    (pending_nodes | length) == 0
  ' "$outfile" >/dev/null 2>&1
}

sb_instruction_ledger_pending_summary() {
  local outfile
  outfile="$(sb_instruction_ledger_file)"
  [[ -f "$outfile" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  jq -r '
    def walk_pending($path; $node):
      if ($node | type) == "object" and (($node.children // []) | length) > 0 then
        ($node.children | to_entries[] | walk_pending("\($path).children[\(.key)]"; .value))
      elif ($node | type) == "object" and ($node.status // "") == "pending" then
        "- [\($path)] \($node.label // "item")"
      else empty end;
    "Instruction ledger — unresolved items:",
    (.intents // [] | to_entries[] | walk_pending("intents[\(.key)]"; .value)),
    "",
    "Mark each item done with evidence before Stop."
  ' "$outfile" 2>/dev/null || true
}

# Auto-mark root done when all children resolved.
sb_instruction_ledger_auto_resolve_parents() {
  local outfile
  outfile="$(sb_instruction_ledger_file)"
  [[ -f "$outfile" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  sb_instruction_ledger_jq_update "$outfile" '
    def resolve_node:
      if .children and (.children | length) > 0 then
        .children |= map(resolve_node)
        | if (.children | all(.status == "done" or .status == "deferred")) then
            .status = "done" | .evidence = "all children resolved"
          else . end
      else . end;
    .intents |= map(resolve_node)
  '
}
