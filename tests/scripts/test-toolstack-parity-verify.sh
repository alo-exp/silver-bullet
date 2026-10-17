#!/usr/bin/env bash
# scripts/lib/global-toolstack/parity-verify.sh: scorecard of the global
# toolstack (config, hooks, rules, MCP/hooks wiring, CLIs, SB parity).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/toolstack-helpers.sh"
tl_init

SCRIPT="$TS_SRC/parity-verify.sh"
CUR="$HOME/.cursor"
TSD="$CUR/hooks/toolstack"
SBREPO="$TL_TMP/sbrepo"

good_config() {
  cat >"$CUR/toolstack.json" <<'JSON'
{"enforcement":"always","sb_parity":true,"profile":"five_tool_routed",
 "shell_compression":{"primary":"rtk","fallback":"leanctx"},
 "routes":{"sb_wire":"leanctx","sb_read":"leanctx","sb_grep":"context_mode","sb_shell":"rtk","sb_slice":"context_mode","sb_webfetch":"context_mode","sb_graph":"graphify","sb_remember":"agentmemory","sb_pathjail":"leanctx","sb_injection":"leanctx"},
 "tools":{"graphify":{"required":true,"graph_path":"graphify-out/graph.json","query_ttl_seconds":1800,"query_budget":2000},
          "agentmemory":{"required":true,"usage_ttl_seconds":1800,"export_root":".agentmemory"},
          "context_mode":{"required":true},"leanctx":{"required":true},"rtk":{"required":true}}}
JSON
}
good_state() {
  rm -rf "$CUR" "$SBREPO"
  mkdir -p "$TSD/lib" "$CUR/rules" "$SBREPO"
  good_config
  local h
  for h in session-bootstrap shell-compression graphify-gate agentmemory-gate rtk-gate context-mode-gate token-compression-tools-gate stack-compression-coordinator record-graphify-query record-agentmemory-usage; do
    printf '#!/bin/sh\n' >"$TSD/$h.sh"; chmod +x "$TSD/$h.sh"
  done
  : >"$TSD/lib/common.sh"
  local r
  for r in graphify agentmemory leanctx context-mode token-compression-enforcement recommended-tools; do : >"$CUR/rules/$r.mdc"; done
  cat >"$CUR/mcp.json" <<'JSON'
{"mcpServers":{"graphify":{},"agentmemory":{},"context-mode":{},"leanctx":{"env":{"LEANCTX_DISABLE_SHELL_MCP":"1","prefix":"lctx_"}}}}
JSON
  cat >"$CUR/hooks.json" <<'JSON'
{"hooks":{"preToolUse":[
 {"command":"rtk hook cursor"},
 {"command":"context-mode hook cursor pretooluse"},
 {"command":"~/.cursor/hooks/toolstack/graphify-gate.sh"},
 {"command":"~/.cursor/hooks/toolstack/agentmemory-gate.sh"},
 {"command":"~/.cursor/hooks/toolstack/rtk-gate.sh"},
 {"command":"~/.cursor/hooks/toolstack/context-mode-gate.sh"},
 {"command":"~/.cursor/hooks/toolstack/stack-compression-coordinator.sh"},
 {"command":"~/.cursor/hooks/toolstack/token-compression-tools-gate.sh"},
 {"command":"~/.cursor/hooks/toolstack/session-bootstrap.sh"}]}}
JSON
  printf '{"recommended_tools":{"graphify":{"query_budget":2000},"agentmemory":{"export_root":".agentmemory"}}}' >"$SBREPO/.silver-bullet.json"
}
break_state() {
cat >"$CUR/toolstack.json" <<'JSON'
{"enforcement":"off","sb_parity":false,"profile":"other",
 "shell_compression":{"primary":"x","fallback":"y"},
 "routes":{"sb_wire":"a","sb_read":"a","sb_grep":"a","sb_shell":"a","sb_slice":"a","sb_webfetch":"a","sb_graph":"a","sb_remember":"a","sb_pathjail":"a","sb_injection":"a"},
 "tools":{"leanctx_standalone":{},"graphify":{"graph_path":"g.json","query_ttl_seconds":1,"query_budget":3},"agentmemory":{"export_root":"mem","usage_ttl_seconds":2}}}
JSON
rm -f "$TSD"/*.sh "$TSD/lib/common.sh" "$CUR/rules/"*.mdc
printf '{"mcpServers":{"lean-ctx-standalone":{}}}' >"$CUR/mcp.json"
cat >"$CUR/hooks.json" <<'JSON'
{"hooks":[{"command":"~/.cursor/hooks/toolstack/shell-compression.sh"},{"command":"lean-ctx hook rewrite"}]}
JSON
}
run_pv() { TOOLSTACK_REPO_ROOT="$SBREPO" tl_run bash "$SCRIPT"; }

for c in graphify agentmemory context-mode lean-ctx rtk; do tl_stub "$c" 'exit 0'; done

# --- fully healthy ---
good_state
run_pv
assert_eq "healthy exits 0" 0 "$TL_STATUS"
assert_contains "healthy banner" "$TL_OUT" "== Global toolstack parity verify (SB five_tool_routed) =="
assert_contains "healthy summary" "$TL_OUT" "0 failed, 0 warnings"
assert_not_contains "no failing line" "$TL_OUT" "  [ ]"
assert_contains "config pass" "$TL_OUT" "[x] config: exists"
assert_contains "route checked" "$TL_OUT" "[x] route:sb_shell: rtk"
assert_contains "rtk-before-cm order" "$TL_OUT" "[x] hooks:rtk_before_cm: order"
assert_contains "SB parity budget" "$TL_OUT" "[x] parity:query_budget: 2000"
assert_contains "SB parity export root" "$TL_OUT" "[x] parity:export_root: .agentmemory"
assert_contains "mcp wired" "$TL_OUT" "[x] mcp:leanctx: wired"

# --- everything wrong ---
good_state
break_state
rm -f "$TL_BIN/graphify" "$TL_BIN/agentmemory" "$TL_BIN/context-mode" "$TL_BIN/lean-ctx" "$TL_BIN/rtk"
run_pv
assert_eq "broken exits 1" 1 "$TL_STATUS"
for want in "[ ] enforcement: not always" "[ ] sb_parity: not true" "[ ] profile: other" "[ ] shell_primary: x" "[ ] shell_fallback: y" \
  "[ ] route:sb_wire: got=a want=leanctx" "[ ] route:sb_grep: got=a want=context_mode" "[ ] route:sb_shell: got=a want=rtk" \
  "[ ] route:sb_graph: got=a want=graphify" "[ ] route:sb_remember: got=a want=agentmemory" \
  "[ ] graph_path: g.json" "[ ] graphify_ttl: 1" "[ ] graphify_budget: 3" "[ ] export_root: mem" "[ ] agentmemory_ttl: 2" \
  "[ ] no_standalone_tool: leanctx_standalone present" "[ ] required:graphify: null" "[ ] required:rtk: null" \
  "[ ] hook:graphify-gate: missing" "[ ] hook:session-bootstrap: missing" "[ ] common.sh: missing" "[ ] rule:graphify.mdc: missing" "[ ] rule:recommended-tools.mdc: missing" \
  "[ ] mcp:graphify: missing" "[ ] mcp:agentmemory: missing" "[ ] mcp:context-mode: missing" "[ ] mcp:leanctx: missing" \
  "[ ] mcp:no_standalone: still present" "[ ] leanctx:shell_off: missing" "[!] leanctx:prefix: check env" \
  "[ ] hooks:shell_compression: missing" "[ ] hooks:legacy_shell_wrapper: still wired" "[ ] hooks:no_leanctx_rewrite: still present" \
  "[ ] hooks:graphify_gate: missing" "[ ] hooks:agentmemory_gate: missing" "[ ] hooks:rtk_gate: missing" "[ ] hooks:cm_gate: missing" \
  "[ ] hooks:coordinator: missing" "[ ] hooks:token_gate: missing" "[ ] hooks:session_bootstrap: missing" "[ ] hooks:rtk_before_cm: rtk= cm=" \
  "[ ] cli:graphify: missing" "[ ] cli:agentmemory: missing" "[ ] cli:context-mode: missing" "[ ] cli:lean-ctx: missing" "[ ] cli:rtk: missing" \
  "[ ] parity:query_budget: sb=2000 ts=3" "[ ] parity:export_root: sb=.agentmemory"; do
  assert_contains "broken: $want" "$TL_OUT" "$want"
done

# --- missing files entirely ---
good_state
rm -f "$CUR/toolstack.json" "$CUR/mcp.json" "$CUR/hooks.json" "$SBREPO/.silver-bullet.json"
for c in graphify agentmemory context-mode lean-ctx rtk; do tl_stub "$c" 'exit 0'; done
run_pv
assert_eq "missing config exits 1" 1 "$TL_STATUS"
assert_contains "config missing" "$TL_OUT" "[ ] config: missing"
assert_contains "mcp.json missing" "$TL_OUT" "[ ] mcp.json: missing"
assert_contains "hooks.json missing" "$TL_OUT" "[ ] hooks.json: missing"
assert_not_contains "no SB parity without .silver-bullet.json" "$TL_OUT" "parity:query_budget"

# --- hook order: context-mode listed before rtk fails ---
good_state
cat >"$CUR/hooks.json" <<'JSON'
{"hooks":[{"command":"context-mode hook cursor pretooluse"},
 {"command":"rtk hook cursor"},
 {"command":"toolstack/graphify-gate"},{"command":"toolstack/agentmemory-gate"},{"command":"toolstack/rtk-gate"},
 {"command":"toolstack/context-mode-gate"},{"command":"toolstack/stack-compression-coordinator"},
 {"command":"toolstack/token-compression-tools-gate"},{"command":"toolstack/session-bootstrap"}]}
JSON
run_pv
assert_eq "wrong hook order exits 1" 1 "$TL_STATUS"
assert_contains "order violation reported" "$TL_OUT" "[ ] hooks:rtk_before_cm: rtk=2 cm=1"

# --- default SB repo root falls back under ~/.cursor/worktrees (absent => no parity checks) ---
good_state
tl_run bash "$SCRIPT"
assert_eq "default SB root absent still passes" 0 "$TL_STATUS"
assert_not_contains "default root: no parity section" "$TL_OUT" "parity:query_budget"
mkdir -p "$CUR/worktrees/repo/r41j"
printf '{"recommended_tools":{"graphify":{"query_budget":2000},"agentmemory":{"export_root":".agentmemory"}}}' >"$CUR/worktrees/repo/r41j/.silver-bullet.json"
tl_run bash "$SCRIPT"
assert_contains "default SB root is ~/.cursor/worktrees/repo/r41j" "$TL_OUT" "[x] parity:query_budget: 2000"

# --- one process scoring a healthy and then a broken stack (both outcomes of every check) ---
export CUR TSD SBREPO
export -f break_state
good_state
for c in graphify agentmemory context-mode lean-ctx rtk; do tl_stub "$c" 'exit 0'; done
TOOLSTACK_REPO_ROOT="$SBREPO" tl_run bash -c 'source "$1" || true; echo "=== second pass ==="; break_state; source "$1" || true' _ "$SCRIPT"
first="${TL_OUT%%=== second pass ===*}"
second="${TL_OUT##*=== second pass ===}"
assert_contains "double run: first pass healthy" "$first" "0 failed, 0 warnings"
assert_contains "double run: first pass parity ok" "$first" "[x] parity:export_root: .agentmemory"
assert_contains "double run: second pass broken budget parity" "$second" "[ ] parity:query_budget: sb=2000 ts=3"
assert_contains "double run: second pass broken export parity" "$second" "[ ] parity:export_root: sb=.agentmemory"
assert_not_contains "double run: second pass not healthy" "$second" "0 failed"

tl_results
