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
[[ "${CODEX_FAIL_UNTIL:-0}" -ge "$n" ]] && exit "${CODEX_FAIL_RC:-1}"
exit 0
S
  cat >"$T/scripts/install-cursor.sh" <<'S'
#!/usr/bin/env bash
echo "install-cursor HOME=$HOME CURSOR_HOME=$CURSOR_HOME RUNTIME=$SILVER_BULLET_RUNTIME" >>"$LOG"
[[ -n "${CURSOR_HANG:-}" ]] && exec sleep "$CURSOR_HANG"
[[ -n "${CURSOR_INSTALL_RC:-}" ]] && { echo "boom out"; echo "boom err" >&2; exit "$CURSOR_INSTALL_RC"; }
if [[ -z "${CURSOR_NO_HOOKS:-}" ]]; then
  mkdir -p "$CURSOR_HOME"
  echo "${CURSOR_HOOKS_BODY:-silver-bullet hooks}" >"$CURSOR_HOME/hooks.json"
fi
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

# --- cursor, all green --------------------------------------------------
build_tree
SMOKE_ARGS=(--host cursor)
smoke PATH="$NOCLAUDE"
assert_eq "cursor host passes" 0 "$TL_STATUS"
assert_contains "banner shows the repo root" "$TL_OUT" "REPO_ROOT=$T"
assert_contains "banner shows the timeouts" "$TL_OUT" "timeouts: overall=60s cmd=30s diag=30s"
for step in "cursor: install-cursor.sh" "cursor: hooks.json merged" "cursor: sb-diagnostics.sh" \
  "cursor: claims-audit.sh" "cursor: check-apo-invariants site-doc-freshness"; do
  assert_contains "PASS $step" "$TL_OUT" "PASS: $step"
done
assert_contains "summary counts checks" "$TL_OUT" "Tri-host smoke: 6 passed, 0 failed, 0 skipped (6 checks)"
assert_contains "installer ran in an isolated cursor HOME" "$(<"$LOG")" "install-cursor HOME=$TL_TMP/tmp/sb-trihost-cursor."
assert_contains "installer ran as the cursor runtime" "$(<"$LOG")" "RUNTIME=cursor"
assert_contains "diagnostics in smoke mode" "$(<"$LOG")" "diag runtime=cursor smoke=1"
assert_contains "claims audit runs with RTK disabled" "$(<"$LOG")" "claims-audit RTK=1"
assert_contains "apo invariant check invoked" "$(<"$LOG")" "apo site-doc-freshness"
assert_eq "isolated HOME removed afterwards" "" "$(ls -A "$TL_TMP/tmp")"

# Positional host argument and an operator-supplied post-install setting.
build_tree
SMOKE_ARGS=(cursor)
smoke PATH="$NOCLAUDE"
assert_eq "positional host passes" 0 "$TL_STATUS"
assert_contains "post-install reconcile skipped by default" "$(<"$LOG")" "install-cursor"

# --- cursor failures ----------------------------------------------------
build_tree
SMOKE_ARGS=(--host cursor)
smoke PATH="$NOCLAUDE" CURSOR_NO_HOOKS=1
assert_eq "missing hooks.json fails" 1 "$TL_STATUS"
assert_contains "missing hooks.json verdict" "$TL_OUT" "FAIL: cursor: hooks.json missing after install"
assert_not_contains "no diagnostics after missing hooks.json" "$(<"$LOG")" "diag"

build_tree
smoke PATH="$NOCLAUDE" CURSOR_HOOKS_BODY='{"hooks":{}}'
assert_eq "hooks.json without silver-bullet fails" 1 "$TL_STATUS"
assert_contains "foreign hooks.json verdict" "$TL_OUT" "FAIL: cursor: hooks.json missing silver-bullet entries"

build_tree
smoke PATH="$NOCLAUDE" DIAG_FAIL_RUNTIME=cursor
assert_eq "failing diagnostics fail the smoke" 1 "$TL_STATUS"
assert_contains "diagnostics verdict" "$TL_OUT" "FAIL: cursor: sb-diagnostics.sh"
assert_contains "checks continue after diagnostics failure" "$TL_OUT" "PASS: cursor: claims-audit.sh"

