#!/usr/bin/env bash
# scripts/lib/pid-identity.sh with real processes: a pid is trusted only while its start time and process
# group equal the record written by whoever started it (R14-10).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
source "$TL_REPO_ROOT/scripts/lib/pid-identity.sh"

PF="$TL_TMP/batch.pid"
alive() { kill -0 "$1" 2>/dev/null && [[ "$(command ps -o stat= -p "$1" 2>/dev/null | tr -d ' ')" != Z* ]]; }
# a decoy "runner" in its own session with a claude-looking child, started from another directory
mkdir -p "$TL_TMP/elsewhere"
RUN="$(cd "$TL_TMP/elsewhere" && setsid bash -c 'exec -a "bash scripts/run-enterprise-e2e-matrix.sh" /bin/sleep 300 >/dev/null 2>&1 & echo $!' )"
/bin/sleep 0.3
echo "$RUN" >"$PF"

assert_eq "no record: not trusted" "" "$(sb_pid_identity_verify "$PF" || true)"
sb_pid_identity_write "$PF" "$RUN"
assert_eq "record is mode 0600" 600 "$(stat -c %a "$PF.id")"
assert_eq "recorded pid verifies" "$RUN" "$(sb_pid_identity_verify "$PF")"

# reused pid: same number, different start time
rec="$(cat "$PF.id")"
printf '%s|%s|%s\n' "$RUN" "$(sb_pid_group "$RUN")" "Mon Jan  1 00:00:00 1999" >"$PF.id"
assert_eq "different start time (reused pid): not trusted" "" "$(sb_pid_identity_verify "$PF" || true)"
printf '%s|%s|%s\n' "$RUN" 1 "$(sb_pid_start_token "$RUN")" >"$PF.id"
assert_eq "different process group: not trusted" "" "$(sb_pid_identity_verify "$PF" || true)"
printf '%s|%s|%s\n' 1 1 "x" >"$PF.id"
assert_eq "record for another pid: not trusted" "" "$(sb_pid_identity_verify "$PF" || true)"
echo "$rec" >"$PF.id"
assert_eq "restored record verifies again" "$RUN" "$(sb_pid_identity_verify "$PF")"
echo "not-a-pid" >"$PF"
assert_eq "junk pid file: not trusted" "" "$(sb_pid_identity_verify "$PF" || true)"
assert_eq "missing pid file: not trusted" "" "$(sb_pid_identity_verify "$TL_TMP/none.pid" || true)"

# a process that exited is not trusted, and cannot be recorded
kill -TERM "$RUN" 2>/dev/null || true
for _ in $(seq 1 30); do alive "$RUN" || break; /bin/sleep 0.1; done
echo "$RUN" >"$PF"; echo "$rec" >"$PF.id"
if alive "$RUN"; then tl_fail "decoy exited"; kill -KILL "$RUN"; else tl_pass "decoy exited"; fi
tl_stub ps 'exit 1'
assert_eq "a dead pid is not trusted" "" "$(sb_pid_identity_verify "$PF" || true)"
rc=0; sb_pid_identity_write "$PF" 2147483646 || rc=$?
assert_eq "an unknown pid cannot be recorded" 1 "$rc"
# a recorded pid that no longer exists (kill -0 fails) is not trusted
echo 2147483646 >"$PF"; printf '2147483646|1|Mon Jan  1 00:00:00 2026\n' >"$PF.id"
assert_eq "a vanished pid is not trusted" "" "$(sb_pid_identity_verify "$PF" || true)"
tl_results
