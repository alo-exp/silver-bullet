#!/usr/bin/env bash
# Fault-injection tests for the opt-in tool gate hooks: behavior when a sourced library
# is unavailable (symlink farm without it), when cat fails, and when the project-active
# helper reports the project as not initiated.
set -euo pipefail
# The opt-in gates act only on the user's own consent, never on .silver-bullet.json alone.
# shellcheck source=../lib/consent-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/consent-helpers.sh"
sb_test_consent_grant_all
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
unset SB_AGENT_CERT_RUN SB_KAY_HOOK_BRIDGE_INVOKED
source "$TL_REPO_ROOT/tests/lib/c-toolgates-1-helpers.sh"
gh_init_project
REAL_REPO="$GH_REPO"

cfg() { # tool-id
  jq -n --arg t "$1" '{config_version:"1", sb_initiated:true, recommended_tools:{($t):{enabled_by_user:true}}}' >"$GH_CFG"
}
# name | hook | tool id | edit path
GATES=(
  "agentmemory|hooks/agentmemory-gate.sh|agentmemory|$GH_PROJ/src/app.js"
  "alumnium|hooks/alumnium-gate.sh|alumnium|$GH_PROJ/e2e/login.spec.ts"
  "context-mode|hooks/context-mode-gate.sh|context_mode|$GH_PROJ/src/app.js"
  "graphify|hooks/graphify-gate.sh|graphify|$GH_PROJ/src/app.js"
  "leanctx|hooks/leanctx-gate.sh|leanctx|$GH_PROJ/src/app.js"
)

for entry in "${GATES[@]}"; do
  IFS='|' read -r name hook tool edit_path <<<"$entry"
  cfg "$tool"
  edit="$(gh_edit_input "$edit_path")"

  GH_REPO="$REAL_REPO" gh_run "$hook" "$edit"
  assert_gate_denies "$name: baseline (nothing installed) denies" ""

  # no lib dir at all: nothing can be evaluated, hook fails open
  gh_farm "$name-nolib" "$hook" -
  GH_REPO="$GH_FARM" gh_run "$hook" "$edit"
  assert_gate_allows "$name: no libraries available fails open"

  # without hook-audit.sh the deny is still emitted
  gh_farm "$name-noaudit" "$hook" hook-audit.sh
  GH_REPO="$GH_FARM" gh_run "$hook" "$edit"
  assert_gate_denies "$name: deny survives missing audit library" ""

  # without tool-input.sh the hook reads the payload with jq itself
  gh_farm "$name-notoolinput" "$hook" tool-input.sh
  GH_REPO="$GH_FARM" gh_run "$hook" "$edit"
  assert_gate_denies "$name: payload parsed via jq without tool-input library" ""
  # Alumnium only guards browser work, so its gated command is a browser-tool run
  gated_cmd="git commit -m x"; [[ "$name" == alumnium ]] && gated_cmd="npx playwright test"
  GH_REPO="$GH_FARM" gh_run "$hook" "$(gh_bash_input "$gated_cmd")"
  assert_gate_denies "$name: command parsed via jq without tool-input library" ""

  # project-active helper says "not initiated": allow
  gh_farm "$name-inactive" "$hook" project-active.sh
  printf 'sb_project_active() { return 1; }\nsb_project_is_initiated() { return 1; }\n' >"$GH_FARM/hooks/lib/project-active.sh"
  GH_REPO="$GH_FARM" gh_run "$hook" "$edit"
  assert_gate_allows "$name: uninitiated project allows"

  # no project-gate library: the hook cannot locate its project and stays inert
  gh_farm "$name-nogate" "$hook" sb-project-gate.sh project-active.sh
  GH_REPO="$GH_FARM" gh_run "$hook" "$edit"
  assert_gate_allows "$name: missing project-gate library fails open"

  # project search: walks up from a nested directory (the real project-gate library)
  gh_farm "$name-search" "$hook"
  NEST="$TL_TMP/nest-$name"; rm -rf "$NEST"
  mkdir -p "$NEST/only-json/a/b" "$NEST/only-md/a/b" "$NEST/both/a/b" "$NEST/none/a/b"
  cp "$GH_CFG" "$NEST/only-json/.silver-bullet.json"
  cp "$GH_CFG" "$NEST/both/.silver-bullet.json"
  printf '# SB\n' >"$NEST/only-md/silver-bullet.md"
  printf '# SB\n' >"$NEST/both/silver-bullet.md"
  GH_CWD="$NEST/only-json/a/b" GH_PROJECT_ROOT="" GH_REPO="$GH_FARM" gh_run "$hook" "$edit"
  assert_gate_allows "$name: parent with only .silver-bullet.json is not a project"
  GH_CWD="$NEST/only-md/a/b" GH_PROJECT_ROOT="" GH_REPO="$GH_FARM" gh_run "$hook" "$edit"
  assert_gate_allows "$name: parent with only silver-bullet.md is not a project"
  GH_CWD="$NEST/none/a/b" GH_PROJECT_ROOT="" GH_REPO="$GH_FARM" gh_run "$hook" "$edit"
  assert_gate_allows "$name: no markers anywhere allows"
  GH_CWD="$NEST/both/a/b" GH_PROJECT_ROOT="" GH_REPO="$GH_FARM" gh_run "$hook" "$edit"
  assert_gate_denies "$name: both markers in a parent make it the project (normal decision)" ""
  mkdir -p "$NEST/both/a/b/.git"
  GH_CWD="$NEST/both/a/b" GH_PROJECT_ROOT="" GH_REPO="$GH_FARM" gh_run "$hook" "$edit"
  assert_gate_allows "$name: search stops at a .git directory below the project root"
  rm -rf "$NEST/both/a/b/.git"

  # cat failing: no input, fail-open
  tl_stub cat 'exit 1'; hash -r
  GH_REPO="$REAL_REPO" gh_run "$hook" "$edit"
  assert_gate_allows "$name: unreadable stdin allows"
  rm -f "$TL_BIN/cat"; hash -r
