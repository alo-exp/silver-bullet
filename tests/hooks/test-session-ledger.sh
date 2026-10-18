#!/usr/bin/env bash
# shellcheck disable=SC2154
# hooks/lib/session-ledger.sh: session log discovery and the intent ledger blocks.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
unset PROJECT_ROOT_OVERRIDE SILVER_BULLET_SESSION_LOG_PATH_FILE
# shellcheck source=../../hooks/lib/session-ledger.sh
# shellcheck disable=SC2154
source "$TL_REPO_ROOT/hooks/lib/session-ledger.sh"

ec_project
SD="${SB_RUNTIME_STATE_DIR:?}"
LOG="$EC_PROJ/docs/sessions/2026-01-01-00-00-00.md"
mkdir -p "$(dirname "$LOG")"

# ---- project root -----------------------------------------------------------
assert_eq "override root" "/forced/root" "$(PROJECT_ROOT_OVERRIDE=/forced/root sb_session_ledger_project_root)"
assert_eq "root found by walking up" "$EC_PROJ" "$(cd "$EC_PROJ" && sb_session_ledger_project_root)"
mkdir -p "$EC_PROJ/x/y"
assert_eq "root found from a subdirectory" "$EC_PROJ" "$(cd "$EC_PROJ/x/y" && sb_session_ledger_project_root)"
mkdir -p "$TL_TMP/plain"
if (cd "$TL_TMP/plain" && sb_session_ledger_project_root >/dev/null); then tl_fail "no root outside a project"; else tl_pass "no root outside a project"; fi

# ---- log path ---------------------------------------------------------------
assert_eq "default log path file" "$SD/session-log-path" "$(sb_session_ledger_log_path_file)"
assert_eq "log path file override" "/x/y" "$(SILVER_BULLET_SESSION_LOG_PATH_FILE=/x/y sb_session_ledger_log_path_file)"
in_proj() { (cd "$EC_PROJ" && "$@"); }
if in_proj sb_session_ledger_log_path >/dev/null; then tl_fail "no path file: no log path"; else tl_pass "no path file: no log path"; fi
: >"$SD/session-log-path"
if in_proj sb_session_ledger_log_path >/dev/null; then tl_fail "empty path file: no log path"; else tl_pass "empty path file: no log path"; fi
printf 'relative/path.md' >"$SD/session-log-path"
if in_proj sb_session_ledger_log_path >/dev/null; then tl_fail "relative path rejected"; else tl_pass "relative path rejected"; fi
printf '/elsewhere/log.md' >"$SD/session-log-path"
if in_proj sb_session_ledger_log_path >/dev/null; then tl_fail "path outside the project rejected"; else tl_pass "path outside the project rejected"; fi
printf '%s' "$LOG" >"$SD/session-log-path"
assert_eq "valid path" "$LOG" "$(in_proj sb_session_ledger_log_path)"
assert_eq "valid path outside a project (no root to constrain)" "$LOG" "$(cd "$TL_TMP/plain" && sb_session_ledger_log_path)"
rm -f "$SD/session-log-path"
ln -s "$TL_TMP/target" "$SD/session-log-path"
if in_proj sb_session_ledger_log_path >/dev/null; then tl_fail "symlinked path file rejected"; else tl_pass "symlinked path file rejected"; fi
rm -f "$SD/session-log-path"
printf '%s' "$LOG" >"$SD/session-log-path"

# ---- request block ----------------------------------------------------------
block="$(sb_session_ledger_request_block $'first line\nsecond line' silver-plan "" silver-execute)"
assert_match "block header" '^- Request \[[0-9-]+ [0-9:]+Z\]' "$block"
assert_contains "multi-line prompt quoted" "$block" $'  > first line\n  > second line'
assert_contains "skills listed as open tasks" "$block" $'  - [ ] silver-plan\n  - [ ] silver-execute'
assert_not_contains "blank skills skipped" "$block" "- [ ] "$'\n'
assert_contains "empty prompt marker" "$(sb_session_ledger_request_block "")" "  > (empty)"

