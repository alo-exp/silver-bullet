# shellcheck shell=bash
# Phase 103 intent ledger — nested parent/child tree in session state.
#
# Scope (SB-BUG-C #249): ledger lives under host-global SB_RUNTIME_STATE_DIR but
# is stamped with branch + git worktree toplevel. Session-start wipes it on
# scope change; the Stop gate ignores (clears) mismatched/foreign ledgers.
#
# Resolve (SB-BUG-D #250): leaf done/deferred MUST go through
# sb_instruction_ledger_resolve_item / scripts/resolve-instruction-ledger.sh —
# direct Edit/Write of the ledger file remains blocked by state tamper guards.

sb_instruction_ledger_file() {
  printf '%s/instruction-ledger.json' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_instruction_ledger_clear() {
  local outfile
  outfile="$(sb_instruction_ledger_file)"
  rm -f -- "$outfile" 2>/dev/null || true
}

# Current git branch + worktree toplevel for ledger scope stamps.
# Sets SB_INSTRUCTION_LEDGER_SCOPE_BRANCH / SB_INSTRUCTION_LEDGER_SCOPE_WORKTREE.
sb_instruction_ledger_current_scope() {
  local root="${1:-$PWD}"
  SB_INSTRUCTION_LEDGER_SCOPE_BRANCH=""
  SB_INSTRUCTION_LEDGER_SCOPE_WORKTREE=""
  SB_INSTRUCTION_LEDGER_SCOPE_BRANCH="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ -n "$SB_INSTRUCTION_LEDGER_SCOPE_BRANCH" ]] \
    && ! printf '%s' "$SB_INSTRUCTION_LEDGER_SCOPE_BRANCH" | grep -qE '^[a-zA-Z0-9/_.-]+$'; then
    SB_INSTRUCTION_LEDGER_SCOPE_BRANCH=""
  fi
  if declare -f sb_branch_scope_git_toplevel >/dev/null 2>&1; then
    SB_INSTRUCTION_LEDGER_SCOPE_WORKTREE="$(sb_branch_scope_git_toplevel "$root")"
  else
    SB_INSTRUCTION_LEDGER_SCOPE_WORKTREE="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || true)"
  fi
}

# True when ledger file exists and its stamped scope differs from current git scope.
# Ledgers without a scope stamp (legacy) are treated as matching so same-session
# enforcement still works; session-start wipe covers cross-worktree leftover files.
sb_instruction_ledger_scope_mismatch() {
  local outfile branch worktree lb lw
  outfile="$(sb_instruction_ledger_file)"
  [[ -f "$outfile" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  sb_instruction_ledger_current_scope "${1:-$PWD}"
  branch="${SB_INSTRUCTION_LEDGER_SCOPE_BRANCH:-}"
  worktree="${SB_INSTRUCTION_LEDGER_SCOPE_WORKTREE:-}"
  [[ -n "$branch" ]] || return 1
  lb="$(jq -r '.scope.branch // empty' "$outfile" 2>/dev/null || true)"
  lw="$(jq -r '.scope.worktree // empty' "$outfile" 2>/dev/null || true)"
  # Unscoped legacy ledger: do not treat as mismatch (same-session still valid).
  [[ -n "$lb" || -n "$lw" ]] || return 1
  if [[ -n "$lb" && "$lb" != "$branch" ]]; then
    return 0
  fi
  if [[ -n "$lw" && -n "$worktree" && "$lw" != "$worktree" ]]; then
    return 0
  fi
  return 1
}

# If ledger is foreign to this branch/worktree, clear it so Stop is not deadlocked.
sb_instruction_ledger_drop_if_scope_mismatch() {
  if sb_instruction_ledger_scope_mismatch "${1:-$PWD}"; then
    sb_instruction_ledger_clear
    return 0
  fi
  return 1
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
#
# Fenced code blocks (``` ... ```) are stripped BEFORE bullet extraction. A
# bullet inside a code fence is quoted material — a pasted diff, a log excerpt,
# a shell transcript — never a user instruction. Without this, pasting any
# block that happens to contain list syntax enrolled those lines as pending
# work items. An unterminated fence is treated as fencing the rest of the
# prompt, which is the safe direction: quoted text is skipped, not enrolled.
sb_instruction_ledger_parse_bullets() {
  local prompt="$1"
  command -v jq >/dev/null 2>&1 || return 1
  printf '%s' "$prompt" | jq -Rs '
    split("\n")
    | reduce .[] as $line ({fenced: false, out: []};
        if ($line | test("^[[:space:]]*```")) then
          .fenced = (.fenced | not)
        elif .fenced then
          .
        else
          .out += [$line]
        end)
    | .out
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

# Detect a pasted agent completion report (as opposed to a user request).
#
# Reporting that work is DONE must never manufacture new unresolved items. A
# completion report is largely a summary of finished work — restating it as
# pending ledger children means Stop can never be satisfied, because the very
# act of reporting adds items that no further work will resolve.
#
# Requires at least TWO distinct corroborating markers. A genuine user request
# can incidentally contain any one of these (someone may legitimately ask
# "run git status --porcelain and fix what you find"), so a single hit is not
# enough to suppress seeding. Two independent markers is the false-positive
# guard: over-filtering silently disables the ledger, which is worse than an
# occasional spurious item.
sb_prompt_is_agent_report() {
  local prompt="${1:-}"
  local hits=0
  [[ -n "$prompt" ]] || return 1

  # Explicit if-blocks (not `grep && hits=...`): these libs are sourced by
  # hooks running under `set -e` with an ERR trap, where a failing AND-list is
  # needless risk.
  local marker
  for marker in \
    '^[[:space:]]*(Report from|##[[:space:]]*Report)' \
    'git log --oneline|git status --porcelain' \
    'Results:[[:space:]]*[0-9]+[[:space:]]*passed' \
    'exit 0|_EXIT=[0-9]' \
    '[0-9a-f]{7,}\.\.[0-9a-f]{7,}|`[0-9a-f]{7,}`[[:space:]]*→[[:space:]]*`[0-9a-f]{7,}`'
  do
    if printf '%s' "$prompt" | grep -Eq "$marker" 2>/dev/null; then
      hits=$((hits + 1))
    fi
  done

  [[ "$hits" -ge 2 ]]
}

# Seed nested ledger when prompt has >= min_bullets list items (default 3).
sb_instruction_ledger_seed_from_prompt() {
  local prompt="$1"
  local min_bullets="${2:-3}"
  local outfile pid now bullets count existing children_json branch worktree
  outfile="$(sb_instruction_ledger_file)"
  [[ -n "$prompt" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  if declare -f sb_prompt_is_informational_query >/dev/null 2>&1 \
    && sb_prompt_is_informational_query "$prompt"; then
    return 0
  fi

  # A pasted completion report is evidence of work finished, not a new request.
  # Seeding from it would enroll the report's own summary as pending items that
  # nothing can resolve, deadlocking Stop.
  if sb_prompt_is_agent_report "$prompt"; then
    return 0
  fi

  # Drop a foreign (other branch/worktree) ledger before seeding this prompt.
  sb_instruction_ledger_drop_if_scope_mismatch "$PWD" 2>/dev/null || true

  bullets="$(sb_instruction_ledger_parse_bullets "$prompt" 2>/dev/null || echo '[]')"
  count="$(jq 'length' <<<"$bullets" 2>/dev/null || echo 0)"
  [[ "${count:-0}" -ge "$min_bullets" ]] || return 0

  pid="$(sb_instruction_ledger_prompt_id "$prompt")"
  [[ -n "$pid" ]] || return 0

  if [[ -f "$outfile" ]]; then
    existing="$(jq -r '.prompt_id // ""' "$outfile" 2>/dev/null || true)"
    [[ "$existing" == "$pid" ]] && return 0
  fi

  sb_instruction_ledger_current_scope "$PWD"
  branch="${SB_INSTRUCTION_LEDGER_SCOPE_BRANCH:-}"
  worktree="${SB_INSTRUCTION_LEDGER_SCOPE_WORKTREE:-}"

  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  children_json="$(jq -n --argjson labels "$bullets" '
    [$labels[] | {id: (. | @base64 | .[0:8]), label: ., status: "pending", evidence: "", children: []}]
  ' 2>/dev/null || echo '[]')"

  jq -n \
    --arg pid "$pid" \
    --arg at "$now" \
    --arg preview "$(printf '%.200s' "$prompt")" \
    --arg branch "$branch" \
    --arg worktree "$worktree" \
    --argjson children "$children_json" \
    '{
      prompt_id: $pid,
      started_at: $at,
      prompt_preview: $preview,
      scope: {
        branch: $branch,
        worktree: $worktree
      },
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
  # Collect pending nodes into an ARRAY before counting. A bare generator
  # (`def pending_nodes: .. | objects | select(...)`) makes `| length` map over
  # each emitted node instead of counting them, and emits nothing at all when
  # there are zero pending nodes — so `jq -e` exits 4 (no output) exactly when
  # everything IS resolved, blocking Stop forever with an empty item list.
  jq -e '
    [.. | objects | select(has("status")) | select(.status == "pending")] | length == 0
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
        "- [\($node.id // $path)] \($node.label // "item")"
      else empty end;
    "Instruction ledger — unresolved items:",
    (.intents // [] | to_entries[] | walk_pending("intents[\(.key)]"; .value)),
    "",
    "Sanctioned resolve (do NOT Edit instruction-ledger.json — state tamper blocks it):",
    "  bash scripts/resolve-instruction-ledger.sh done <item-id-or-label> --evidence \"…\"",
    "  bash scripts/resolve-instruction-ledger.sh deferred <item-id-or-label> --evidence \"…\"",
    "  bash scripts/resolve-instruction-ledger.sh list"
  ' "$outfile" 2>/dev/null || true
}

# Sanctioned leaf writer: mark a pending leaf done|deferred with evidence.
# Selector matches item id (preferred), exact label, or unique label substring.
# Returns 0 on success, 1 on missing ledger / bad args / no match / ambiguous.
sb_instruction_ledger_resolve_item() {
  local selector="${1:-}"
  local status="${2:-}"
  local evidence="${3:-}"
  local outfile matches tmp
  outfile="$(sb_instruction_ledger_file)"
  [[ -n "$selector" ]] || return 1
  case "$status" in
    done|deferred) ;;
    *) return 1 ;;
  esac
  [[ -n "$evidence" ]] || return 1
  [[ -f "$outfile" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  # Refuse to mutate a foreign-scope ledger; drop it instead.
  if sb_instruction_ledger_scope_mismatch "$PWD" 2>/dev/null; then
    sb_instruction_ledger_clear
    return 1
  fi

  matches="$(jq -r --arg sel "$selector" '
    def leaves:
      .. | objects
      | select(has("status"))
      | select((.children // []) | length == 0);
    [leaves
      | select(
          (.id // "") == $sel
          or (.label // "") == $sel
          or ((.label // "") | contains($sel))
        )
      | .id // empty]
    | unique
  ' "$outfile" 2>/dev/null || echo '[]')"

  if [[ "$(jq 'length' <<<"$matches" 2>/dev/null || echo 0)" != "1" ]]; then
    return 1
  fi

  tmp="$(mktemp "${outfile}.XXXXXX" 2>/dev/null)" || return 1
  if jq --arg sel "$selector" --arg st "$status" --arg ev "$evidence" '
    def update_node:
      if (.children // []) | length > 0 then
        .children |= map(update_node)
      elif (
          (.id // "") == $sel
          or (.label // "") == $sel
          or ((.label // "") | contains($sel))
        ) then
        .status = $st | .evidence = $ev
      else . end;
    .intents |= map(update_node)
  ' "$outfile" >"$tmp" 2>/dev/null; then
    mv -f -- "$tmp" "$outfile" 2>/dev/null || { rm -f -- "$tmp"; return 1; }
  else
    rm -f -- "$tmp"
    return 1
  fi

  sb_instruction_ledger_auto_resolve_parents 2>/dev/null || true
  return 0
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

