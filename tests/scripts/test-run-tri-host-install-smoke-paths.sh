#!/usr/bin/env bash
# run-tri-host-install-smoke.sh decision paths against stub installers: host
# dispatch, install retry rules, timeout verdicts, hooks.json verification,
# claude CLI skip and the summary/exit code. Real installers are covered by
# test-tri-host-install-smoke.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

T="$TL_TMP/tree"
LOG="$TL_TMP/calls.log"
COUNT="$TL_TMP/install-count"
SLEEPS="$TL_TMP/sleeps.log"
mkdir -p "$TL_TMP/tmp"

build_tree() {
  rm -rf "$T" "$COUNT"
  mkdir -p "$T/scripts/lib" "$T/hooks/lib"
  cp "$TL_REPO_ROOT/scripts/run-tri-host-install-smoke.sh" "$T/scripts/"
  cp "$TL_REPO_ROOT/scripts/lib/command-timeout.sh" "$T/scripts/lib/"
  cp "$TL_REPO_ROOT/hooks/lib/runtime-paths.sh" "$T/hooks/lib/"
  cat >"$T/scripts/install-codex.sh" <<'S'
#!/usr/bin/env bash
n=$(( $(cat "$COUNT" 2>/dev/null || echo 0) + 1 )); echo "$n" >"$COUNT"
echo "install-codex attempt=$n HOME=$HOME RUNTIME=$SILVER_BULLET_RUNTIME SKIP=${RT_SKIP_POST_INSTALL-}" >>"$LOG"
echo "install-codex-env kay=${KAY_HOME-unset} claude=${CLAUDE_CONFIG_DIR-unset} state=${SB_RUNTIME_STATE_DIR-unset} statefile=${SILVER_BULLET_STATE_FILE-unset}" >>"$LOG"
[[ -n "${CODEX_IGNORE_TERM:-}" ]] && trap '' TERM
if [[ -n "${CODEX_CHAIN_FILE:-}" ]]; then
  # Own pid and the three ancestors above it: installer, timeout wrapper, smoke, supervisor.
  p=$$; chain=""
  for _ in 1 2 3 4; do chain+="$p "; p="$(ps -o ppid= -p "$p" | tr -d ' ')"; done
  echo "$chain" >"$CODEX_CHAIN_FILE.tmp" && mv "$CODEX_CHAIN_FILE.tmp" "$CODEX_CHAIN_FILE"
fi
[[ -n "${CODEX_HANG:-}" ]] && exec sleep "$CODEX_HANG"
[[ "${CODEX_FAIL_UNTIL:-0}" -ge "$n" ]] && { echo "boom out"; echo "boom err" >&2; exit "${CODEX_FAIL_RC:-1}"; }
exit 0
S
  cat >"$T/scripts/install-claude.sh" <<'S'
#!/usr/bin/env bash
echo "install-claude HOME=$HOME BIN=$CLAUDE_BIN RUNTIME=$SILVER_BULLET_RUNTIME" >>"$LOG"
exit "${CLAUDE_INSTALL_RC:-0}"
S
  cat >"$T/scripts/sb-diagnostics.sh" <<'S'
#!/usr/bin/env bash
echo "diag runtime=$SILVER_BULLET_RUNTIME smoke=$SB_DIAG_SMOKE" >>"$LOG"
[[ "$SILVER_BULLET_RUNTIME" == "${DIAG_FAIL_RUNTIME:-none}" ]] && exit 3
exit 0
S
  cat >"$T/scripts/claims-audit.sh" <<'S'
#!/usr/bin/env bash
echo "claims-audit RTK=$RTK_DISABLED" >>"$LOG"
[[ -n "${CLAIMS_FAIL:-}" ]] && exit 2
exit 0
S
  cat >"$T/scripts/check-apo-invariants.py" <<'S'
import os, sys
open(os.environ["LOG"], "a").write("apo " + " ".join(sys.argv[1:]) + "\n")
sys.exit(2 if os.environ.get("APO_FAIL") else 0)
S
  chmod +x "$T"/scripts/*.sh
  : >"$LOG"
}

run_smoke() {
  tl_run env LOG="$LOG" COUNT="$COUNT" TMPDIR="$TL_TMP/tmp" SB_TRIHOST_OVERALL_TIMEOUT=60 \
    SB_TRIHOST_CMD_TIMEOUT=30 SB_TRIHOST_DIAG_TIMEOUT=30 "$@"
}
smoke() { run_smoke "$@" bash "$T/scripts/run-tri-host-install-smoke.sh" "${SMOKE_ARGS[@]}"; }

# claude is never reachable unless a test provides it.
NOCLAUDE="$(tl_path_without claude)"

# --- codex, all green ---------------------------------------------------
build_tree
SMOKE_ARGS=(--host codex)
smoke PATH="$NOCLAUDE" KAY_HOME=/real/kay CLAUDE_CONFIG_DIR=/real/claude SB_RUNTIME_STATE_DIR=/real/state SILVER_BULLET_STATE_FILE=/real/sf
assert_eq "codex host passes" 0 "$TL_STATUS"
assert_contains "banner shows the repo root" "$TL_OUT" "REPO_ROOT=$T"
assert_contains "banner shows the timeouts" "$TL_OUT" "timeouts: overall=60s cmd=30s diag=30s"
for step in "codex: install-codex.sh" "codex: sb-diagnostics.sh" \
  "codex: claims-audit.sh" "codex: check-apo-invariants site-doc-freshness"; do
  assert_contains "PASS $step" "$TL_OUT" "PASS: $step"
done
assert_contains "summary counts checks" "$TL_OUT" "Tri-host smoke: 5 passed, 0 failed, 0 skipped (5 checks)"
assert_contains "installer ran in an isolated codex HOME" "$(<"$LOG")" "install-codex attempt=1 HOME=$TL_TMP/tmp/sb-trihost-codex."
assert_contains "installer saw no host-config redirect" "$(<"$LOG")" "install-codex-env kay=unset claude=unset state=unset statefile=unset"
assert_contains "installer ran as the codex runtime" "$(<"$LOG")" "RUNTIME=codex"
assert_contains "diagnostics in smoke mode" "$(<"$LOG")" "diag runtime=codex smoke=1"
assert_contains "claims audit runs with RTK disabled" "$(<"$LOG")" "claims-audit RTK=1"
assert_contains "apo invariant check invoked" "$(<"$LOG")" "apo site-doc-freshness"
assert_eq "isolated HOME removed afterwards" "" "$(ls -A "$TL_TMP/tmp")"

# Positional host argument.
build_tree
SMOKE_ARGS=(codex)
smoke PATH="$NOCLAUDE"
assert_eq "positional host passes" 0 "$TL_STATUS"
assert_contains "positional host ran the installer" "$(<"$LOG")" "install-codex"

build_tree
smoke PATH="$NOCLAUDE" DIAG_FAIL_RUNTIME=codex
assert_eq "failing diagnostics fail the smoke" 1 "$TL_STATUS"
assert_contains "diagnostics verdict" "$TL_OUT" "FAIL: codex: sb-diagnostics.sh"
assert_contains "checks continue after diagnostics failure" "$TL_OUT" "PASS: codex: claims-audit.sh"

build_tree
smoke PATH="$NOCLAUDE" CLAIMS_FAIL=1 APO_FAIL=1
assert_eq "failing sb invocations fail the smoke" 1 "$TL_STATUS"
assert_contains "claims audit verdict" "$TL_OUT" "FAIL: codex: claims-audit.sh"
assert_contains "apo verdict" "$TL_OUT" "FAIL: codex: check-apo-invariants site-doc-freshness"
assert_contains "failure summary" "$TL_OUT" "2 failed"

# Failing installer: rc and log tail shown; a failing `tail` must not mask the verdict.
build_tree
tl_stub tail 'exit 1'
tl_stub sleep 'exit 0'
smoke PATH="$TL_BIN:$NOCLAUDE" CODEX_FAIL_UNTIL=99 CODEX_FAIL_RC=7
assert_eq "failing installer fails the smoke" 1 "$TL_STATUS"
assert_contains "installer rc reported" "$TL_ERR" "codex: install-codex.sh (attempt 3) failed (rc=7)"
assert_contains "log tail framing printed even when tail fails" "$TL_ERR" "----- end of codex: install-codex.sh (attempt 3) log -----"
assert_contains "installer verdict" "$TL_OUT" "FAIL: codex: install-codex.sh"
assert_not_contains "no further checks after a failed install" "$TL_OUT" "sb-diagnostics.sh"
rm -f "$TL_BIN/tail" "$TL_BIN/sleep"

# --- command timeout -----------------------------------------------------
build_tree
smoke PATH="$NOCLAUDE" CODEX_HANG=7.11 SB_TRIHOST_CMD_TIMEOUT=1
assert_eq "hanging installer fails the smoke" 1 "$TL_STATUS"
assert_contains "timeout verdict" "$TL_OUT" "FAIL: codex: install-codex.sh (attempt 1) (TIMED OUT after 1s"
assert_contains "hang detected message" "$TL_ERR" "hang detected for codex: install-codex.sh (attempt 1)"

# --- overall timeout -----------------------------------------------------
# After the overall timeout fires no descendant may survive, however the installer's
# own timeout wrapper (a separate process group) is configured. Checked right after the
# run returns, with distinctive sleep durations, never by waiting for orphans to expire.
live_procs() { ps -eo pid=,stat=,args= | awk -v pat="$1" 'index($0, pat) && $2 !~ /^Z/ && !/awk/'; }

build_tree
smoke PATH="$NOCLAUDE" CODEX_HANG=7.12 SB_TRIHOST_CMD_TIMEOUT=2 SB_TRIHOST_OVERALL_TIMEOUT=1
assert_eq "overall timeout exits 124" 124 "$TL_STATUS"
assert_contains "overall timeout explained" "$TL_ERR" "tri-host install smoke hung — overall timeout 1s"
assert_contains "tuning hint" "$TL_ERR" "SB_TRIHOST_CMD_TIMEOUT"
assert_eq "no hung installer left running (short command timeout)" "" "$(live_procs "sleep 7.12")"

# Long command timeout: the installer's own timeout wrapper would keep the hung installer
# alive for minutes if the overall timeout left it behind.
build_tree
smoke PATH="$NOCLAUDE" CODEX_HANG=7.31 SB_TRIHOST_CMD_TIMEOUT=300 SB_TRIHOST_OVERALL_TIMEOUT=1
assert_eq "overall timeout exits 124 with a long command timeout" 124 "$TL_STATUS"
assert_eq "no hung installer left running (long command timeout)" "" "$(live_procs "sleep 7.31")"
assert_eq "no timeout wrapper left running" "" "$(live_procs "timeout --signal=TERM --kill-after=2 300s")"

# An installer that ignores SIGTERM is killed for good.
build_tree
smoke PATH="$NOCLAUDE" CODEX_HANG=7.32 CODEX_IGNORE_TERM=1 SB_TRIHOST_CMD_TIMEOUT=300 SB_TRIHOST_OVERALL_TIMEOUT=1
assert_eq "overall timeout exits 124 with a TERM-ignoring installer" 124 "$TL_STATUS"
assert_eq "no TERM-ignoring installer left running" "" "$(live_procs "sleep 7.32")"

# The TERM-to-KILL path stays fast when the machine is slow: with every `ps` call taking half
# a second the supervisor must still finish inside the launcher's kill-after window.
build_tree
tl_stub ps 'command -p sleep 0.5; exec /bin/ps "$@"'
[[ -x /bin/ps ]] || { REAL_PS="$(command -v ps)"; tl_stub ps 'command -p sleep 0.5; exec "'"$REAL_PS"'" "$@"'; }
smoke PATH="$TL_BIN:$NOCLAUDE" CODEX_HANG=7.33 CODEX_IGNORE_TERM=1 SB_TRIHOST_CMD_TIMEOUT=300 SB_TRIHOST_OVERALL_TIMEOUT=1
rm -f "$TL_BIN/ps"
assert_eq "slow ps: overall timeout still exits 124" 124 "$TL_STATUS"
assert_eq "slow ps: no TERM-ignoring installer left running" "" "$(live_procs "sleep 7.33")"

# Identity check: when a pid now carries a different start time (a recycled pid), it is not
# signalled. A ps that reports another start time on the second look keeps the survivor alive.
build_tree
REAL_PS="$(command -v ps)"
tl_stub ps 'if [[ "$*" == *stat=* ]]; then "'"$REAL_PS"'" "$@" | awk '"'"'{ print $1, $2, "Thu Jan  1 00:00:00 1970" }'"'"'; else exec "'"$REAL_PS"'" "$@"; fi'
smoke PATH="$TL_BIN:$NOCLAUDE" CODEX_HANG=7.34 CODEX_IGNORE_TERM=1 SB_TRIHOST_CMD_TIMEOUT=300 SB_TRIHOST_OVERALL_TIMEOUT=1
rm -f "$TL_BIN/ps"
assert_eq "identity mismatch: overall timeout exits 124" 124 "$TL_STATUS"
LEFT="$(live_procs "sleep 7.34")"
assert_contains "identity mismatch: the process with another start time was not killed" "$LEFT" "sleep 7.34"
# Clean up the one process this test left behind (its own descendant, found by its unique argument).
for p in $(awk '{ print $1 }' <<<"$LEFT"); do kill -KILL "$p" 2>/dev/null || true; done
assert_eq "identity mismatch: leftover removed" "" "$(sleep 0.3; live_procs "sleep 7.34")"

# A supervisor that is SIGKILLed cannot clean up: the smoke notices that its parent is gone
# and takes its own tree down within 5 seconds (the hung installer would run for 7.4).
pid_alive() { local st; st="$(ps -p "$1" -o stat= 2>/dev/null || true)"; [[ -n "$st" && "$st" != Z* ]]; }
build_tree
CHAIN="$TL_TMP/chain"
rm -f "$CHAIN"
( env LOG="$LOG" COUNT="$COUNT" TMPDIR="$TL_TMP/tmp" PATH="$NOCLAUDE" CODEX_HANG=7.41 CODEX_CHAIN_FILE="$CHAIN" \
    SB_TRIHOST_OVERALL_TIMEOUT=60 SB_TRIHOST_CMD_TIMEOUT=300 SB_TRIHOST_DIAG_TIMEOUT=30 \
    bash "$T/scripts/run-tri-host-install-smoke.sh" --host codex >/dev/null 2>&1 ) &
LAUNCHER=$!
for _ in $(seq 1 100); do [[ -s "$CHAIN" ]] && break; /bin/sleep 0.1; done
read -r -a CHAIN_PIDS <"$CHAIN"
assert_eq "chain recorded (installer, timeout, smoke, supervisor)" 4 "${#CHAIN_PIDS[@]}"
kill -KILL "${CHAIN_PIDS[3]}"
wait "$LAUNCHER" || true
for _ in $(seq 1 25); do
  any=0
  for p in "${CHAIN_PIDS[@]}"; do pid_alive "$p" && any=1; done
  [[ $any -eq 0 ]] && break
  /bin/sleep 0.2
done
for p in "${CHAIN_PIDS[@]}"; do
  assert_eq "orphaned chain member $p is gone" 1 "$(pid_alive "$p" && echo 0 || echo 1)"
done
assert_eq "no installer left after a killed supervisor" "" "$(live_procs "sleep 7.41")"

# --- codex ----------------------------------------------------------------
# Retries: two failed attempts, success on the third; the sleep between is stubbed.
build_tree
tl_stub sleep 'echo "$*" >>"'"$SLEEPS"'"'
: >"$SLEEPS"
SMOKE_ARGS=(--host codex)
smoke PATH="$TL_BIN:$NOCLAUDE" CODEX_FAIL_UNTIL=2
assert_eq "codex succeeds after retries" 0 "$TL_STATUS"
assert_contains "third attempt ran" "$(<"$LOG")" "install-codex attempt=3"
assert_eq "slept between attempts" "2
2" "$(<"$SLEEPS")"
assert_contains "codex install verdict" "$TL_OUT" "PASS: codex: install-codex.sh"
assert_contains "codex diagnostics ran" "$(<"$LOG")" "diag runtime=codex"
assert_contains "post-install reconcile skipped for installers" "$(<"$LOG")" "SKIP=1"
assert_contains "codex HOME is isolated" "$(<"$LOG")" "HOME=$TL_TMP/tmp/sb-trihost-codex."

# Operator override of RT_SKIP_POST_INSTALL is honoured.
build_tree
smoke PATH="$TL_BIN:$NOCLAUDE" RT_SKIP_POST_INSTALL=0
assert_contains "RT_SKIP_POST_INSTALL override kept" "$(<"$LOG")" "SKIP=0"

# Three failures: give up after three attempts.
build_tree
: >"$SLEEPS"
smoke PATH="$TL_BIN:$NOCLAUDE" CODEX_FAIL_UNTIL=99
assert_eq "codex gives up" 1 "$TL_STATUS"
assert_eq "exactly three attempts" "3" "$(<"$COUNT")"
assert_contains "codex failure verdict" "$TL_OUT" "FAIL: codex: install-codex.sh"
assert_not_contains "no diagnostics after failed install" "$(<"$LOG")" "diag"

# A hard timeout (rc 124) is not retried and sleeps nowhere.
build_tree
: >"$SLEEPS"
smoke PATH="$TL_BIN:$NOCLAUDE" CODEX_FAIL_UNTIL=99 CODEX_FAIL_RC=124
assert_eq "timeout rc fails the smoke" 1 "$TL_STATUS"
assert_eq "no retry after timeout rc" "1" "$(<"$COUNT")"
assert_eq "no sleep after timeout rc" "" "$(<"$SLEEPS")"
assert_contains "timeout rc labelled" "$TL_OUT" "TIMED OUT after 30s"

build_tree
smoke PATH="$TL_BIN:$NOCLAUDE" DIAG_FAIL_RUNTIME=codex
assert_eq "codex diagnostics failure fails the smoke" 1 "$TL_STATUS"
assert_contains "codex diagnostics verdict" "$TL_OUT" "FAIL: codex: sb-diagnostics.sh"
assert_contains "codex checks continue" "$TL_OUT" "PASS: codex: claims-audit.sh"

# --- claude ----------------------------------------------------------------
build_tree
SMOKE_ARGS=(--host claude)
smoke PATH="$NOCLAUDE"
assert_eq "skipping claude is not a failure" 0 "$TL_STATUS"
assert_contains "claude skip reported" "$TL_OUT" "SKIP: claude: CLI not available"
assert_contains "skip counted" "$TL_OUT" "0 passed, 0 failed, 1 skipped (1 checks)"

# CLAUDE_BIN pointing at a non-executable file is also a skip.
printf '#!/bin/sh\n' >"$TL_TMP/claude-noexec"
build_tree
smoke PATH="$NOCLAUDE" CLAUDE_BIN="$TL_TMP/claude-noexec"
assert_contains "non-executable CLAUDE_BIN skipped" "$TL_OUT" "SKIP: claude: CLI not available"

# A claude CLI on PATH is exercised.
build_tree
tl_stub claude 'exit 0'
smoke PATH="$TL_BIN:$NOCLAUDE"
assert_eq "claude host passes" 0 "$TL_STATUS"
assert_contains "claude install verdict" "$TL_OUT" "PASS: claude: install-claude.sh"
assert_contains "claude diagnostics verdict" "$TL_OUT" "PASS: claude: sb-diagnostics.sh"
assert_contains "installer got the CLI path and an isolated HOME" "$(<"$LOG")" "install-claude HOME=$TL_TMP/tmp/sb-trihost-claude."
assert_contains "installer got the resolved CLI" "$(<"$LOG")" "BIN=$TL_BIN/claude"

build_tree
smoke PATH="$TL_BIN:$NOCLAUDE" CLAUDE_INSTALL_RC=1
assert_eq "claude install failure fails the smoke" 1 "$TL_STATUS"
assert_contains "claude install verdict (fail)" "$TL_OUT" "FAIL: claude: install-claude.sh"
assert_not_contains "no claude diagnostics after failed install" "$(<"$LOG")" "diag runtime=claude"

build_tree
smoke PATH="$TL_BIN:$NOCLAUDE" DIAG_FAIL_RUNTIME=claude
assert_eq "claude diagnostics failure fails the smoke" 1 "$TL_STATUS"
assert_contains "claude diagnostics verdict (fail)" "$TL_OUT" "FAIL: claude: sb-diagnostics.sh"

# --- all hosts / argument handling -------------------------------------------
build_tree
SMOKE_ARGS=()
smoke PATH="$TL_BIN:$NOCLAUDE"
assert_eq "all hosts pass" 0 "$TL_STATUS"
assert_contains "all-host summary" "$TL_OUT" "Tri-host smoke: 10 passed, 0 failed, 0 skipped (10 checks)"

build_tree
SMOKE_ARGS=(--host)
smoke PATH="$TL_BIN:$NOCLAUDE"
assert_eq "--host without a value means all" 0 "$TL_STATUS"
assert_contains "--host alone runs codex" "$TL_OUT" "PASS: codex: install-codex.sh"
assert_contains "--host alone runs claude" "$TL_OUT" "PASS: claude: install-claude.sh"

build_tree
SMOKE_ARGS=(--host nonsense)
smoke PATH="$TL_BIN:$NOCLAUDE"
assert_eq "unknown host exits 2" 2 "$TL_STATUS"
assert_contains "unknown host message" "$TL_ERR" "Unknown host: nonsense (use all|codex|claude)"

tl_results
