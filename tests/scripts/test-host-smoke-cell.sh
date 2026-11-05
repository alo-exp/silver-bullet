#!/usr/bin/env bash
# scripts/lib/host-smoke-cell.sh: argument handling, scopes, fresh/upgrade install cells and
# structural-only mode. Runs a byte-identical copy in a staged tree whose installers,
# diagnostics and validators are stubs; no host CLI is ever started.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/k-agents-live-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/k-agents-live-2-helpers.sh"

T="$TL_TMP/tree"
k2_stage_smoke_tree "$T"
CELL="$T/scripts/lib/host-smoke-cell.sh"
export STUB_LOG="$TL_TMP/stub.log"

cell() { # [env...] -- args  : run the cell, clear the log first
  local envs=()
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  : >"$STUB_LOG"
  tl_run env "${envs[@]}" bash "$CELL" "$@"
  LOG="$(cat "$STUB_LOG")"
}

# ---- argument errors ----
cell X=1 -- --bogus
assert_eq "unknown flag exits 2" 2 "$TL_STATUS"
cell X=1 -- --host codex
assert_eq "missing --mode exits 2" 2 "$TL_STATUS"
cell X=1 -- --mode fresh
assert_eq "missing --host exits 2" 2 "$TL_STATUS"

# ---- fresh codex, rc scope runs the claims audit ----
cell X=1 -- --host codex --mode fresh --scope rc
assert_eq "codex fresh rc exits 0" 0 "$TL_STATUS"
assert_contains "pass line" "$TL_OUT" "PASS: host-smoke-cell codex fresh"
assert_match "codex install ran once under isolated HOME" '^install codex repo='"$T"' home=.*/codex' "$(sed -n 1p <<<"$LOG")"
assert_eq "diagnostics second" "diagnostics runtime=codex smoke=1" "$(sed -n 2p <<<"$LOG")"
assert_eq "claims audit last with RTK disabled" "claims rtk=1" "$(sed -n 3p <<<"$LOG")"
assert_eq "three stub calls total" 3 "$(wc -l <<<"$LOG" | tr -d ' ')"

# ---- tri-host scope also audits claims; default scope does not ----
cell X=1 -- --host codex --mode fresh --scope tri-host
assert_contains "tri-host runs claims audit" "$LOG" "claims rtk=1"
cell X=1 -- --host codex --mode fresh
assert_eq "default scope exits 0" 0 "$TL_STATUS"
assert_not_contains "default scope skips claims audit" "$LOG" "claims"

# ---- failures abort the cell ----
cell STUB_FAIL_INSTALL=1 -- --host codex --mode fresh --scope rc
assert_eq "install failure exits 1" 1 "$TL_STATUS"
assert_not_contains "no pass line on install failure" "$TL_OUT" "PASS:"
cell STUB_FAIL_DIAG=1 -- --host codex --mode fresh --scope rc
assert_eq "diagnostics failure exits 1" 1 "$TL_STATUS"
cell STUB_FAIL_CLAIMS=1 -- --host codex --mode fresh --scope rc
assert_eq "claims failure exits 1" 1 "$TL_STATUS"

# ---- claude without the CLI is a skip (the runner hides claude from PATH) ----
cell PATH="$(tl_path_without claude)" -- --host claude --mode fresh
assert_eq "claude without cli exits 0" 0 "$TL_STATUS"
assert_contains "claude skip message" "$TL_OUT" "SKIP: claude (CLI unavailable)"
assert_eq "claude skip runs nothing" "" "$LOG"
# ... with a stub claude CLI the install cell runs
tl_stub claude 'exit 0'
hash -r
cell X=1 -- --host claude --mode fresh --scope rc
assert_eq "claude with cli exits 0" 0 "$TL_STATUS"
assert_contains "claude installed" "$LOG" "install claude"
assert_contains "claude diagnostics runtime" "$LOG" "diagnostics runtime=claude"
rm -f "$TL_BIN/claude"; hash -r

# ---- cursor: hook tests only for ci-smoke, cli smoke only for pre-release ----
cell X=1 -- --host cursor --mode fresh --scope ci-smoke
assert_eq "cursor ci-smoke exits 0" 0 "$TL_STATUS"
assert_contains "ci-smoke bridge test" "$LOG" "test-cursor-hook-bridge"
assert_contains "ci-smoke bootstrap test" "$LOG" "test-cursor-runtime-bootstrap"
assert_contains "ci-smoke runtime paths test" "$LOG" "test-runtime-paths"
assert_not_contains "ci-smoke does not run cursor cli smoke" "$LOG" "cursor-cli-smoke"
cell STUB_FAIL_test_cursor_hook_bridge=1 -- --host cursor --mode fresh --scope ci-smoke
assert_eq "hook test failure is fatal" 1 "$TL_STATUS"

cell X=1 -- --host cursor --mode fresh --scope pre-release
assert_eq "cursor pre-release exits 0" 0 "$TL_STATUS"
assert_contains "pre-release runs cursor cli smoke with current env" "$LOG" "cursor-cli-smoke env=1"
assert_not_contains "pre-release skips hook tests" "$LOG" "test-cursor-hook-bridge"
cell STUB_FAIL_CURSOR_CLI=1 -- --host cursor --mode fresh --scope pre-release
assert_eq "cursor cli smoke failure is fatal" 1 "$TL_STATUS"

