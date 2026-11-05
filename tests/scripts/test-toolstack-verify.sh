#!/usr/bin/env bash
# scripts/lib/global-toolstack/verify.sh: the post-install health report. A fully
# provisioned fake home passes; each missing/misconfigured piece is reported as a
# failure (or warning) and flips the exit code only for failures.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/toolstack-helpers.sh"
tl_init

VERIFY="$TS_SRC/verify.sh"
HOOKS=(session-bootstrap shell-compression graphify-gate agentmemory-gate rtk-gate context-mode-gate token-compression-tools-gate stack-compression-coordinator record-graphify-query record-agentmemory-usage install parity-verify verify)
RULES=(graphify.mdc agentmemory.mdc leanctx.mdc context-mode.mdc token-compression-enforcement.mdc recommended-tools.mdc)
GOOD_MANIFEST='{"schema":"five-tool-stack/v1","scope":"user-global","profile":"five_tool_routed","tools":{"graphify":{},"agentmemory":{},"context_mode":{},"leanctx":{},"rtk":{}},"hosts":{"claude":{},"codex":{},"cursor":{},"opencode":{},"pi":{}},"coordination":{"one_global_instance_per_tool":true,"rtk_rewrite":"single"}}'

# build_home <dir>: a fully provisioned fake home (manifest under the default XDG path).
build_home() {
  local h="$1" c="$1/.cursor" ts="$1/.cursor/hooks/toolstack" s r
  mkdir -p "$ts/lib/five_tool_runtime" "$c/rules" "$h/.local/state/five-tool-stack" "$c/worktrees/repo/r41j/.git" "$c/worktrees/repo/r41j/graphify-out"
  for s in "${HOOKS[@]}"; do : >"$ts/$s.sh"; chmod +x "$ts/$s.sh"; done
  chmod -x "$ts/install.sh" # install.sh only needs to exist
  : >"$ts/lib/common.sh"; : >"$ts/patch-hooks.py"; : >"$ts/patch-mcp.py"
  : >"$ts/five_tool_instances.py"; : >"$ts/fix-shell-compression-hook.py"
  : >"$ts/lib/five_tool_runtime/runtime.py"; : >"$ts/lib/five_tool_runtime/cli.py"
  for r in "${RULES[@]}"; do : >"$c/rules/$r"; done
  printf '%s\n' "$GOOD_MANIFEST" >"$h/.local/state/five-tool-stack/manifest.json"
  printf '{"mcpServers":{"graphify":{},"agentmemory":{},"context-mode":{},"leanctx":{}}}' >"$c/mcp.json"
  printf '{"hooks":{"a":"rtk hook cursor","b":"toolstack/session-bootstrap","c":"toolstack/graphify-gate","d":"toolstack/agentmemory-gate","e":"toolstack/rtk-gate","f":"toolstack/context-mode-gate","g":"toolstack/record-graphify-query","h":"toolstack/record-agentmemory-usage"}}' >"$c/hooks.json"
  printf '{}' >"$c/toolstack.json"
  : >"$c/worktrees/repo/r41j/graphify-out/graph.json"
}
# tool stubs (graphify, graphify-mcp, agentmemory, context-mode, lean-ctx, rtk) and a healthy curl
good_tools() {
  local t
  for t in graphify graphify-mcp agentmemory context-mode lean-ctx rtk curl; do tl_stub "$t" 'exit 0'; done
}
clear_tools() { rm -f "$TL_BIN"/{graphify,graphify-mcp,agentmemory,context-mode,lean-ctx,rtk,curl}; }

# Minimal PATH (no optional host tools) with only what verify.sh needs.
mini="$TL_TMP/mini-path"; mkdir -p "$mini"
for c in bash jq grep; do ln -s "$(command -v "$c")" "$mini/$c"; done

