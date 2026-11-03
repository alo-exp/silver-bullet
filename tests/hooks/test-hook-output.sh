#!/usr/bin/env bash
# hooks/lib/hook-output.sh (R3-21, R2-01): every emitter prints exactly one JSON document
# made only of fields the host protocol defines, for any string.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
LIB="$TL_REPO_ROOT/hooks/lib/hook-output.sh"
# shellcheck source=../../hooks/lib/hook-output.sh
source "$LIB"
NOJQ="$(tl_path_without jq)"
NOJQPY="$(tl_path_without jq python3)"

# check <name> <json> [python expression over d]: exactly one document, documented fields only.
CHECK_PY="$TL_TMP/check.py"
cat >"$CHECK_PY" <<'PY'
import json, sys
text = sys.stdin.buffer.read().decode("utf-8")
doc, end = json.JSONDecoder().raw_decode(text)
assert text[end:].strip() == "", "more than one JSON document"
top = {"systemMessage", "decision", "reason", "hookSpecificOutput", "continue", "stopReason", "suppressOutput"}
assert set(doc) <= top, f"undocumented top-level field(s): {sorted(set(doc) - top)}"
hso = doc.get("hookSpecificOutput")
if hso is not None:
    assert "hookEventName" in hso, "hookSpecificOutput without hookEventName"
    allowed = {"hookEventName", "additionalContext", "permissionDecision", "permissionDecisionReason"}
    assert set(hso) <= allowed, f"undocumented hookSpecificOutput field(s): {sorted(set(hso) - allowed)}"
    assert hso.get("permissionDecision") in (None, "deny", "ask"), "SB must never emit permissionDecision allow"
if len(sys.argv) > 1:
    d = doc
    assert eval(sys.argv[1]), f"expectation failed: {sys.argv[1]} on {doc!r}"
PY
check() { # name json [expectation]
  local err
  if err="$(printf '%s' "$2" | python3 "$CHECK_PY" "${3:-True}" 2>&1)"; then tl_pass "$1"; else tl_fail "$1 ($(tail -1 <<<"$err"); output: ${2:0:200})"; fi
}

# ---- notices: systemMessage ----------------------------------------------------
check "message: systemMessage only" "$(sb_emit_hook_message PostToolUse 'hello')" 'd == {"systemMessage": "hello"}'
if sb_emit_hook_message PostToolUse "" >/dev/null; then tl_fail "message: empty rejected"; else tl_pass "message: empty rejected"; fi
check "message: event does not change the shape" "$(sb_emit_hook_message Stop 'x')" 'd == {"systemMessage": "x"}'

# Arbitrary strings round-trip through every encoder.
NASTY=$'quote " backslash \\ tab \t newline \n cr \r ctl \x01\x1f bell \x07 emoji ✅ end\\'
long="$(head -c 300000 /dev/zero | tr '\0' 'x')"
LONG_FILE="$TL_TMP/long.txt"
printf '%s' "$long" >"$LONG_FILE"
EXPECT_PY="$TL_TMP/expect.txt"
printf '%s' "$NASTY" >"$EXPECT_PY"
same_as_nasty="d['systemMessage'] == open('$EXPECT_PY', encoding='utf-8', newline='').read()"
check "message via jq: nasty string round-trips" "$(sb_emit_hook_message PostToolUse "$NASTY")" "$same_as_nasty"
check "message via python3: nasty string round-trips" "$(PATH="$NOJQ" bash -c 'source "$1"; sb_emit_hook_message PostToolUse "$2"' _ "$LIB" "$NASTY")" "$same_as_nasty"
check "message via bash: nasty string round-trips" "$(PATH="$NOJQPY" bash -c 'source "$1"; sb_emit_hook_message PostToolUse "$2"' _ "$LIB" "$NASTY")" "$same_as_nasty"
# Bash <= 4.2 (macOS /bin/bash 3.2) keeps the quotes of a double-quoted replacement string;
# the last-resort encoder must not depend on that (emulated with BASH_COMPAT).
for compat in 32 42; do
  check "message via bash under BASH_COMPAT=$compat: nasty string round-trips" "$(PATH="$NOJQPY" BASH_COMPAT=$compat bash -c 'source "$1"; sb_emit_hook_message PostToolUse "$2"' _ "$LIB" "$NASTY")" "$same_as_nasty"
  check "decision via bash under BASH_COMPAT=$compat" "$(PATH="$NOJQPY" BASH_COMPAT=$compat bash -c 'source "$1"; sb_emit_hook_decision PreToolUse deny "$2" "$2"' _ "$LIB" "$NASTY")" "d['hookSpecificOutput']['permissionDecisionReason'].startswith(open('$EXPECT_PY', encoding='utf-8', newline='').read())"