# cursor marker: written only when requested and scope allows
KEEP="$TL_TMP/keep1"
cell SMOKE_KEEP="$KEEP" SB_RELEASE_LIVE_MATRIX_WRITE_CURSOR_MARKER=1 -- --host cursor --mode fresh
assert_file_exists "cursor marker written" "$KEEP/cursor/.silver-bullet/release-live-matrix"
assert_eq "cursor marker content" "matrix=cursor-smoke" "$(cat "$KEEP/cursor/.silver-bullet/release-live-matrix")"
KEEP="$TL_TMP/keep2"
cell SMOKE_KEEP="$KEEP" SB_RELEASE_LIVE_MATRIX_WRITE_CURSOR_MARKER=1 -- --host cursor --mode fresh --scope ci-smoke
assert_file_absent "ci-smoke scope never writes the marker" "$KEEP/cursor/.silver-bullet/release-live-matrix"
KEEP="$TL_TMP/keep3"
cell SMOKE_KEEP="$KEEP" -- --host cursor --mode fresh
assert_file_absent "marker off by default" "$KEEP/cursor/.silver-bullet/release-live-matrix"

# ---- upgrade: previous tag checkout is installed first, then the current tree twice ----
git -C "$T" init -q -b main
git -C "$T" config user.email t@example.com; git -C "$T" config user.name T; git -C "$T" config commit.gpgsign false
git -C "$T" config gc.auto 0
git -C "$T" add -A; git -C "$T" commit -q -m one; git -C "$T" tag v1.0.0
echo two >"$T/two.txt"; git -C "$T" add -A; git -C "$T" commit -q -m two; git -C "$T" tag v2.0.0
cell X=1 -- --host codex --mode upgrade --scope rc
assert_eq "upgrade exits 0" 0 "$TL_STATUS"
assert_eq "upgrade installs: seed, install, re-install" 3 "$(grep -c '^install codex' <<<"$LOG")"
assert_match "seed install runs against the prior tag checkout" '^install codex repo=.*/prior-tag ' "$(sed -n 1p <<<"$LOG")"
assert_match "second install uses the current tree" '^install codex repo='"$T"' ' "$(sed -n 2p <<<"$LOG")"
# a failing re-install after a successful install is tolerated
cat >"$T/scripts/install-codex.sh" <<EOS
#!/usr/bin/env bash
n=\$(cat "$TL_TMP/inst.count" 2>/dev/null || echo 0); echo \$((n+1)) >"$TL_TMP/inst.count"
echo "install codex call \$((n+1))" >>"\${STUB_LOG:?}"
[[ \$((n+1)) -ge 3 ]] && exit 1
exit 0
EOS
rm -f "$TL_TMP/inst.count"
cell X=1 -- --host codex --mode upgrade --scope rc
assert_eq "failing re-install does not fail the cell" 0 "$TL_STATUS"
assert_contains "third install was attempted" "$LOG" "install codex call 3"
k2_stub_script "$T/scripts/install-codex.sh" "install codex repo=\${SB_PRE_RELEASE_REPO_ROOT:-} home=\$HOME" STUB_FAIL_INSTALL
# explicit previous tag, and a tag that does not exist (checkout fails, still succeeds)
cell SB_RC_PREVIOUS_TAG=v1.0.0 -- --host codex --mode upgrade
assert_eq "upgrade with explicit tag exits 0" 0 "$TL_STATUS"
cell SB_RC_PREVIOUS_TAG=no-such-tag -- --host codex --mode upgrade
assert_eq "upgrade with unknown tag still exits 0" 0 "$TL_STATUS"
assert_eq "unknown tag: no seed install, then install and re-install" 2 "$(grep -c '^install codex' <<<"$LOG")"
# no .git: previous tag unresolvable -> plain install as seed
rm -rf "$T/.git"
cell X=1 -- --host codex --mode upgrade
assert_eq "upgrade without git history exits 0" 0 "$TL_STATUS"
assert_eq "no git: seed, install, re-install" 3 "$(grep -c '^install codex' <<<"$LOG")"
assert_not_contains "no git: seed uses the current tree" "$(sed -n 1p <<<"$LOG")" "prior-tag"
cell STUB_FAIL_INSTALL=1 -- --host codex --mode upgrade
assert_eq "upgrade install failure exits 1" 1 "$TL_STATUS"

# ---- structural-only runs the three validators with --repo-root ----
cell X=1 -- --host codex --mode structural-only
assert_eq "structural-only exits 0" 0 "$TL_STATUS"
assert_eq "validators called in order" "validate-host-agnostic-core args=--repo-root $T
validate-host-install-surface args=--repo-root $T
validate-host-skill-surface args=--repo-root $T" "$LOG"
assert_contains "structural-only pass line" "$TL_OUT" "PASS: host-smoke-cell codex structural-only"
cell STUB_FAIL_validate_host_install_surface=1 -- --host codex --mode structural-only
assert_eq "failing validator stops the cell" 1 "$TL_STATUS"

# unknown mode falls through without running anything but still reports
cell X=1 -- --host codex --mode bogus
assert_eq "unknown mode runs nothing" "" "$LOG"

tl_results