# vrun <home> [VAR=value ...]: run verify.sh in <home>. Optional host tools come from
# $TL_BIN (stubbed by good_tools); the base PATH only has bash/jq/grep.
vrun() {
  local h="$1"; shift
  tl_run env -u SB_GLOBAL_TOOLSTACK_MANIFEST -u SB_GLOBAL_TOOLSTACK_HOME -u FIVE_TOOL_STACK_HOME \
    -u XDG_STATE_HOME -u XDG_DATA_HOME -u TEST_REPO HOME="$h" PATH="$TL_BIN:$mini" "$@" bash "$VERIFY"
}
line() { # <name> <expected line>: the report contains this exact line
  assert_contains "$1" $'\n'"$TL_OUT"$'\n' $'\n'"$2"$'\n'
}

# ---------- fully provisioned ----------
good="$TL_TMP/good"; build_home "$good"; good_tools
vrun "$good"
assert_eq "healthy: exit 0" 0 "$TL_STATUS"
assert_contains "healthy: title" "$TL_OUT" "== Global toolstack verify =="
line "healthy: toolstack.json" "  [x] toolstack.json: present"
line "healthy: hook present" "  [x] hook:rtk-gate: present"
line "healthy: install.sh need not be executable" "  [x] hook:install: present"
line "healthy: lib" "  [x] lib/common.sh: present"
line "healthy: generic runtime" "  [x] generic-runtime: present"
line "healthy: manifest" "  [x] global-instances: five-tool manifest present"
line "healthy: rule" "  [x] rule:recommended-tools.mdc: present"
line "healthy: graphify cli path" "  [x] graphify-cli: $TL_BIN/graphify"
line "healthy: lean-ctx path" "  [x] lean-ctx: $TL_BIN/lean-ctx"
line "healthy: mcp wired" "  [x] mcp:leanctx: wired"
line "healthy: standalone absent" "  [x] mcp:no_standalone: removed"
line "healthy: hooks wired" "  [x] hooks:record-agentmemory: wired"
line "healthy: legacy wrapper removed" "  [x] hooks:legacy-shell-wrapper: removed"
line "healthy: server" "  [x] agentmemory-server: healthy"
line "healthy: index" "  [x] graphify-index: present in test repo"
assert_contains "healthy: summary" "$TL_OUT" "Summary: 51 passed, 0 failed, 0 warnings"
assert_eq "healthy: no failed or warning lines" 0 "$(grep -cE '^  \[( |!)\]' <<<"$TL_OUT" || true)"

# ---------- warnings do not fail the run ----------
rm -f "$TL_BIN/graphify-mcp" "$TL_BIN/curl"
rm -f "$good/.cursor/worktrees/repo/r41j/graphify-out/graph.json"
vrun "$good"
assert_eq "warnings only: exit 0" 0 "$TL_STATUS"
line "warn: graphify-mcp" "  [!] graphify-mcp: not on PATH"
line "warn: server" "  [!] agentmemory-server: not healthy — start agentmemory"
line "warn: index" "  [!] graphify-index: missing in $good/.cursor/worktrees/repo/r41j"
assert_contains "warn: summary" "$TL_OUT" "Summary: 48 passed, 0 failed, 3 warnings"
# a TEST_REPO override that is not a git checkout is skipped; one with a graph passes
mkdir -p "$TL_TMP/other-repo/.git" "$TL_TMP/other-repo/graphify-out"; : >"$TL_TMP/other-repo/graphify-out/graph.json"
vrun "$good" TEST_REPO="$TL_TMP/other-repo"
line "TEST_REPO override" "  [x] graphify-index: present in test repo"
vrun "$good" TEST_REPO="$TL_TMP/not-a-repo"
assert_not_contains "TEST_REPO without .git is skipped" "$TL_OUT" "graphify-index"
good_tools

