#!/usr/bin/env bash
# Path coverage for hooks/rfl-quota-retry-due.sh (activation of due quota-retry jobs).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

H=hooks/rfl-quota-retry-due.sh
P="$TL_TMP/proj"
dg_project "$P"
mkdir -p "$P/.planning/rfl-1" "$P/scripts" "$TL_TMP/outside"
echo '{}' >"$P/.planning/rfl-1/quota-retry-schedule.json"

ev() { jq -r '.hookSpecificOutput.hookEventName // ""' <<<"$TL_OUT"; }
ctx() { jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$TL_OUT"; }

# stub resolver: prints argv-derived hook_context
RES="$TL_TMP/resolver.py"
cat >"$RES" <<'PY'
import json, sys
print(json.dumps({"hook_context": "woken:" + " ".join(sys.argv[1:])}))
PY

# --- no-op paths ---------------------------------------------------------
dg_run "$P" "$H" '{}' SB_RFL_QUOTA_RETRY_HOOK=0
assert_eq "disabled by env => noop SessionStart" "SessionStart" "$(ev)"
assert_eq "disabled => no context" "" "$(ctx)"

dg_run_nojq "$P" "$H" '{}' SB_RFL_QUOTA_RETRY_HOOK=0
assert_eq "no jq => printf noop payload" '{"hookSpecificOutput":{"hookEventName":"SessionStart"}}' "$TL_OUT"
dg_run_nojq "$P" "$H" '{}' SB_RFL_HOOK_EVENT=UserPromptSubmit SB_RFL_QUOTA_RETRY_HOOK=0
assert_eq "no jq noop honours event override" '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit"}}' "$TL_OUT"

dg_run_nolib_in "$P" "$H" '{}'
assert_eq "no libs => no project root => noop" "SessionStart" "$(ev)"
dg_run "$TL_TMP/outside" "$H" '{}'
assert_eq "outside project => noop" "" "$(ctx)"
rm -rf "$P/.planning/rfl-1"
dg_run "$P" "$H" '{}'
assert_eq "project without schedules => noop" "" "$(ctx)"
mkdir -p "$P/.planning/rfl-1"; echo '{}' >"$P/.planning/rfl-1/quota-retry-schedule.json"

dg_run "$P" "$H" '{}' SB_RFL_RESOLVER="$TL_TMP/does-not-exist.py"
assert_eq "missing resolver => noop" "" "$(ctx)"

# --- event normalisation ------------------------------------------------
dg_run "$P" "$H" '{"hook_event_name":"UserPromptSubmit"}' SB_RFL_RESOLVER="$RES"
assert_eq "UserPromptSubmit passes through" "UserPromptSubmit" "$(ev)"
dg_run "$P" "$H" '{"hookEventName":"sessionStart"}' SB_RFL_RESOLVER="$RES"
assert_eq "cursor sessionStart maps" "SessionStart" "$(ev)"
dg_run "$P" "$H" '{"hookEventName":"beforeSubmitPrompt"}' SB_RFL_RESOLVER="$RES"
assert_eq "beforeSubmitPrompt maps to UserPromptSubmit" "UserPromptSubmit" "$(ev)"
dg_run "$P" "$H" '{"hook_event_name":"Weird"}' SB_RFL_RESOLVER="$RES"
assert_eq "unknown event defaults to SessionStart" "SessionStart" "$(ev)"
dg_run "$P" "$H" '{"hook_event_name":"SessionStart"}' SB_RFL_RESOLVER="$RES" SB_RFL_HOOK_EVENT=UserPromptSubmit
assert_eq "SB_RFL_HOOK_EVENT overrides payload" "UserPromptSubmit" "$(ev)"
dg_run_closed_stdin "$P" "$H" SB_RFL_RESOLVER="$RES"
assert_eq "unreadable stdin still wakes with default event" "SessionStart" "$(ev)"

# --- activation ---------------------------------------------------------
dg_run "$P" "$H" '{}' SB_RFL_RESOLVER="$RES"
assert_contains "resolver receives wake flags and project root" "$(ctx)" "--quota-retry-wake --project-root $P"
assert_not_contains "no --quota-now without override" "$(ctx)" "--quota-now"
dg_run "$P" "$H" '{}' SB_RFL_RESOLVER="$RES" SB_RFL_QUOTA_NOW=2026-01-01T00:00:00Z
assert_contains "SB_RFL_QUOTA_NOW forwarded" "$(ctx)" "--quota-now 2026-01-01T00:00:00Z"
dg_run "$P" "$H" '{}' SB_RFL_RESOLVER="$RES" SB_RFL_PROJECT_ROOT="$P"
assert_contains "SB_RFL_PROJECT_ROOT honoured from anywhere" "$(ctx)" "--project-root $P"

# resolver discovery: project copy first, then hook-relative repo copy
cat >"$P/scripts/review-fix-ladder.py" <<'PY'
import json
print(json.dumps({"hook_context": "from-project-copy"}))
PY
dg_run "$P" "$H" '{}'
assert_eq "project scripts/review-fix-ladder.py discovered" "from-project-copy" "$(ctx)"
rm -f "$P/scripts/review-fix-ladder.py"
dg_run "$P" "$H" '{}' SB_RFL_QUOTA_NOW=2000-01-01T00:00:00Z
assert_eq "falls back to the bundled resolver (not due => noop)" "" "$(ctx)"
assert_eq "bundled resolver run still emits a hook payload" "SessionStart" "$(ev)"

# resolver output handling
printf 'import sys\n' >"$TL_TMP/silent.py"
dg_run "$P" "$H" '{}' SB_RFL_RESOLVER="$TL_TMP/silent.py"
assert_eq "empty resolver output => noop" "" "$(ctx)"
printf 'print("{\\"other\\": 1}")\n' >"$TL_TMP/noctx.py"
dg_run "$P" "$H" '{}' SB_RFL_RESOLVER="$TL_TMP/noctx.py"
assert_eq "resolver without hook_context => noop" "" "$(ctx)"
printf 'import sys\nsys.exit(3)\n' >"$TL_TMP/fail.py"
dg_run "$P" "$H" '{}' SB_RFL_RESOLVER="$TL_TMP/fail.py"
assert_eq "failing resolver => noop" "" "$(ctx)"

dg_run "$P" "$H" 'not json' SB_RFL_RESOLVER="$RES"
assert_eq "unparsable payload keeps default event" "SessionStart" "$(ev)"
assert_contains "unparsable payload still wakes" "$(ctx)" "woken:"
printf 'print("not json")\n' >"$TL_TMP/badjson.py"
dg_run "$P" "$H" '{}' SB_RFL_RESOLVER="$TL_TMP/badjson.py"
assert_eq "non-JSON resolver output => noop" "" "$(ctx)"
assert_eq "non-JSON resolver output still exits 0" 0 "$TL_STATUS"

# cd into the hook directory failing is tolerated (resolver is then found via the project)
cat >"$P/scripts/review-fix-ladder.py" <<'PY'
import json
print(json.dumps({"hook_context": "project-only"}))
PY
TL_STATUS=0
printf '{}' | (cd "$P" && bash -c 'cd() { [[ "$1" == */hooks ]] && return 1; builtin cd "$@"; }; export -f cd; exec bash "$0"' "$TL_REPO_ROOT/$H") >"$TL_TMP/.out" 2>/dev/null || TL_STATUS=$?
TL_OUT="$(cat "$TL_TMP/.out")"
assert_eq "hook dir unresolvable: project resolver still used" "project-only" "$(ctx)"
rm -f "$P/scripts/review-fix-ladder.py"

# python3 missing
dg_run "$P" "$H" '{}' SB_RFL_RESOLVER="$RES" PATH="$(tl_path_without python3)"
assert_eq "no python3 => noop" "" "$(ctx)"

# unexpected failure routes through the ERR trap into the noop payload
dg_stub_real jq additionalContext
dg_run "$P" "$H" '{}' SB_RFL_RESOLVER="$RES"
assert_eq "ERR trap emits noop payload" "SessionStart" "$(ev)"
assert_eq "ERR trap exits 0" 0 "$TL_STATUS"
rm -f "$TL_BIN/jq"

tl_results
