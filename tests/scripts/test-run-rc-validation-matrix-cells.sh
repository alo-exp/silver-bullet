#!/usr/bin/env bash
# scripts/run-rc-validation-matrix.sh in a temp tree: stub host-smoke cell, stub live helpers.
# No agent CLI, network or real host home is touched.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

R="$TL_REPO_ROOT"
T="$TL_TMP/tree"
mkdir -p "$T/scripts/lib" "$T/tests/live/lib" "$T/tests/scripts/lib"
cp "$R/scripts/run-rc-validation-matrix.sh" "$T/scripts/"
cp "$R/scripts/lib/pre-release-host-isolation.sh" "$T/scripts/lib/"
M="$T/scripts/run-rc-validation-matrix.sh"
LOG="$TL_TMP/calls.log"
MK="$SB_RUNTIME_STATE_DIR/rc-validation"

# Stub the host smoke cell: records args, fails for hosts listed in CELL_FAIL.
cat >"$T/scripts/lib/host-smoke-cell.sh" <<EOS
#!/usr/bin/env bash
echo "cell \$*" >>"$LOG"
host=""; while [[ \$# -gt 0 ]]; do [[ "\$1" == --host ]] && host="\$2"; shift; done
[[ " \${CELL_FAIL:-} " == *" \$host "* ]] && exit 1
exit 0
EOS
# Stub live helper libraries; behaviour switched by environment variables.
cat >"$T/tests/live/lib/rc-delegate-smoke.sh" <<EOS
rc_delegate_smoke_run() { echo "delegate \$1 wd=\$2 log=\$3" >>"$LOG"; [[ " \${DELEGATE_FAIL:-} " == *" \$1 "* ]] && return 1; return 0; }
rc_delegate_five_tool_scenarios() { echo "fivetool \$1" >>"$LOG"; [[ "\${FIVETOOL_FAIL:-}" == 1 ]] && return 1; return 0; }
EOS
cat >"$T/tests/scripts/lib/five-tool-prerelease.sh" <<EOS
five_tool_leanctx_opted_in() { [[ "\${LEANCTX:-0}" == 1 ]]; }
five_tool_cursor_cli_path() { [[ "\${CURSOR_LIVE:-0}" == 1 ]] && echo /fake/cursor-agent; }
five_tool_cursor_agent_authenticated() { [[ "\${CURSOR_AUTH:-0}" == 1 ]]; }
five_tool_claude_cli_path() { [[ "\${CLAUDE_LIVE:-0}" == 1 ]] && echo /fake/claude; }
five_tool_claude_cli_authenticated() { [[ "\${CLAUDE_AUTH:-0}" == 1 ]]; }
EOS

mrun() { local -a envs=(); while [[ $# -gt 0 && "$1" == *=* ]]; do envs+=("$1"); shift; done
         : >"$LOG"; rm -rf "$MK"; tl_run env -u GITHUB_ACTIONS -u SB_RC_CI_MODE -u SB_RC_MATRIX_REQUIRE_LIVE "${envs[@]}" bash "$M" "$@"; }
marker() { cat "$MK/$1" 2>/dev/null || echo MISSING; }
status_of() { sed -n 's/^status=//p' "$MK/$1" 2>/dev/null || true; }
artifact_of() { sed -n 's/^artifact=//p' "$MK/$1" 2>/dev/null || true; }

# --- skip / args ----------------------------------------------------------------------------------
mrun SB_SKIP_RC_MATRIX=1
assert_eq "skip exits 0" 0 "$TL_STATUS"; assert_contains "skip message" "$TL_OUT" "SKIP: SB_SKIP_RC_MATRIX=1"
assert_eq "skip runs nothing" "" "$(cat "$LOG")"
mrun --bogus
assert_eq "unknown argument -> 2" 2 "$TL_STATUS"

# --- dry run ------------------------------------------------------------------------------------------
mrun --dry-run
assert_eq "dry-run ok" 0 "$TL_STATUS"
assert_contains "dry-run totals" "$TL_OUT" "RC matrix: 6 passed, 0 failed, 0 skipped"
for h in cursor codex claude; do for m in fresh upgrade; do
  assert_eq "dry-run marker $h-$m" pass "$(status_of "$h-$m")"
  assert_eq "dry-run artifact $h-$m" dry-run "$(artifact_of "$h-$m")"
done; done
assert_eq "dry-run runs no cell" "" "$(cat "$LOG")"

# --- filters ---------------------------------------------------------------------------------------------------
mrun --dry-run --host codex
assert_contains "host filter totals" "$TL_OUT" "RC matrix: 2 passed"
assert_eq "host filter: only codex markers" "codex-fresh codex-upgrade" "$(ls "$MK" | tr '\n' ' ' | sed 's/ $//')"
mrun --dry-run --mode upgrade
assert_contains "mode filter totals" "$TL_OUT" "RC matrix: 3 passed"
assert_eq "mode filter: only upgrade markers" "claude-upgrade codex-upgrade cursor-upgrade" "$(ls "$MK" | tr '\n' ' ' | sed 's/ $//')"
mrun --dry-run --host cursor --mode fresh
assert_contains "host+mode filter" "$TL_OUT" "RC matrix: 1 passed"
mrun --dry-run --host nosuch
assert_contains "no cell selected" "$TL_OUT" "RC matrix: 0 passed, 0 failed, 0 skipped"
assert_eq "no cell selected exits 0" 0 "$TL_STATUS"

# --- not live: structural install only ------------------------------------------------------------------------------
mrun --host codex --mode fresh
assert_eq "no live cli: ok" 0 "$TL_STATUS"
assert_eq "no live cli marker" skip "$(status_of codex-fresh)"
assert_eq "no live cli artifact" no-live-cli "$(artifact_of codex-fresh)"
assert_contains "no live cli totals" "$TL_OUT" "0 passed, 0 failed, 1 skipped"
assert_contains "cell invoked with rc scope" "$(cat "$LOG")" "cell --host codex --mode fresh --scope rc"
mrun CELL_FAIL=codex --host codex --mode fresh
assert_eq "no live cli + cell failure -> 1" 1 "$TL_STATUS"
assert_eq "cell failure marker" fail "$(status_of codex-fresh)"
assert_eq "cell failure artifact" install "$(artifact_of codex-fresh)"
assert_contains "failure totals" "$TL_OUT" "0 passed, 1 failed, 0 skipped"
mrun --host claude --mode fresh --require-live
assert_eq "--require-live without cli -> 1" 1 "$TL_STATUS"
assert_eq "require-live marker" unavailable "$(artifact_of claude-fresh)"
assert_eq "require-live runs no cell" "" "$(cat "$LOG")"
mrun SB_RC_MATRIX_REQUIRE_LIVE=1 --host cursor --mode fresh
assert_eq "require-live via env" unavailable "$(artifact_of cursor-fresh)"
# cursor: CLI present but unauthenticated is not live; authenticated is
mrun CURSOR_LIVE=1 CURSOR_AUTH=0 --host cursor --mode fresh
assert_eq "cursor unauthenticated -> not live" no-live-cli "$(artifact_of cursor-fresh)"
mrun CLAUDE_LIVE=1 CLAUDE_AUTH=0 --host claude --mode fresh
assert_eq "claude unauthenticated -> not live" no-live-cli "$(artifact_of claude-fresh)"

# --- CI mode ---------------------------------------------------------------------------------------------------------------------
mrun SB_RC_CI_MODE=1 --host claude --mode upgrade
assert_eq "ci mode: structural only" ci-no-first-party-keys "$(artifact_of claude-upgrade)"
assert_eq "ci mode: skip status" skip "$(status_of claude-upgrade)"
mrun GITHUB_ACTIONS=true --host codex --mode fresh
assert_eq "GITHUB_ACTIONS implies ci mode" ci-no-first-party-keys "$(artifact_of codex-fresh)"
mrun GITHUB_ACTIONS=true CELL_FAIL=codex --host codex --mode fresh
assert_eq "ci mode: cell failure" install "$(artifact_of codex-fresh)"
assert_eq "ci mode: failure exit" 1 "$TL_STATUS"
mrun GITHUB_ACTIONS=true --host cursor --mode fresh
assert_eq "ci mode does not skip cursor" no-live-cli "$(artifact_of cursor-fresh)"

# --- live host (stubbed CLIs) ---------------------------------------------------------------------------------------------------------
tl_stub codex 'exit 0'
mrun --host codex --mode fresh
assert_eq "live codex ok" 0 "$TL_STATUS"
assert_eq "live codex pass marker" pass "$(status_of codex-fresh)"
assert_match "live codex artifact is rc.log under the smoke root" '/sb-rc\.[A-Za-z0-9]+/codex/rc\.log$' "$(artifact_of codex-fresh)"
assert_contains "delegate smoke invoked" "$(cat "$LOG")" "delegate codex wd="
assert_contains "live totals" "$TL_OUT" "1 passed, 0 failed, 0 skipped"
mrun CELL_FAIL=codex --host codex --mode fresh
assert_eq "live host-smoke failure marker" host-smoke "$(artifact_of codex-fresh)"
assert_eq "live host-smoke failure exit" 1 "$TL_STATUS"
# several live cells with a private TMPDIR: no per-cell smoke root may be left behind
PT="$TL_TMP/private-tmp"; rm -rf "$PT"; mkdir -p "$PT"
mrun TMPDIR="$PT" --host codex
assert_eq "two live codex cells pass" 0 "$TL_STATUS"
assert_contains "two live cells totals" "$TL_OUT" "2 passed, 0 failed, 0 skipped"
assert_eq "no sb-rc.* smoke roots remain" "" "$(find "$PT" -maxdepth 1 -name 'sb-rc.*' | tr '\n' ' ')"
mrun DELEGATE_FAIL=codex --host codex --mode fresh
assert_eq "live delegate failure -> fail marker" fail "$(status_of codex-fresh)"
assert_match "live delegate failure artifact is the log" 'rc\.log$' "$(artifact_of codex-fresh)"
mrun CLAUDE_LIVE=1 CLAUDE_AUTH=1 --host claude --mode upgrade
assert_eq "live claude pass" pass "$(status_of claude-upgrade)"
mrun CURSOR_LIVE=1 CURSOR_AUTH=1 --host cursor --mode fresh
assert_eq "live cursor (no leanctx) uses delegate smoke" pass "$(status_of cursor-fresh)"
assert_contains "cursor delegate" "$(cat "$LOG")" "delegate cursor"
mrun CURSOR_LIVE=1 CURSOR_AUTH=1 LEANCTX=1 --host cursor --mode fresh
assert_eq "live cursor with leanctx" pass "$(status_of cursor-fresh)"
assert_contains "five-tool scenarios used" "$(cat "$LOG")" "fivetool $T"
assert_not_contains "delegate smoke not used with leanctx" "$(cat "$LOG")" "delegate cursor"
mrun CURSOR_LIVE=1 CURSOR_AUTH=1 LEANCTX=1 FIVETOOL_FAIL=1 --host cursor --mode fresh
assert_eq "five-tool failure marker" fail "$(status_of cursor-fresh)"
assert_eq "five-tool failure exit" 1 "$TL_STATUS"

# runtime-paths present in the repo root is sourced
mkdir -p "$T/hooks/lib"; cp "$R/hooks/lib/runtime-paths.sh" "$T/hooks/lib/"
mrun SB_RUNTIME_PRESERVE_STATE_DIR=1 --dry-run --host cursor --mode fresh
assert_eq "runtime-paths sourced: still ok" 0 "$TL_STATUS"

tl_results