# ---------- nothing installed ----------
clear_tools
empty="$TL_TMP/empty"; mkdir -p "$empty"
vrun "$empty"
assert_eq "empty home: exit 1" 1 "$TL_STATUS"
for l in "toolstack.json: missing" "hook:session-bootstrap: missing" "hook:install: missing" "hook:verify: missing" \
  "lib/common.sh: missing" "patch-hooks.py: missing" "patch-mcp.py: missing" "five_tool_instances.py: missing" \
  "generic-runtime: missing" "generic-runtime-cli: missing" "fix-shell-compression-hook.py: missing" \
  "global-instances: five-tool manifest missing or incomplete" "rule:graphify.mdc: missing" "rule:recommended-tools.mdc: missing" \
  "graphify-cli: not on PATH" "agentmemory-cli: not on PATH" "context-mode: not on PATH" "lean-ctx: not on PATH" "rtk: not on PATH" \
  "mcp.json: missing" "hooks.json: missing"; do
  line "empty: $l" "  [ ] $l"
done
line "empty: graphify-mcp only warns" "  [!] graphify-mcp: not on PATH"
line "empty: server only warns" "  [!] agentmemory-server: not healthy — start agentmemory"
assert_not_contains "empty: no test repo check" "$TL_OUT" "graphify-index"
assert_contains "empty: summary" "$TL_OUT" "Summary: 0 passed, 35 failed, 2 warnings"
assert_eq "empty: nothing passes" 0 "$(grep -c '^  \[x\]' <<<"$TL_OUT" || true)"

# ---------- mcp.json / hooks.json present but wrong ----------
bad="$TL_TMP/bad"; build_home "$bad"; good_tools
printf '{"mcpServers":{"lean-ctx-standalone":{}}}' >"$bad/.cursor/mcp.json"
printf '{"hooks":{"x":"toolstack/shell-compression"}}' >"$bad/.cursor/hooks.json"
vrun "$bad"
assert_eq "wrong wiring: exit 1" 1 "$TL_STATUS"
for l in "mcp:graphify: missing" "mcp:agentmemory: missing" "mcp:context-mode: missing" "mcp:leanctx: missing" \
  "mcp:lean-ctx-standalone: still present" "hooks:session-bootstrap: missing" "hooks:shell-compression: missing" \
  "hooks:legacy-shell-wrapper: still wired" "hooks:rtk: missing" "hooks:graphify-gate: missing" "hooks:agentmemory-gate: missing" \
  "hooks:rtk-gate: missing" "hooks:context-mode-gate: missing" "hooks:record-graphify: missing" "hooks:record-agentmemory: missing"; do
  line "wrong wiring: $l" "  [ ] $l"
done

# ---------- each hook / file removed individually ----------
for s in "${HOOKS[@]}"; do
  [[ "$s" == install ]] && continue
  h="$TL_TMP/nohook-$s"; build_home "$h"; rm "$h/.cursor/hooks/toolstack/$s.sh"
  vrun "$h"
  assert_eq "hook $s absent: exit 1" 1 "$TL_STATUS"
  line "hook $s absent" "  [ ] hook:$s: missing"
done
h="$TL_TMP/noinstall"; build_home "$h"; rm "$h/.cursor/hooks/toolstack/install.sh"
vrun "$h"; line "install.sh absent" "  [ ] hook:install: missing"
h="$TL_TMP/nonexec"; build_home "$h"; chmod -x "$h/.cursor/hooks/toolstack/rtk-gate.sh"
vrun "$h"; line "non-executable hook is reported" "  [ ] hook:rtk-gate: missing"
h="$TL_TMP/nomcp-cli"; build_home "$h"; rm "$TL_BIN/agentmemory"
vrun "$h"; line "agentmemory CLI absent" "  [ ] agentmemory-cli: not on PATH"
good_tools