done
check "message: very long value" "$(sb_emit_hook_message PostToolUse "$long")" "len(d['systemMessage']) == 300000"
check "message via python3: very long value" "$(PATH="$NOJQ" bash -c 'source "$1"; sb_emit_hook_message PostToolUse "$(cat "$2")"' _ "$LIB" "$LONG_FILE")" "len(d['systemMessage']) == 300000"
bad=$'bad \xff\xfe utf8'
check "message via jq: invalid UTF-8 replaced" "$(sb_emit_hook_message PostToolUse "$bad")" "d['systemMessage'] == 'bad �� utf8'"
check "message via python3: invalid UTF-8 replaced" "$(PATH="$NOJQ" bash -c 'source "$1"; sb_emit_hook_message PostToolUse "$2"' _ "$LIB" "$bad")" "d['systemMessage'] == 'bad �� utf8'"
tl_stub jq 'exit 3'
check "failing jq falls back to python3" "$(sb_emit_hook_message PostToolUse 'a"b')" "d == {'systemMessage': 'a\"b'}"
rm -f "$TL_BIN/jq"
tl_stub python3 'exit 1'
out="$(PATH="$TL_BIN:$NOJQ" bash -c 'source "$1"; sb_emit_hook_message PostToolUse "$2"' _ "$LIB" "$NASTY")"
rm -f "$TL_BIN/python3"
check "failing python3 falls back to the Bash encoder" "$out" "$same_as_nasty"

# ---- message_json --------------------------------------------------------------
check "message_json: encoded string passes through" "$(sb_emit_hook_message_json Stop '"m\n2"')" "d == {'systemMessage': 'm\n2'}"
check "message_json: two strings are literal text" "$(sb_emit_hook_message_json Stop '"a" "b"')" "d == {'systemMessage': '\"a\" \"b\"'}"
check "message_json: non-string JSON is literal text" "$(sb_emit_hook_message_json Stop '{"x":1}')" "d == {'systemMessage': '{\"x\":1}'}"
check "message_json: broken JSON is literal text" "$(sb_emit_hook_message_json Stop '"open')" "d == {'systemMessage': '\"open'}"
check "message_json via python3" "$(PATH="$NOJQ" bash -c 'source "$1"; sb_emit_hook_message_json Stop "\"raw\""' _ "$LIB")" "d == {'systemMessage': 'raw'}"
check "message_json without jq or python3: literal text" "$(PATH="$NOJQPY" bash -c 'source "$1"; sb_emit_hook_message_json Stop "\"raw\""' _ "$LIB")" "d == {'systemMessage': '\"raw\"'}"
if sb_emit_hook_message_json Stop "" >/dev/null; then tl_fail "message_json: empty rejected"; else tl_pass "message_json: empty rejected"; fi

# ---- context: additionalContext ------------------------------------------------
check "context: PostToolUse" "$(sb_emit_hook_context PostToolUse 'ctx')" "d == {'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': 'ctx'}}"
check "context: SessionStart" "$(sb_emit_hook_context SessionStart $'two\nlines')" "d['hookSpecificOutput'] == {'hookEventName': 'SessionStart', 'additionalContext': 'two\nlines'}"
check "context: default event" "$(sb_emit_hook_context '' 'c')" "d['hookSpecificOutput']['hookEventName'] == 'PostToolUse'"
check "context: Stop has no context field" "$(sb_emit_hook_context Stop 'c')" "d == {'systemMessage': 'c'}"
check "context: SubagentStop has no context field" "$(sb_emit_hook_context SubagentStop 'c')" "d == {'systemMessage': 'c'}"
if sb_emit_hook_context PostToolUse "" >/dev/null; then tl_fail "context: empty rejected"; else tl_pass "context: empty rejected"; fi

# ---- decision + advisory context in ONE document (R2-01) --------------------------
check "decision: PreToolUse deny folds advisories into the reason" \
  "$(sb_emit_hook_decision PreToolUse deny 'HARD STOP' 'advisory one')" \
  "d == {'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': 'deny', 'permissionDecisionReason': 'HARD STOP\n\nadvisory one'}}"
