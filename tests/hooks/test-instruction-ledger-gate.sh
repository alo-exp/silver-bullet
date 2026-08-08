#!/usr/bin/env bash
# test-instruction-ledger-gate.sh — nested instruction ledger Stop gate.
#
# Regression coverage for the jq generator/counting defect in
# sb_instruction_ledger_all_resolved(): a bare generator piped to `length`
# emitted no output when zero nodes were pending, so `jq -e` exited 4 and the
# gate reported "not resolved" precisely when everything WAS resolved —
# blocking Stop forever with an empty item list.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="${REPO_ROOT}/hooks/instruction-ledger-gate.sh"
# shellcheck source=hooks/lib/runtime-paths.sh
source "${REPO_ROOT}/hooks/lib/runtime-paths.sh"

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

PASS=0
FAIL=0
TEST_RUN_ID="$$"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
SB_TEST_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/instruction-ledger-${TEST_RUN_ID}"
export SB_RUNTIME_STATE_DIR="$SB_TEST_DIR"
mkdir -p "$SB_TEST_DIR"

# shellcheck source=hooks/lib/instruction-ledger.sh
source "${REPO_ROOT}/hooks/lib/instruction-ledger.sh"

trap 'rm -rf "$SB_TEST_DIR" "${WORK:-}" 2>/dev/null || true' EXIT