# ---------- manifest location precedence ----------
mhome="$TL_TMP/mhome"; build_home "$mhome"; rm "$mhome/.local/state/five-tool-stack/manifest.json"
vrun "$mhome"; line "no manifest anywhere" "  [ ] global-instances: five-tool manifest missing or incomplete"
mk_manifest() { mkdir -p "$(dirname "$1")"; printf '%s\n' "${2:-$GOOD_MANIFEST}" >"$1"; }
mk_manifest "$TL_TMP/m1/custom.json"
vrun "$mhome" SB_GLOBAL_TOOLSTACK_MANIFEST="$TL_TMP/m1/custom.json"
line "SB_GLOBAL_TOOLSTACK_MANIFEST" "  [x] global-instances: five-tool manifest present"
mk_manifest "$TL_TMP/m2/instances.json"
vrun "$mhome" SB_GLOBAL_TOOLSTACK_HOME="$TL_TMP/m2"
line "SB_GLOBAL_TOOLSTACK_HOME/instances.json" "  [x] global-instances: five-tool manifest present"
mk_manifest "$TL_TMP/m3/manifest.json"
vrun "$mhome" FIVE_TOOL_STACK_HOME="$TL_TMP/m3"
line "FIVE_TOOL_STACK_HOME/manifest.json" "  [x] global-instances: five-tool manifest present"
mk_manifest "$TL_TMP/m4/five-tool-stack/manifest.json"
vrun "$mhome" XDG_STATE_HOME="$TL_TMP/m4"
line "XDG_STATE_HOME" "  [x] global-instances: five-tool manifest present"
mk_manifest "$TL_TMP/m5/five-tool-stack/manifest.json"
vrun "$mhome" XDG_DATA_HOME="$TL_TMP/m5"
line "XDG_DATA_HOME" "  [x] global-instances: five-tool manifest present"
vrun "$mhome" XDG_STATE_HOME="$TL_TMP/m4" XDG_DATA_HOME="$TL_TMP/nowhere"
line "XDG_STATE_HOME wins over XDG_DATA_HOME" "  [x] global-instances: five-tool manifest present"
mk_manifest "$mhome/.local/state/five-tool-stack/manifest.json"
vrun "$mhome" SB_GLOBAL_TOOLSTACK_MANIFEST="$TL_TMP/none.json"
line "explicit manifest path wins even when missing" "  [ ] global-instances: five-tool manifest missing or incomplete"
vrun "$mhome" SB_GLOBAL_TOOLSTACK_HOME="$TL_TMP/nowhere" FIVE_TOOL_STACK_HOME="$TL_TMP/m3"
line "SB_GLOBAL_TOOLSTACK_HOME wins over FIVE_TOOL_STACK_HOME" "  [ ] global-instances: five-tool manifest missing or incomplete"
vrun "$mhome"
line "default XDG location under HOME" "  [x] global-instances: five-tool manifest present"

# ---------- incomplete manifests ----------
check_bad_manifest() { # <name> <jq filter applied to the good manifest>
  mk_manifest "$TL_TMP/bm/manifest.json" "$(jq -c "$2" <<<"$GOOD_MANIFEST")"
  vrun "$mhome" FIVE_TOOL_STACK_HOME="$TL_TMP/bm"
  assert_eq "manifest $1: exit 1" 1 "$TL_STATUS"
  line "manifest $1" "  [ ] global-instances: five-tool manifest missing or incomplete"
}
check_bad_manifest "wrong schema" '.schema = "other"'
check_bad_manifest "wrong scope" '.scope = "project"'
check_bad_manifest "wrong profile" '.profile = "x"'
check_bad_manifest "missing tool" 'del(.tools.rtk)'
check_bad_manifest "missing host" 'del(.hosts.pi)'
check_bad_manifest "several instances" '.coordination.one_global_instance_per_tool = false'
check_bad_manifest "multiple rtk rewrites" '.coordination.rtk_rewrite = "multiple"'
printf 'not json' >"$TL_TMP/bm/manifest.json"
vrun "$mhome" FIVE_TOOL_STACK_HOME="$TL_TMP/bm"
line "manifest not JSON" "  [ ] global-instances: five-tool manifest missing or incomplete"

tl_results