check "decision: PreToolUse block means deny" "$(sb_emit_hook_decision PreToolUse block 'r')" "d['hookSpecificOutput']['permissionDecision'] == 'deny'"
check "decision: unknown decision fails closed" "$(sb_emit_hook_decision PreToolUse Deny 'r')" "d['hookSpecificOutput']['permissionDecision'] == 'deny'"
check "decision: deny without a reason gets a default" "$(sb_emit_hook_decision PreToolUse deny '')" "'Silver Bullet blocked' in d['hookSpecificOutput']['permissionDecisionReason']"
check "decision: PreToolUse ask keeps context separate" "$(sb_emit_hook_decision PreToolUse ask 'confirm?' 'ctx')" \
  "d['hookSpecificOutput'] == {'hookEventName': 'PreToolUse', 'permissionDecision': 'ask', 'permissionDecisionReason': 'confirm?', 'additionalContext': 'ctx'}"
check "decision: advisory only (no decision)" "$(sb_emit_hook_decision PreToolUse '' '' 'note')" \
  "d == {'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'additionalContext': 'note'}}"
check "decision: allow is never emitted" "$(sb_emit_hook_decision PreToolUse allow 'ok' 'note')" "'permissionDecision' not in d['hookSpecificOutput']"
assert_eq "decision: nothing to say prints nothing" "" "$(sb_emit_hook_decision PreToolUse none '' '')"
check "decision: Stop block appends context to the reason" "$(sb_emit_hook_decision Stop block 'missing skills' 'warning')" \
  "d == {'decision': 'block', 'reason': 'missing skills\n\nwarning'}"
check "decision: SubagentStop block" "$(sb_emit_hook_decision SubagentStop deny 'r')" "d == {'decision': 'block', 'reason': 'r'}"
check "decision: Stop without block shows context and notice" "$(sb_emit_hook_decision Stop '' '' 'ctx' 'note')" "d == {'systemMessage': 'ctx\n\nnote'}"
check "decision: Stop ask fails closed to block" "$(sb_emit_hook_decision Stop ask 'r')" "d['decision'] == 'block'"
check "decision: PostToolUse block with context" "$(sb_emit_hook_decision PostToolUse block 'r' 'ctx')" \
  "d == {'decision': 'block', 'reason': 'r', 'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': 'ctx'}}"
check "decision: UserPromptSubmit context only" "$(sb_emit_hook_decision UserPromptSubmit '' '' 'ctx')" \
  "d == {'hookSpecificOutput': {'hookEventName': 'UserPromptSubmit', 'additionalContext': 'ctx'}}"
check "decision: SessionStart has no decision field" "$(sb_emit_hook_decision SessionStart block 'r' 'ctx')" \
  "d == {'hookSpecificOutput': {'hookEventName': 'SessionStart', 'additionalContext': 'r\n\nctx'}}"
check "decision: notice rides along as systemMessage" "$(sb_emit_hook_decision PreToolUse deny 'r' '' 'heads up')" \
  "d['systemMessage'] == 'heads up' and d['hookSpecificOutput']['permissionDecision'] == 'deny'"
check "decision: default event is PreToolUse" "$(sb_emit_hook_decision '' deny 'r')" "d['hookSpecificOutput']['hookEventName'] == 'PreToolUse'"
check "decision: odd event names stay valid JSON" "$(sb_emit_hook_decision 'Ev"il' '' '' 'c')" "d['hookSpecificOutput']['hookEventName'] == 'Ev\"il'"
check "decision: nasty strings in every field" "$(sb_emit_hook_decision PostToolUse block "$NASTY" "$NASTY" "$NASTY")" \
  "d['reason'] == d['systemMessage'] == d['hookSpecificOutput']['additionalContext'] == open('$EXPECT_PY', encoding='utf-8', newline='').read()"
check "decision via bash encoder" "$(PATH="$NOJQPY" bash -c 'source "$1"; sb_emit_hook_decision PreToolUse deny "$2" "$2"' _ "$LIB" "$NASTY")" \
  "d['hookSpecificOutput']['permissionDecisionReason'] == open('$EXPECT_PY', encoding='utf-8', newline='').read() + '\n\n' + open('$EXPECT_PY', encoding='utf-8', newline='').read()"

tl_results
