#!/usr/bin/env bash
# scripts/enable-alumnium.sh and scripts/enable-rtk-context-mode.sh: the
# verification runbooks. Each script is staged into a throwaway "repo" (with the
# real hooks/lib linked in) so the project files they read are under test control
# and nothing is installed or fetched: npm/rtk/node are stubs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

STAGE="$TL_TMP/repo"
mkdir -p "$STAGE/scripts"
ln -s "$TL_REPO_ROOT/hooks" "$STAGE/hooks"
cp "$TL_REPO_ROOT/scripts/enable-alumnium.sh" "$TL_REPO_ROOT/scripts/enable-rtk-context-mode.sh" "$STAGE/scripts/"
ALU="$STAGE/scripts/enable-alumnium.sh"
RCM="$STAGE/scripts/enable-rtk-context-mode.sh"
printf '{}\n' >"$STAGE/.silver-bullet.json"

# ---------------------------------------------------------------- alumnium
HOST_NAME="$SB_RUNTIME_NAME"
ART="$TL_TMP/alumnium-mcp.json"
export SB_ALUMNIUM_MCP_ARTIFACT="$ART"

tl_stub npx 'exit 0'
tl_stub npm 'if [[ "$1" == view ]]; then echo 9.9.9; exit 0; fi; exit 1'
printf '{"mcpServers":{"alumnium":{}}}\n' >"$ART"
tl_run bash "$ALU"
assert_eq "alumnium: all good exits 0" "0" "$TL_STATUS"
assert_contains "alumnium: npm reachable with version" "$TL_OUT" "[x] npm package reachable (alumnium@9.9.9)"
assert_contains "alumnium: MCP wired line names host and artifact" "$TL_OUT" "[x] MCP wired (${HOST_NAME}: ${ART})"
assert_contains "alumnium: summary" "$TL_OUT" "=== Summary: 2 passed, 0 failed ==="

# npm view works for the gate but then fails for the version lookup -> "unknown"
tl_stub npm 'if [[ "$2" == alumnium && -f "$TL_MARK" ]]; then exit 1; fi; if [[ "$1" == view ]]; then touch "$TL_MARK"; exit 0; fi; exit 1'
export TL_MARK="$TL_TMP/npm-mark"
tl_run bash "$ALU"
assert_contains "alumnium: version falls back to unknown" "$TL_OUT" "alumnium@unknown"
rm -f "$TL_MARK"

# registry unreachable and MCP not wired
tl_stub npm 'exit 1'
rm -f "$ART"
tl_run bash "$ALU"
assert_eq "alumnium: failures exit 1" "1" "$TL_STATUS"
assert_contains "alumnium: unreachable npm reported" "$TL_OUT" "[ ] alumnium npm package not reachable — npm install -g alumnium or check network"
assert_contains "alumnium: unwired MCP reported" "$TL_OUT" "[ ] MCP not wired (${HOST_NAME}) — see docs/ALUMNIUM.md"
assert_contains "alumnium: failing summary" "$TL_OUT" "=== Summary: 0 passed, 2 failed ==="

# npx absent altogether
NOPATH="$(tl_path_without npx npm)"
tl_run env PATH="$NOPATH" bash "$ALU"
assert_eq "alumnium: no npx exits 1" "1" "$TL_STATUS"
assert_contains "alumnium: no npx reported" "$TL_OUT" "alumnium npm package not reachable"

# artifact present but mentioning nothing of alumnium
printf '{"mcpServers":{"other":{}}}\n' >"$ART"
tl_run bash "$ALU"
assert_contains "alumnium: unrelated artifact is not wiring" "$TL_OUT" "MCP not wired"
unset SB_ALUMNIUM_MCP_ARTIFACT TL_MARK

# ------------------------------------------------------- rtk + context mode
export SILVER_BULLET_RUNTIME=cursor
mkdir -p "$HOME/.cursor"
printf '{"hooks":{"preToolUse":[{"command":"rtk hook cursor"}]}}\n' >"$HOME/.cursor/hooks.json"
printf '{"mcpServers":{"context-mode":{}}}\n' >"$HOME/.cursor/mcp.json"
printf '# SB\n<!-- BEGIN context-mode hint (do not edit) -->\nuse ctx_execute\n<!-- END context-mode hint (do not edit) -->\n' >"$STAGE/silver-bullet.md"
tl_stub rtk 'case "$1" in --version) echo "rtk 0.42.3";; esac; exit 0'
tl_stub node 'echo v22.9.0'
tl_stub context-mode 'exit 0'

tl_run bash "$RCM"
assert_eq "rcm: healthy stack exits 0" "0" "$TL_STATUS"
assert_contains "rcm: rtk binary" "$TL_OUT" "[x] binary present: rtk 0.42.3"
assert_contains "rcm: rtk version" "$TL_OUT" "[x] version OK (v0.4x)"
assert_contains "rcm: rtk hook" "$TL_OUT" "[x] host hook wired (cursor: ${HOME}/.cursor/hooks.json)"
assert_contains "rcm: node" "$TL_OUT" "[x] Node 22.9.0 (>= 22.5)"
assert_contains "rcm: cli" "$TL_OUT" "[x] CLI or Claude plugin present"
assert_contains "rcm: artifact" "$TL_OUT" "[x] platform artifact (cursor: ${HOME}/.cursor/mcp.json)"
assert_contains "rcm: fragment" "$TL_OUT" "[x] instruction fragment in project docs"
assert_contains "rcm: summary" "$TL_OUT" "=== Summary: 7 passed, 0 failed, 0 hints ==="
assert_contains "rcm: header names the repo" "$TL_OUT" "=== RTK + Context Mode verification (repo: ${STAGE}) ==="