done

# ---- compression-marker-guard ----
MG=hooks/compression-marker-guard.sh
marker="$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{new_string:"[lean-ctx: x]"}}')"
gh_farm mg-nolib "$MG" -
GH_REPO="$GH_FARM" gh_run "$MG" "$marker"
assert_gate_allows "marker guard: no tool-input library means tool name is unknown, allow"
gh_farm mg-notoolinput "$MG" tool-input.sh
GH_REPO="$GH_FARM" gh_run "$MG" "$marker"
assert_gate_allows "marker guard: missing tool-input library allows"
tl_stub cat 'exit 1'; hash -r
GH_REPO="$REAL_REPO" gh_run "$MG" "$marker"
assert_gate_allows "marker guard: unreadable stdin allows"
rm -f "$TL_BIN/cat"; hash -r

# ---- context-mode-read-deny ----
RD=hooks/context-mode-read-deny.sh
jq -n '{config_version:"1", sb_initiated:true, recommended_tools:{context_mode:{enabled_by_user:true}}}' >"$GH_CFG"
head -c 9000 /dev/zero | tr '\0' a >"$GH_PROJ/src/big.txt"
# Context Mode installed and wired: the nudge only applies when its ctx_* tools exist.
tl_stub context-mode 'exit 0'; hash -r
printf '{"mcpServers":{"context-mode":{}}}' >"$TL_TMP/cm-mcp.json"; export SB_CONTEXT_MODE_MCP_ARTIFACT="$TL_TMP/cm-mcp.json"
rd_acks() { rm -rf "$SB_RUNTIME_STATE_DIR/context-mode-read-acks"; }
rin="$(jq -cn --arg p "$GH_PROJ/src/big.txt" '{hook_event_name:"PreToolUse", tool_name:"Read", tool_input:{file_path:$p}}')"
rd_acks; GH_REPO="$REAL_REPO" gh_run "$RD" "$rin"
assert_gate_denies "read-deny: baseline denies" "9000 bytes"
gh_farm rd-nolib "$RD" -
GH_REPO="$GH_FARM" gh_run "$RD" "$rin"
assert_gate_allows "read-deny: no libraries fails open"
gh_farm rd-noaudit "$RD" hook-audit.sh
rd_acks; GH_REPO="$GH_FARM" gh_run "$RD" "$rin"
assert_gate_denies "read-deny: deny survives missing audit library" "9000 bytes"
gh_farm rd-notoolinput "$RD" tool-input.sh
GH_REPO="$GH_FARM" gh_run "$RD" "$rin"
assert_gate_allows "read-deny: without tool-input library the read path is unknown, allow"
gh_farm rd-inactive "$RD" project-active.sh
printf 'sb_project_active() { return 1; }\nsb_project_is_initiated() { return 1; }\n' >"$GH_FARM/hooks/lib/project-active.sh"
GH_REPO="$GH_FARM" gh_run "$RD" "$rin"
assert_gate_allows "read-deny: uninitiated project allows"
tl_stub cat 'exit 1'; hash -r
GH_REPO="$REAL_REPO" gh_run "$RD" "$rin"
assert_gate_allows "read-deny: unreadable stdin allows"
rm -f "$TL_BIN/cat"; hash -r
# unknown file size falls back to 0 in the message
gh_farm rd-nosize "$RD" context-mode-read-deny.sh
{
  printf 'source "%s/hooks/lib/context-mode-read-deny.sh"\n' "$TL_REPO_ROOT"
  printf 'sb_context_mode_file_size_bytes() { return 1; }\n'
  printf 'sb_context_mode_should_deny_read() { printf %%s "%s"; }\n' "$GH_PROJ/src/big.txt"
} >"$GH_FARM/hooks/lib/context-mode-read-deny.sh"
GH_REPO="$GH_FARM" gh_run "$RD" "$rin"
assert_gate_denies "read-deny: unknown size reported as 0 bytes" "0 bytes > 5120 byte threshold"
# read-path helper failing leaves the audit target empty but still denies
gh_farm rd-nopath "$RD" context-mode-read-deny.sh
{
  printf 'source "%s/hooks/lib/context-mode-read-deny.sh"\n' "$TL_REPO_ROOT"
  printf 'sb_context_mode_tool_read_path() { return 1; }\n'
  printf 'sb_context_mode_should_deny_read() { printf %%s "%s"; }\n' "$GH_PROJ/src/big.txt"
} >"$GH_FARM/hooks/lib/context-mode-read-deny.sh"
GH_REPO="$GH_FARM" gh_run "$RD" "$rin"
assert_gate_denies "read-deny: failing read-path helper does not break the decision" "9000 bytes"

tl_results
