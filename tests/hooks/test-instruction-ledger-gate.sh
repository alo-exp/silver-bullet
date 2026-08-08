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

bash -n "$HOOK" && check "gate shell syntax" pass || check "gate shell syntax" fail
bash -n "${REPO_ROOT}/hooks/lib/instruction-ledger.sh" \
  && check "ledger lib shell syntax" pass || check "ledger lib shell syntax" fail

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