# --tool selects one half
tl_run bash "$RCM" --tool rtk
assert_contains "rcm --tool rtk: rtk section" "$TL_OUT" "RTK:"
assert_not_contains "rcm --tool rtk: no context mode section" "$TL_OUT" "Context Mode:"
assert_contains "rcm --tool rtk: summary" "$TL_OUT" "3 passed, 0 failed"
tl_run bash "$RCM" --tool context_mode
assert_not_contains "rcm --tool context_mode: no rtk section" "$TL_OUT" "RTK:"
assert_contains "rcm --tool context_mode: summary" "$TL_OUT" "4 passed, 0 failed"

# help and argument errors
tl_run bash "$RCM" --help
assert_eq "rcm --help exits 0" "0" "$TL_STATUS"
assert_contains "rcm --help usage" "$TL_OUT" "Usage: bash scripts/enable-rtk-context-mode.sh [--tool rtk|context_mode|all]"
tl_run bash "$RCM" -h
assert_eq "rcm -h exits 0" "0" "$TL_STATUS"
tl_run bash "$RCM" --bogus
assert_eq "rcm unknown arg exits 2" "2" "$TL_STATUS"
assert_contains "rcm unknown arg message" "$TL_ERR" "Unknown arg: --bogus"
tl_run bash "$RCM" --tool nonsense
assert_eq "rcm invalid tool exits 2" "2" "$TL_STATUS"
assert_contains "rcm invalid tool message" "$TL_ERR" "Invalid --tool: nonsense (use rtk|context_mode|all)"
tl_run bash "$RCM" --tool
assert_contains "rcm --tool without value defaults to all" "$TL_OUT" "Context Mode:"

# rtk degraded: too old, hook missing
tl_stub rtk 'case "$1" in --version) echo "rtk 0.30.1";; esac; exit 0'
rm -f "$HOME/.cursor/hooks.json"
tl_run bash "$RCM" --tool rtk
assert_eq "rcm: failing checks exit 1" "1" "$TL_STATUS"
assert_contains "rcm: too old" "$TL_OUT" "[ ] version too old — upgrade to rtk >= 0.42.0"
assert_contains "rcm: hook missing" "$TL_OUT" "[ ] host hook missing (cursor) — run rtk init for host — see docs/RTK.md"
assert_contains "rcm: failure notice on stderr" "$TL_ERR" "Some checks failed. Resolve [ ] lines and re-run."

# wrong rtk binary on PATH (gain --help fails)
tl_stub rtk 'if [[ "$1" == gain ]]; then exit 1; fi; echo "rtk 0.42.0"'
tl_run bash "$RCM" --tool rtk
assert_contains "rcm: wrong binary" "$TL_OUT" "[ ] wrong rtk binary on PATH — install rtk-ai/rtk; rtk gain --help must succeed"
assert_not_contains "rcm: wrong binary has no version complaint" "$TL_OUT" "version too old"

# rtk absent
NOPATH="$(tl_path_without rtk)"
rm -f "$TL_BIN/rtk"
tl_run env PATH="$NOPATH" bash "$RCM" --tool rtk
assert_contains "rcm: rtk missing" "$TL_OUT" "[ ] rtk not on PATH — brew tap rtk-ai/rtk && brew install rtk"

# context mode degraded: old node, no cli, no artifact, no fragment -> hint only
tl_stub node 'echo v18.1.0'
rm -f "$HOME/.cursor/mcp.json" "$TL_BIN/context-mode" "$STAGE/silver-bullet.md"
NOPATH="$(tl_path_without context-mode)"
tl_run env PATH="$NOPATH" bash "$RCM" --tool context_mode
assert_eq "rcm: context mode failures exit 1" "1" "$TL_STATUS"
assert_contains "rcm: node too old" "$TL_OUT" "[ ] Node too old or missing — upgrade to Node >= 22.5"
assert_contains "rcm: cli missing" "$TL_OUT" "[ ] context-mode not installed — npm install -g context-mode or Claude plugin"
assert_contains "rcm: artifact missing" "$TL_OUT" "[ ] MCP/plugin not wired (cursor) — see docs/CONTEXT-MODE.md"
assert_contains "rcm: fragment hint" "$TL_OUT" "[!] instruction fragment missing"
assert_contains "rcm: summary counts hints" "$TL_OUT" "0 passed, 3 failed, 1 hints"

# a missing fragment alone is only a hint: exit 0
tl_stub node 'echo v23.0.0'
tl_stub context-mode 'exit 0'
printf '{"mcpServers":{"context-mode":{}}}\n' >"$HOME/.cursor/mcp.json"
tl_run bash "$RCM" --tool context_mode
assert_eq "rcm: hint alone does not fail" "0" "$TL_STATUS"
assert_contains "rcm: hint counted" "$TL_OUT" "3 passed, 0 failed, 1 hints"

# host cannot be resolved by the runtime helper: falls back to cursor
unset SILVER_BULLET_RUNTIME
tl_run env -u SILVER_BULLET_RUNTIME PATH="$PATH" bash -c 'cd "$1" && bash "$2" --tool context_mode' _ "$STAGE" "$RCM"
assert_contains "rcm: unset runtime still resolves a host" "$TL_OUT" "Context Mode:"

tl_results