build_tree
smoke PATH="$NOCLAUDE" CLAIMS_FAIL=1 APO_FAIL=1
assert_eq "failing sb invocations fail the smoke" 1 "$TL_STATUS"
assert_contains "claims audit verdict" "$TL_OUT" "FAIL: cursor: claims-audit.sh"
assert_contains "apo verdict" "$TL_OUT" "FAIL: cursor: check-apo-invariants site-doc-freshness"
assert_contains "failure summary" "$TL_OUT" "2 failed"

# Failing installer: rc and log tail shown; a failing `tail` must not mask the verdict.
build_tree
tl_stub tail 'exit 1'
smoke PATH="$TL_BIN:$NOCLAUDE" CURSOR_INSTALL_RC=7
assert_eq "failing installer fails the smoke" 1 "$TL_STATUS"
assert_contains "installer rc reported" "$TL_ERR" "cursor: install-cursor.sh failed (rc=7)"
assert_contains "log tail framing printed even when tail fails" "$TL_ERR" "----- end of cursor: install-cursor.sh log -----"
assert_contains "installer verdict" "$TL_OUT" "FAIL: cursor: install-cursor.sh"
assert_not_contains "no further checks after a failed install" "$TL_OUT" "hooks.json merged"
rm -f "$TL_BIN/tail"

# --- command timeout -----------------------------------------------------
build_tree
smoke PATH="$NOCLAUDE" CURSOR_HANG=7.11 SB_TRIHOST_CMD_TIMEOUT=1
assert_eq "hanging installer fails the smoke" 1 "$TL_STATUS"
assert_contains "timeout verdict" "$TL_OUT" "FAIL: cursor: install-cursor.sh (TIMED OUT after 1s"
assert_contains "hang detected message" "$TL_ERR" "hang detected for cursor: install-cursor.sh"

# --- overall timeout -----------------------------------------------------
build_tree
# The overall timeout does not signal the installer's own timeout wrapper
# (separate process group), so a short per-command timeout bounds the orphan.
smoke PATH="$NOCLAUDE" CURSOR_HANG=7.12 SB_TRIHOST_CMD_TIMEOUT=2 SB_TRIHOST_OVERALL_TIMEOUT=1
assert_eq "overall timeout exits 124" 124 "$TL_STATUS"
assert_contains "overall timeout explained" "$TL_ERR" "tri-host install smoke hung — overall timeout 1s"
assert_contains "tuning hint" "$TL_ERR" "SB_TRIHOST_CMD_TIMEOUT"

# Never leave the (distinctively timed) hung installer behind: wait for the
# command-level timeout to reap it, bounded.
for _ in $(seq 1 60); do
  [[ -z "$(ps -eo args= | grep -F "sleep 7.1" | grep -vF grep || true)" ]] && break
  /bin/sleep 0.2
done
assert_eq "no hung installer left running" "" "$(ps -eo args= | grep -F "sleep 7.1" | grep -vF grep || true)"

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
assert_contains "all-host summary" "$TL_OUT" "Tri-host smoke: 16 passed, 0 failed, 0 skipped (16 checks)"

build_tree
SMOKE_ARGS=(--host)
smoke PATH="$TL_BIN:$NOCLAUDE"
assert_eq "--host without a value means all" 0 "$TL_STATUS"
assert_contains "--host alone runs codex" "$TL_OUT" "PASS: codex: install-codex.sh"
assert_contains "--host alone runs cursor" "$TL_OUT" "PASS: cursor: install-cursor.sh"

build_tree
SMOKE_ARGS=(--host nonsense)
smoke PATH="$TL_BIN:$NOCLAUDE"
assert_eq "unknown host exits 2" 2 "$TL_STATUS"
assert_contains "unknown host message" "$TL_ERR" "Unknown host: nonsense (use all|codex|cursor|claude)"

tl_results