check() {
  local desc="$1" result="$2"
  if [[ "$result" == pass ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

WORK=$(mktemp -d)
printf '# Silver Bullet test\n' >"$WORK/silver-bullet.md"
cat >"$WORK/.silver-bullet.json" <<JSON
{"sb_initiated":true,"project":{"name":"test","active_workflow":"full-dev-cycle"}}
JSON

LEDGER="${SB_TEST_DIR}/instruction-ledger.json"

# Build a ledger whose three leaf children carry the given statuses.
write_ledger() {
  jq -n --arg a "$1" --arg b "$2" --arg c "$3" '{
    prompt_id: "test-prompt",
    started_at: "2026-01-01T00:00:00Z",
    prompt_preview: "three item request",
    intents: [{
      id: "root", label: "User multi-item request", status: "pending", evidence: "",
      children: [
        {id: "i1", label: "audit the hooks",  status: $a, evidence: "e1", children: []},
        {id: "i2", label: "fix the bug",      status: $b, evidence: "e2", children: []},
        {id: "i3", label: "add tests",        status: $c, evidence: "e3", children: []}
      ]
    }]
  }' >"$LEDGER"
}

run_stop() {
  rm -f "${SB_TEST_DIR}/trivial" "${SB_TEST_DIR}/stop-coalesce-block" 2>/dev/null || true
  ( cd "$WORK" && printf '%s' '{"hook_event_name":"Stop"}' \
      | SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" \
        bash "$HOOK" 2>/dev/null ) || true
}

blocks() {
  printf '%s' "$1" | grep -q '"decision":"block"'
}

echo "--- instruction-ledger-gate ---"

# ── Library-level: all_resolved must be a COUNT, not a generator map ─────────
# The gate always runs auto_resolve_parents first (it rolls a parent up to
# "done" once every child is resolved), so mirror that ordering here.
write_ledger done done done
sb_instruction_ledger_auto_resolve_parents
if sb_instruction_ledger_all_resolved; then
  check "all_resolved returns 0 when zero nodes are pending" pass
else
  check "all_resolved returns 0 when zero nodes are pending" fail
fi

write_ledger done deferred done
sb_instruction_ledger_auto_resolve_parents
if sb_instruction_ledger_all_resolved; then
  check "all_resolved treats deferred as resolved" pass
else
  check "all_resolved treats deferred as resolved" fail
fi

write_ledger done pending done
sb_instruction_ledger_auto_resolve_parents
if sb_instruction_ledger_all_resolved; then
  check "all_resolved returns non-zero when one node is pending" fail
else
  check "all_resolved returns non-zero when one node is pending" pass
fi

# ── Gate-level: Stop must NOT block once every item is resolved ──────────────
write_ledger done done done
out=$(run_stop)
if blocks "$out"; then
  check "Stop is allowed when all ledger items are done" fail
else
  check "Stop is allowed when all ledger items are done" pass
fi

write_ledger done deferred deferred
out=$(run_stop)
if blocks "$out"; then
  check "Stop is allowed when items are done/deferred" fail
else
  check "Stop is allowed when items are done/deferred" pass
fi

# ── Gate-level: Stop MUST still block on a genuinely pending item ────────────
write_ledger done pending done
out=$(run_stop)
if blocks "$out"; then
  check "Stop blocks when one ledger item is pending" pass
else
  check "Stop blocks when one ledger item is pending" fail
fi
if printf '%s' "$out" | grep -q 'fix the bug'; then
  check "block reason names the pending item" pass
else
  check "block reason names the pending item" fail
fi

# ── No ledger at all → gate is inert ─────────────────────────────────────────
rm -f "$LEDGER"
out=$(run_stop)
if blocks "$out"; then
  check "Stop is allowed when no ledger exists" fail
else
  check "Stop is allowed when no ledger exists" pass
fi

# ── Seeding: code fences and agent reports must not enroll work items ────────
# Regression coverage for ledger self-enrollment: pasting an agent completion
# report enrolled the report's own summary bullets as new pending items, so
# Stop could never be satisfied. Fenced blocks are quoted material, and a
# completion report is evidence of work finished — neither is a user request.

seeded_labels() {
  [[ -f "$LEDGER" ]] || return 1
  jq -r '[.. | objects | select(has("label")) | .label] | join("|")' "$LEDGER" 2>/dev/null
}

# A genuine 3-bullet request MUST still seed. This assertion guards against
# over-filtering: silently disabling the ledger is worse than a spurious item.
rm -f "$LEDGER"
sb_instruction_ledger_seed_from_prompt 'Please do the following work:
- refactor the parser module
- add a regression test for the fence case
- update the changelog'
if [[ -f "$LEDGER" ]] && seeded_labels | grep -q 'refactor the parser module'; then
  check "genuine 3-bullet user request still seeds the ledger" pass
else
  check "genuine 3-bullet user request still seeds the ledger" fail
fi

# Bullets inside a fenced code block are NOT instructions.
rm -f "$LEDGER"
sb_instruction_ledger_seed_from_prompt 'Here is the config I am using:
```yaml
- alpha step
- beta step
- gamma step
```
Thanks.'
if [[ -f "$LEDGER" ]]; then
  check "bullets inside a code fence are not enrolled" fail
else
  check "bullets inside a code fence are not enrolled" pass
fi

# parse_bullets itself must drop fenced lines but keep real ones.
fence_mixed='- real instruction one
```
- fenced bullet
- another fenced bullet
```
- real instruction two'
if [[ "$(sb_instruction_ledger_bullet_count "$fence_mixed")" == "2" ]]; then
  check "parse_bullets counts only unfenced bullets" pass
else
  check "parse_bullets counts only unfenced bullets" fail
fi

# An unterminated fence must swallow the rest of the prompt (safe direction).
unterminated='- real instruction
```
- fenced one
- fenced two'
if [[ "$(sb_instruction_ledger_bullet_count "$unterminated")" == "1" ]]; then
  check "unterminated fence swallows remaining bullets" pass
else
  check "unterminated fence swallows remaining bullets" fail
fi

# A pasted agent completion report must NOT seed.
AGENT_REPORT='Report from worker agent

- Fixed the ledger parser
- Repaired the leanctx claude arm
- Updated the doctor warning

Verbatim output:
Results: 13 passed, 0 failed
SYNTAX_EXIT=0

git log --oneline -2
8f570b37 fix(hooks): stop gates failing open
`8f570b37` → `9a1b2c3d`'
rm -f "$LEDGER"
sb_instruction_ledger_seed_from_prompt "$AGENT_REPORT"
if [[ -f "$LEDGER" ]]; then
  check "pasted agent report does not seed the ledger" fail
else
  check "pasted agent report does not seed the ledger" pass
fi

if sb_prompt_is_agent_report "$AGENT_REPORT"; then
  check "agent report classifier matches a real report" pass
else
  check "agent report classifier matches a real report" fail
fi

# One marker alone must NOT be enough (false-positive guard).
if sb_prompt_is_agent_report 'Please run git status --porcelain and fix whatever is dirty'; then
  check "single marker does not classify as agent report" fail
else
  check "single marker does not classify as agent report" pass
fi

rm -f "$LEDGER"
bash -n "$HOOK" && check "gate shell syntax" pass || check "gate shell syntax" fail
bash -n "${REPO_ROOT}/hooks/lib/instruction-ledger.sh" \
  && check "ledger lib shell syntax" pass || check "ledger lib shell syntax" fail

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