# ---- append block: placeholder, anchor, plain -------------------------------
printf '# Log\n\n## Active Intent Ledger\n\n%s\n\n## Agent Teams dispatched\n' "$sb_session_ledger_placeholder" >"$LOG"
in_proj sb_session_ledger_append_request "do the thing" silver-plan
body="$(cat "$LOG")"
assert_contains "placeholder replaced by the request" "$body" "  > do the thing"
assert_not_contains "placeholder gone" "$body" "$sb_session_ledger_placeholder"
in_proj sb_session_ledger_append_request "second" silver-verify
assert_eq "second request inserted before the anchor" "1" "$(awk '/> second/{r=NR} /^## Agent Teams dispatched$/{a=NR} END{print (r<a)?1:0}' "$LOG")"
printf '# Log\n## Agent Teams dispatched\nx\n' >"$LOG"
in_proj sb_session_ledger_append_request "anchored" silver-plan
assert_eq "request inserted before the anchor when no placeholder" "1" "$(awk '/> anchored/{r=NR} /^## Agent Teams dispatched$/{a=NR} END{print (r<a)?1:0}' "$LOG")"
printf '# Log only\n' >"$LOG"
in_proj sb_session_ledger_append_request "appended" silver-plan
assert_contains "request appended when neither marker exists" "$(tail -4 "$LOG")" "> appended"

# unusable log targets are skipped silently
rm -f "$LOG"
in_proj sb_session_ledger_append_request "nothing" silver-plan
assert_file_absent "missing log: nothing created" "$LOG"
printf '%s' "$TL_TMP/does-not-exist.md" >"$SD/session-log-path"
(cd "$TL_TMP/plain" && sb_session_ledger_append_request "x")
printf '%s' "$LOG" >"$SD/session-log-path"
ln -s "$TL_TMP/target" "$LOG"
sb_session_ledger_append_block "$LOG" "block"
assert_file_absent "symlinked log is not written" "$TL_TMP/target"
rm -f "$LOG"

# awk failing leaves the log untouched and reports failure
printf '%s\n' "$sb_session_ledger_placeholder" >"$LOG"
before="$(cat "$LOG")"
tl_stub awk 'exit 1'
rc=0
sb_session_ledger_append_block "$LOG" "block" || rc=$?
assert_eq "awk failure (placeholder path) reports failure" "1" "$rc"
printf '%s\n' "$sb_session_ledger_anchor" >"$LOG"
rc=0
sb_session_ledger_append_block "$LOG" "block" || rc=$?
assert_eq "awk failure (anchor path) reports failure" "1" "$rc"
rm -f "${TL_BIN:?}/awk"; hash -r
printf '%s\n' "$sb_session_ledger_placeholder" >"$LOG"
assert_eq "log unchanged after the failed rewrite" "$before" "$(cat "$LOG")"

# ---- mark completed ---------------------------------------------------------
printf 'x\n  - [ ] silver-plan\n  - [ ] silver-plan-extra\n  - [ ] a.b(c)\n' >"$LOG"
sb_session_ledger_mark_completed ""
in_proj sb_session_ledger_mark_completed silver-plan
body="$(cat "$LOG")"
assert_contains "matching skill ticked" "$body" "  - [x] silver-plan"$'\n'
assert_contains "longer skill name untouched" "$body" "  - [ ] silver-plan-extra"
in_proj sb_session_ledger_mark_completed 'a.b(c)'
assert_contains "regex characters in the skill name are escaped" "$(cat "$LOG")" "  - [x] a.b(c)"
rm -f "$LOG"
in_proj sb_session_ledger_mark_completed silver-plan
assert_file_absent "missing log: nothing created" "$LOG"
printf '  - [ ] z\n' >"$LOG"
rc=0
SILVER_BULLET_SESSION_LOG_PATH_FILE="$TL_TMP/no-such-path-file" sb_session_ledger_mark_completed z || rc=$?
assert_eq "no session-log path file: nothing to mark, still succeeds" "0" "$rc"
assert_eq "no session-log path file: the log is untouched" "  - [ ] z" "$(cat "$LOG")"
tl_stub awk 'exit 1'
rc=0
in_proj sb_session_ledger_mark_completed z || rc=$?
rm -f "${TL_BIN:?}/awk"; hash -r
assert_eq "awk failure reports failure" "1" "$rc"
assert_eq "awk failure leaves the log" "  - [ ] z" "$(cat "$LOG")"

tl_results
