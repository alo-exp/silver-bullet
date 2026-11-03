#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034  # the prelude reads input/tool_name and sets mcp_server, mcp_tool, mcp_args
# Unit tests for the shared opt-in prelude (hooks/lib/opt-in-gate.sh), the stamp and version
# helpers in hooks/lib/recommended-tools.sh, and the failure paths of the opt-in gate libraries
# (unreadable payloads, unwritable state, missing sibling libraries).
set -euo pipefail
# shellcheck source=../lib/consent-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/consent-helpers.sh"
sb_test_consent_grant_all
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
unset SB_AGENTMEMORY_MCP_ARTIFACT SB_CONTEXT_MODE_MCP_ARTIFACT SB_LEANCTX_MCP_ARTIFACT SB_ALUMNIUM_MCP_ARTIFACT

LIBDIR="$TL_REPO_ROOT/hooks/lib"
# shellcheck source=../../hooks/lib/opt-in-gate.sh
source "$LIBDIR/opt-in-gate.sh"
# shellcheck source=../../hooks/lib/agentmemory-gate.sh
source "$LIBDIR/agentmemory-gate.sh"
# shellcheck source=../../hooks/lib/alumnium-gate.sh
source "$LIBDIR/alumnium-gate.sh"
# shellcheck source=../../hooks/lib/context-mode-read-deny.sh
source "$LIBDIR/context-mode-read-deny.sh"
# shellcheck source=../../hooks/lib/graphify-gate.sh
source "$LIBDIR/graphify-gate.sh"
# shellcheck source=../../hooks/lib/leanctx-gate.sh
source "$LIBDIR/leanctx-gate.sh"
# shellcheck source=../../hooks/lib/rtk-gate.sh
source "$LIBDIR/rtk-gate.sh"
# shellcheck source=../../hooks/lib/token-compression-tools-gate.sh
source "$LIBDIR/token-compression-tools-gate.sh"

yes_t() { local n="$1"; shift; if "$@"; then tl_pass "$n"; else tl_fail "$n"; fi; }
no_t() { local n="$1"; shift; if "$@"; then tl_fail "$n"; else tl_pass "$n"; fi; }
STATE="$SB_RUNTIME_STATE_DIR"
BADSTATE="$TL_TMP/not-a-dir"; printf 'file' >"$BADSTATE"   # a state dir that cannot be created
CFG="$TL_TMP/cfg.json"; printf '{}' >"$CFG"

echo "=== path normalization ==="
no_t "normalize: empty path" sb_opt_in_normalize_path ""
assert_eq "normalize: the root" "/" "$(sb_opt_in_normalize_path "/")"
assert_eq "normalize: dotdot above the root stays at the root" "/" "$(sb_opt_in_normalize_path "/../..")"
# shellcheck disable=SC2088  # the literal tilde is the input under test
TILDE_PATH="~/x"
assert_eq "normalize: ~/ expands to HOME" "$HOME/x" "$(sb_opt_in_normalize_path "$TILDE_PATH")"
assert_eq "normalize: relative to the base" "$TL_TMP/a/c" "$(sb_opt_in_normalize_path "b/../c" "$TL_TMP/a")"
mkdir -p "$TL_TMP/real"; ln -sfn "$TL_TMP/real" "$TL_TMP/dirlink"; ln -sfn "$TL_TMP/real/file" "$TL_TMP/leaflink"
assert_eq "normalize: a symlinked directory is resolved" "$TL_TMP/real/x" "$(sb_opt_in_normalize_path "$TL_TMP/dirlink/x")"
assert_eq "normalize: a symlinked leaf is resolved" "$TL_TMP/real/file" "$(sb_opt_in_normalize_path "$TL_TMP/leaflink")"
ln -sfn "$TL_TMP/loop2" "$TL_TMP/loop1"; ln -sfn "$TL_TMP/loop1" "$TL_TMP/loop2"
yes_t "normalize: a symlink loop terminates" sb_opt_in_normalize_path "$TL_TMP/loop1"
assert_eq "normalize: a not-yet-existing tree" "$TL_TMP/new/deep/f" "$(sb_opt_in_normalize_path "$TL_TMP/new/deep/f")"
no_t "path_under: empty path" sb_opt_in_path_under "" "$TL_TMP"
no_t "path_under: empty dir" sb_opt_in_path_under "$TL_TMP/x" ""
yes_t "path_under: inside" sb_opt_in_path_under "$TL_TMP/a/b" "$TL_TMP/a"
yes_t "path_under: the directory itself" sb_opt_in_path_under "$TL_TMP/a" "$TL_TMP/a"
no_t "path_under: a lookalike sibling" sb_opt_in_path_under "$TL_TMP/a-evil/b" "$TL_TMP/a"
no_t "path_under: dotdot out" sb_opt_in_path_under "$TL_TMP/a/../b" "$TL_TMP/a"

echo "=== payload helpers with unparsable input ==="
input='not json'
assert_eq "command string of garbage is empty" "" "$(sb_opt_in_command_string)"
assert_eq "target paths of garbage are empty" "" "$(sb_opt_in_target_paths)"
tool_name="mcp__srv__tool"
yes_t "mcp call: garbage args fall back to {} (server and tool come from the name)" sb_opt_in_mcp_call
assert_eq "mcp args fallback" "{}" "$mcp_args"
tool_name="Bash"
no_t "mcp call: a shell tool is not an MCP call" sb_opt_in_mcp_call
input='{"tool_name":"CallMcpTool","tool_input":{"server":"s","toolName":"t","arguments":{"q":1}}}'; tool_name="CallMcpTool"
yes_t "mcp call: Cursor shape" sb_opt_in_mcp_call
assert_eq "mcp call: server" "s" "$mcp_server"
assert_eq "mcp call: arguments" '{"q":1}' "$mcp_args"
input='not json'; tool_name="CallMcpTool"
no_t "mcp call: an unparsable Cursor payload is not an MCP call" sb_opt_in_mcp_call
assert_eq "mcp call: unparsable payload has no server" "" "$mcp_server"
assert_eq "mcp call: unparsable payload has empty args" "{}" "$mcp_args"
input='{"tool_input":{"cmd":["git","commit","-m","a b"]}}'
assert_eq "command string: an argv list is shell-quoted" "'git' 'commit' '-m' 'a b'" "$(sb_opt_in_command_string)"
input='{"tool_input":{"command":5}}'
assert_eq "command string: a non-string command is empty" "" "$(sb_opt_in_command_string)"
input='{"tool_input":{"file_path":"/p/a"}}'
assert_eq "target paths: a direct path" "/p/a" "$(sb_opt_in_target_paths)"
input='{"tool_input":{"input":"x"}}'
sb_tool_patch_paths() { return 1; }
assert_eq "target paths: a failing patch parser yields nothing" "" "$(sb_opt_in_target_paths)"
sb_tool_patch_paths() { printf '\n/p/one\n/p/two\n'; }
always_yes() { return 0; }
file_path=""
yes_t "edit targets: blank lines are skipped, every target is checked" sb_opt_in_edit_targets_exempt always_yes
assert_eq "edit targets: the first target is kept for the audit record" "/p/one" "$file_path"
only_one() { [[ "$1" == /p/one ]]; }
no_t "edit targets: one non-exempt target makes the edit non-exempt" sb_opt_in_edit_targets_exempt only_one
unset -f sb_tool_patch_paths
source "$LIBDIR/tool-input.sh"

echo "=== shell results ==="
input='{"tool_response":{"exit_code":0}}'; yes_t "shell succeeded: exit 0" sb_opt_in_shell_succeeded
input='{"tool_response":{"exitCode":"0"}}'; yes_t "shell succeeded: exitCode string" sb_opt_in_shell_succeeded
input='{"tool_response":{"exit_code":1}}'; no_t "shell succeeded: exit 1" sb_opt_in_shell_succeeded
input='{"tool_response":{"stdout":"x","is_error":true}}'; no_t "shell succeeded: error flag" sb_opt_in_shell_succeeded
input='{"tool_response":{"stdout":"x"}}'; yes_t "shell succeeded: output without a code" sb_opt_in_shell_succeeded
input='{"tool_response":{}}'; no_t "shell succeeded: nothing to go on" sb_opt_in_shell_succeeded
input='{"tool_response":"text"}'; no_t "shell succeeded: a string response" sb_opt_in_shell_succeeded
input='{"tool_response":{"isError":true}}'; no_t "mcp succeeded: error result" sb_opt_in_mcp_succeeded
input='{"tool_response":{}}'; yes_t "mcp succeeded: clean result" sb_opt_in_mcp_succeeded

echo "=== blocks ==="
sb_hook_audit_record() { return 1; }
hook_event=PreToolUse; out="$(sb_opt_in_emit_block "reason one")"
assert_contains "emit_block survives a failing audit writer" "$out" '"permissionDecision":"deny"'
hook_event=Stop; out="$(sb_opt_in_emit_block "reason two")"
assert_contains "emit_block: a non-PreToolUse event blocks with decision" "$out" '"decision":"block"'
unset -f sb_hook_audit_record

echo "=== command classification ==="
no_t "tool_command: empty" sb_opt_in_tool_command rtk ""
no_t "tool_command: only assignments has no program" sb_opt_in_tool_command rtk "A=1"
no_t "program: only assignments" _sb_opt_in_program "A=1 B=2"
assert_eq "program: after assignments" "git" "$(_sb_opt_in_program "A=1 /usr/bin/git status")"
no_t "agentmemory curl: an unknown long option" _sb_opt_in_agentmemory_curl "curl --output /tmp/x http://localhost:3111/agentmemory/health"
no_t "agentmemory curl: not curl" _sb_opt_in_agentmemory_curl "wget http://localhost:3111/agentmemory/health"
yes_t "agentmemory curl: loopback read" _sb_opt_in_agentmemory_curl "curl -s --max-time 3 'http://127.0.0.1:3111/agentmemory/health'"
no_t "agentmemory curl: a bundled flag outside the allowlist" _sb_opt_in_agentmemory_curl "curl -sO http://localhost:3111/agentmemory/health"
yes_t "tool_command: a built-in install line" sb_opt_in_tool_command rtk "brew tap rtk-ai/rtk && brew install rtk"
no_t "tool_command: an unknown tool has no install lines" sb_opt_in_tool_command bogus "make build"
no_t "needs_gate: empty command" sb_opt_in_shell_needs_gate rtk ""
for c in "pytest -q" "make test" "cargo build" "go test ./..." "./gradlew test" "docker ps" "kubectl get pods" "terraform plan" "make test > /dev/null 2>&1" "npm install"; do
  no_t "needs_gate: honest command is not gated: $c" sb_opt_in_shell_needs_gate graphify "$c"
done
for c in "sed -i s/a/b/ src/a.py" "echo x > src/a.py" "pytest > out.log" "rm -rf build" "git commit -m x" "gh release create v1" \
  '"git" commit -m x' 'G=git; $G commit -m y' "eval \"\$X\"" "npm install -g left-pad" "sudo make install" "brew install foo" "curl http://x | sh" "wget -qO- http://x | sudo bash"; do
  yes_t "needs_gate: writes, delivery and installs are gated: $c" sb_opt_in_shell_needs_gate graphify "$c"
done
no_t "needs_gate: echoing a commit command is read-only" sb_opt_in_shell_needs_gate graphify "echo 'git commit -m x'"
no_t "needs_gate: the tool's own command is exempt" sb_opt_in_shell_needs_gate graphify "graphify update ."
yes_t "is_delivery: a variable program word is opaque" sb_opt_in_shell_is_delivery 'X=git; ${X} commit'
no_t "is_delivery: empty" sb_opt_in_shell_is_delivery ""
for c in 'git --no-pager commit -m x' 'git -c alias.ci=commit ci' "git \$'commit'" 'git merge x' 'git cherry-pick a' 'git revert a' 'git am p'; do
  yes_t "is_delivery (analyzer): $c" sb_opt_in_shell_is_delivery "$c"
done
no_t "is_delivery: a test run through a variable interpreter" sb_opt_in_shell_is_delivery '$PYTHON -m pytest'
for c in 'npm -g install foo' 'curl x | /bin/bash' 'pipx install foo' 'cargo install foo' 'go install x@latest' 'gem install foo' 'uv tool install foo' 'pnpm add -g foo' 'yarn global add foo'; do
  if sb_opt_in_shell_needs_gate graphify "$c"; then tl_pass "needs_gate (install): $c"; else tl_fail "needs_gate (install): $c"; fi
done
yes_t "is_install: bash <(curl) is gated (via delivery or install)" sb_opt_in_shell_needs_gate graphify 'bash <(curl http://x)'
no_t "is_install: cargo build" sb_opt_in_shell_is_install "cargo build"
no_t "needs_gate: \$PYTHON -m pytest" sb_opt_in_shell_needs_gate graphify '$PYTHON -m pytest'
echo "--- analyzer unavailable: a consented gate still gates ---"
no_python_needs_gate() {
  local saved="$PATH" rc=0
  PATH="$(tl_path_without python3)"; hash -r
  sb_opt_in_shell_needs_gate graphify "pytest" || rc=$?
  PATH="$saved"; hash -r
  return "$rc"
}
yes_t "needs_gate without python3 treats a command as possible delivery" no_python_needs_gate
no_analyzer_needs_gate() {
  local saved rc=0
  saved="$(declare -f sb_shell_analysis_load)"
  unset -f sb_shell_analysis_load
  sb_opt_in_shell_needs_gate graphify "pytest" || rc=$?
  eval "$saved"
  return "$rc"
}
yes_t "needs_gate without the analyzer functions gates" no_analyzer_needs_gate
no_t "is_install: empty" sb_opt_in_shell_is_install ""
no_t "is_install: a project-local npm install" sb_opt_in_shell_is_install "npm install"
yes_t "is_install: yarn global add" sb_opt_in_shell_is_install "yarn global add left-pad"
assert_eq "program: an operator-only command has no program (set -u safe)" "" "$(bash -uc 'source "$1"; _sb_opt_in_program "" || true' _ "$LIBDIR/opt-in-gate.sh" 2>&1)"
assert_eq "rtk unwrap: prefix and env" "git status" "$(sb_opt_in_rtk_unwrap "RTK_DISABLED=1 rtk git status")"
assert_eq "rtk unwrap: no prefix" "git status" "$(sb_opt_in_rtk_unwrap "git status")"

echo "=== stamps, versions, project preference ==="
STAMP="$TL_TMP/stamp"
no_t "stamp_write: empty path" sb_rt_stamp_write ""
no_t "stamp_write: a directory" sb_rt_stamp_write "$TL_TMP"
no_t "stamp_write: parent cannot be created" sb_rt_stamp_write "$BADSTATE/sub/stamp"
tl_stub mktemp 'exit 1'; hash -r
no_t "stamp_write: mktemp fails" sb_rt_stamp_write "$STAMP"
rm -f "$TL_BIN/mktemp"; tl_stub mv 'exit 1'; hash -r
no_t "stamp_write: rename fails" sb_rt_stamp_write "$STAMP"
assert_file_absent "stamp_write: no temp file is left behind" "$STAMP"
[[ -z "$(find "$TL_TMP" -maxdepth 1 -name 'stamp.*' 2>/dev/null)" ]] && tl_pass "stamp_write: no stray temp file" || tl_fail "stamp_write: no stray temp file"
rm -f "$TL_BIN/mv"; hash -r
yes_t "stamp_write: ok" sb_rt_stamp_write "$STAMP"
yes_t "stamp fresh" sb_rt_stamp_is_fresh "$STAMP" 60
printf '%s' "$(date +%s)" >"$STAMP"
yes_t "stamp fresh without a trailing newline" sb_rt_stamp_is_fresh "$STAMP" 60
no_t "stamp: bad ttl" sb_rt_stamp_is_fresh "$STAMP" "x"
printf 'junk\n' >"$STAMP"; no_t "stamp: junk" sb_rt_stamp_is_fresh "$STAMP" 60
assert_eq "ttl: in range" "300" "$(sb_rt_ttl_seconds 300 1800)"
assert_eq "ttl: too small" "1800" "$(sb_rt_ttl_seconds 59 1800)"
assert_eq "ttl: too large" "1800" "$(sb_rt_ttl_seconds 999999 1800)"
assert_eq "ttl: not a number" "1800" "$(sb_rt_ttl_seconds 'a[$(id)]' 1800)"
no_t "version_ge: invalid have" sb_rt_version_ge "x" "1.0"
no_t "version_ge: invalid min" sb_rt_version_ge "1.0" "x"
sb_rt_version_ge "x" "1.0" || assert_eq "version_ge: invalid input is status 2" "2" "$?"
yes_t "version_ge: major greater" sb_rt_version_ge "2.0" "1.9.9"
no_t "version_ge: major lower" sb_rt_version_ge "1.9" "2.0"
yes_t "version_ge: minor greater" sb_rt_version_ge "1.5" "1.4.9"
no_t "version_ge: minor lower" sb_rt_version_ge "1.3" "1.4"
yes_t "version_ge: patch equal" sb_rt_version_ge "1.4.2" "1.4.2"
no_t "version_ge: patch lower" sb_rt_version_ge "1.4.1" "1.4.2"
yes_t "version_ge: leading zeros are decimal" sb_rt_version_ge "1.08" "1.8"
assert_eq "version_extract" "1.2.3" "$(sb_rt_version_extract "rtk version 1.2.3-beta")"
no_t "version_extract: nothing" sb_rt_version_extract "no digits"
assert_eq "safe_rel_path: plain" "a/b.c" "$(sb_rt_safe_rel_path "a/b.c" d)"
assert_eq "safe_rel_path: trailing slash" "d" "$(sb_rt_safe_rel_path "a/" d)"
assert_eq "safe_rel_path: double slash" "d" "$(sb_rt_safe_rel_path "a//b" d)"
assert_eq "safe_rel_path: dot component" "d" "$(sb_rt_safe_rel_path "a/./b" d)"
printf 'not json' >"$TL_TMP/garbage.json"
assert_eq "project_preference: unparsable config is unset" "unset" "$(sb_recommended_tool_project_preference "$TL_TMP/garbage.json" rtk)"
assert_eq "alumnium on codex: merge instruction" "Merge [mcp_servers.alumnium] into ~/.codex/config.toml (see docs/ALUMNIUM.md)" "$(sb_recommended_tool_platform_pre_index_commands "" alumnium codex)"
assert_eq "notice marker: a project root that does not exist still gets a marker path" "yes" "$([[ "$(_sb_rt_notice_marker rtk /nonexistent/project)" == "$STATE/consent-notices/rtk-"* ]] && echo yes || echo no)"
printf '{"recommended_tools":{"rtk":{"enabled_by_user":true}}}' >"$TL_TMP/rec.json"
out="$(XDG_CONFIG_HOME="$TL_TMP/none" SB_RUNTIME_STATE_DIR="$BADSTATE" sb_recommended_tool_consent_prompt_block "$TL_TMP/rec.json" rtk)"
assert_contains "the consent notice still shows when its marker cannot be written" "$out" "CONSENT NEEDED"

echo "=== failure paths of the gate libraries ==="
# unreadable server-health cache (no trailing newline) and an unwritable state dir
printf '%s up http://localhost:3111/agentmemory/health' "$(date +%s)" >"$STATE/agentmemory-health"
yes_t "agentmemory health: a cache without a newline is still read" sb_agentmemory_server_healthy "$CFG"
rm -f "$STATE/agentmemory-health"
tl_stub curl 'exit 0'; hash -r
yes_t "agentmemory health: an unwritable state dir does not break the probe" env SB_RUNTIME_STATE_DIR="$BADSTATE" bash -c 'source "$1"; sb_agentmemory_server_healthy' _ "$LIBDIR/agentmemory-gate.sh"
tl_stub mv 'exit 1'; hash -r
yes_t "agentmemory health: a failing rename is cleaned up" sb_agentmemory_server_healthy "$CFG"
rm -f "$TL_BIN/mv" "$STATE/agentmemory-health"; hash -r
tl_stub mktemp 'echo /nonexistent-dir/tmp.XXXX'; hash -r
yes_t "agentmemory health: an unwritable temp file is cleaned up" sb_agentmemory_server_healthy "$CFG"
rm -f "$TL_BIN/mktemp" "$TL_BIN/curl" "$STATE/agentmemory-health"; hash -r
no_t "agentmemory retrieval: only assignments" sb_agentmemory_command_is_retrieval "A=1"
no_t "graphify retrieval: only assignments" sb_graphify_command_is_retrieval "A=1"
no_t "leanctx usage: only assignments" sb_leanctx_command_is_usage "A=1"
no_t "token tool match: only assignments" sb_token_tool_command_matches "A=1" rtk rtk
no_t "token tool delivery: empty command" sb_token_tool_command_is_delivery ""
no_t "token tool delivery: a mention" sb_token_tool_command_is_delivery "echo 'git commit'"
yes_t "token tool delivery: a commit" sb_token_tool_command_is_delivery "git -C . commit -m x"
yes_t "token tool delivery: a PR" sb_token_tool_command_is_delivery "gh pr create --fill"
assert_contains "rtk too-old message without rtk on PATH" "$(PATH="$(tl_path_without rtk)" sb_rtk_block_message_old_version "$CFG")" "installed unknown"
(
  sb_shell_candidate_write_paths() { return 1; }
  sb_alumnium_command_requires_browser "make build" && exit 1
  exit 0
) && tl_pass "alumnium: a failing write-path analyzer means not browser work" || tl_fail "alumnium: a failing write-path analyzer means not browser work"
(
  cd() { return 1; }
  sb_consent_project_key "$TL_TMP" >/dev/null && exit 1
  exit 0
) && tl_pass "project key: an unreadable directory has no key" || tl_fail "project key: an unreadable directory has no key"
assert_eq "decision for a project directory that does not exist falls back to the machine record" "granted" "$(sb_consent_decision rtk enforce /nonexistent/project)"

echo "=== context mode helpers ==="
printf '%s\n' "/usr/bin/node" >"$STATE/context-mode-node"
printf '/x 1.2.3' >"$STATE/context-mode-node"
tl_stub node 'echo v23.1.0'; hash -r
assert_eq "node version: an unusable cache is re-read" "23.1.0" "$(sb_context_mode_node_version)"
printf '%s 99.0.0' "$(command -v node)" >"$STATE/context-mode-node"
touch -d '+1 minute' "$STATE/context-mode-node" 2>/dev/null || touch "$STATE/context-mode-node"
assert_eq "node version: a fresh cache without a newline is used" "99.0.0" "$(sb_context_mode_node_version)"
rm -f "$STATE/context-mode-node"
tl_stub node 'exit 1'; hash -r
no_t "node version: node --version fails" sb_context_mode_node_version
tl_stub node 'echo v23.1.0'; hash -r
tl_stub mv 'exit 1'; hash -r
assert_eq "node version: a failing cache rename is tolerated" "23.1.0" "$(sb_context_mode_node_version)"
rm -f "$TL_BIN/mv" "$TL_BIN/node" "$STATE/context-mode-node"* ; hash -r
assert_eq "claude wiring: a project root that cannot be entered is used as given" "no" "$(_sb_context_mode_claude_wired /nonexistent/project && echo yes || echo no)"
# the read nudge: a payload the helpers cannot parse
(
  sb_tool_name() { printf 'Read'; }
  [[ -z "$(sb_context_mode_tool_read_path 'garbage')" ]] || exit 1
  sb_tool_name() { printf 'Grep'; }
  [[ -z "$(sb_context_mode_tool_read_path 'garbage')" ]] || exit 2
  exit 0
) && tl_pass "read path: unparsable Read and Grep payloads yield no path" || tl_fail "read path: unparsable payloads (exit $?)"
BIGF="$TL_TMP/big.txt"; head -c 9000 /dev/zero | tr '\0' 'a' >"$BIGF"
assert_eq "read bytes: a limit that cannot be parsed counts the whole file" "9000" "$(_sb_context_mode_read_bytes 'garbage' "$BIGF")"
(
  export SB_CONTEXT_MODE_MCP_ARTIFACT="$TL_TMP/cm-art"; printf 'context-mode' >"$TL_TMP/cm-art"
  tl_stub context-mode 'exit 0'; hash -r
  rm -rf "$STATE/context-mode-read-acks"
  out="$(SB_RUNTIME_STATE_DIR="$BADSTATE" sb_context_mode_should_deny_read "$(jq -cn --arg p "$BIGF" '{tool_name:"Read",tool_input:{file_path:$p}}')" "$CFG" "$TL_TMP")"
  [[ "$out" == "$BIGF" ]]
) && tl_pass "read nudge: an unwritable acknowledgement store still redirects" || tl_fail "read nudge: an unwritable acknowledgement store still redirects"

echo "=== stack coordinator state ==="
mkdir -p "$TL_TMP/proj"; printf '{}' >"$TL_TMP/proj/.silver-bullet.json"
yes_t "project sum for a project that does not exist" _sb_stack_project_sum "/nonexistent/project/.silver-bullet.json"
SB_STACK_SESSION=""; export SB_STACK_SESSION
M="$(sb_stack_mutex_state_path "$TL_TMP/proj/.silver-bullet.json")"
mkdir -p "$(dirname "$M")"; printf 'garbage' >"$M"
yes_t "mutex: a corrupt file counts as clean (no session)" sb_stack_mutual_exclusion_is_clean "$TL_TMP/proj/.silver-bullet.json"
rm -f "$M"
yes_t "mutex: no state at all is clean (no session)" sb_stack_mutual_exclusion_is_clean "$TL_TMP/proj/.silver-bullet.json"
printf '{"violations":[]}' >"$M"
yes_t "mutex: an empty violation list is clean (no session)" sb_stack_mutual_exclusion_is_clean "$TL_TMP/proj/.silver-bullet.json"
rm -f "$M"
sb_stack_record_surface_owner "$TL_TMP/proj/.silver-bullet.json" sb_shell rtk
tl_stub cat 'exit 1'; hash -r
yes_t "state update: an unreadable existing state is replaced" sb_stack_record_surface_owner "$TL_TMP/proj/.silver-bullet.json" sb_graph graphify
/bin/rm -f "$TL_BIN/cat"; hash -r
assert_eq "state update: only the new surface survives an unreadable state" "graphify" "$(jq -r '.surfaces.sb_graph.owner' "$(sb_stack_coordinator_state_path "$TL_TMP/proj/.silver-bullet.json")")"
SB_STACK_SESSION="sess-a"
M="$(sb_stack_mutex_state_path "$TL_TMP/proj/.silver-bullet.json")"; mkdir -p "$(dirname "$M")"
printf 'garbage' >"$M"
yes_t "mutex: a corrupt file counts as clean (session)" sb_stack_mutual_exclusion_is_clean "$TL_TMP/proj/.silver-bullet.json"
printf '{"violations":[]}' >"$M"
yes_t "mutex: an empty violation list is clean (session)" sb_stack_mutual_exclusion_is_clean "$TL_TMP/proj/.silver-bullet.json"
SB_STACK_SESSION=""
tl_stub mktemp 'exit 1'; hash -r
no_t "state update: mktemp fails" sb_stack_record_surface_owner "$TL_TMP/proj/.silver-bullet.json" sb_shell rtk
rm -f "$TL_BIN/mktemp"; hash -r
sb_stack_record_double_compression "$TL_TMP/proj/.silver-bullet.json" sb_shell a b
tl_stub rm 'exit 1'; hash -r
SB_STACK_SESSION="sess-a"
yes_t "clear (one session): a failing rm is tolerated" sb_stack_clear_mutex_violations "$TL_TMP/proj/.silver-bullet.json"
SB_STACK_SESSION=""
yes_t "clear (every session of a project): a failing rm is tolerated" sb_stack_clear_mutex_violations "$TL_TMP/proj/.silver-bullet.json"
yes_t "clear (every project): a failing rm is tolerated" sb_stack_clear_mutex_violations
/bin/rm -f "$TL_BIN/rm"; hash -r
rm -rf "$STATE/stack-compression-mutex.d" "$STATE/stack-compression-coordinator.d"

echo "=== stack optimizer failure paths ==="
# shellcheck source=../../hooks/lib/stack-optimizer.sh
source "$LIBDIR/stack-optimizer.sh"
no_t "plain value: empty" _sb_stack_plain_value ""
for bad in $'a\nb' $'a\rb' $'a\tb' 'a<b' 'a>b' 'a&b' 'a"b'; do
  no_t "plain value rejects: $(printf '%q' "$bad")" _sb_stack_plain_value "$bad"
done
yes_t "plain value accepts a path" _sb_stack_plain_value "/tmp/a b/c"
assert_eq "knob: empty value uses the default" "dflt" "$(sb_stack_profile_knob "$CFG" p graphify k dflt)"
OUT="$TL_TMP/outside-export"; mkdir -p "$OUT"
EREPO="$TL_TMP/erepo"; mkdir -p "$EREPO"; ln -sfn "$OUT" "$EREPO/.agentmemory"
export SB_AGENTMEMORY_HOME="$TL_TMP/amhome-x"
no_t "env merge: an export root that escapes the project is refused" sb_stack_merge_agentmemory_env "$EREPO" "$CFG" synergy_max
assert_file_absent "env merge: nothing written for an escaping export root" "$SB_AGENTMEMORY_HOME/.env"
printf '{"recommended_tools":{"agentmemory":{"enabled_by_user":true}}}' >"$TL_TMP/am-on.json"
tl_stub launchctl 'exit 0'; hash -r
sb_stack_launchd_server_plist "$EREPO" "$TL_TMP/am-on.json" >/dev/null 2>&1 || true
rm -f "$TL_BIN/launchctl"; hash -r
out="$(CI=1 sb_optimize_agentmemory "$EREPO" "$TL_TMP/am-on.json" claude 2>&1)" || true
[[ -z "$(find "$OUT" -mindepth 1 2>/dev/null)" ]] && tl_pass "optimize agentmemory: nothing is created through an escaping export-root symlink" || tl_fail "optimize agentmemory: nothing is created through an escaping export-root symlink"
assert_file_absent "optimize agentmemory: ~/.agentmemory/.env is not written for an escaping export root" "$SB_AGENTMEMORY_HOME/.env"
printf '{"recommended_tools":{"graphify":{"enabled_by_user":true},"agentmemory":{"enabled_by_user":true}}}' >"$TL_TMP/both-on.json"
tl_stub curl 'exit 0'; tl_stub graphify 'exit 0'; hash -r
rm -f "$STATE/agentmemory-health"
sb_optimize_synergy "$EREPO" "$TL_TMP/both-on.json" >/dev/null 2>&1 || true
rm -f "$TL_BIN/curl" "$TL_BIN/graphify" "$STATE/agentmemory-health"; hash -r
mkdir -p "$TL_TMP/mrepo"
tl_stub mktemp 'exit 1'; hash -r
no_t "env merge: mktemp fails" sb_stack_merge_agentmemory_env "$TL_TMP/mrepo" "$CFG" synergy_max
/bin/rm -f "$TL_BIN/mktemp"; hash -r
assert_eq "graphify platform words: pre opencode" "graphify install --project --platform opencode" "$(_sb_stack_graphify_platform_words pre opencode)"
assert_eq "graphify platform words: pre hermes" "graphify install --project --platform hermes" "$(_sb_stack_graphify_platform_words pre hermes)"
assert_eq "graphify platform words: pre codex" "graphify install --project --platform codex" "$(_sb_stack_graphify_platform_words pre codex)"
assert_eq "graphify platform words: pre goose" "graphify install --project --platform pi" "$(_sb_stack_graphify_platform_words pre goose)"
assert_contains "graphify platform words: pre pi" "$(_sb_stack_graphify_platform_words pre pi)" "install-pi.py"
assert_eq "graphify platform words: post cursor" "graphify cursor install" "$(_sb_stack_graphify_platform_words post cursor)"
assert_eq "graphify platform words: post codex" "graphify codex install --project" "$(_sb_stack_graphify_platform_words post codex)"
assert_eq "agentmemory connect: goose" "agentmemory connect pi" "$(_sb_stack_agentmemory_connect_words goose)"
assert_eq "agentmemory connect: pi" "agentmemory connect pi" "$(_sb_stack_agentmemory_connect_words pi)"
assert_eq "agentmemory connect: hermes" "agentmemory connect hermes" "$(_sb_stack_agentmemory_connect_words hermes)"
assert_eq "agentmemory connect: cursor has none" "" "$(_sb_stack_agentmemory_connect_words cursor)"
printf '{"recommended_tools":{"graphify":{"enabled_by_user":true}}}' >"$TL_TMP/g-on.json"
mkdir -p "$TL_TMP/prepo"
tl_stub mktemp 'exit 1'; hash -r
out="$(SB_STACK_SCORE_THRESHOLD=abc sb_stack_optimization_prompt_line "$TL_TMP/prepo" "$TL_TMP/g-on.json")"
assert_contains "prompt line: a bad threshold falls back to 70 (cache cannot be written)" "$out" "STACK OPTIMIZATION"
/bin/rm -f "$TL_BIN/mktemp"; hash -r
PCACHE="$STATE/stack-optimization-score.d/$(printf '%s' "$TL_TMP/prepo" | cksum | awk '{print $1}')"
mkdir -p "$(dirname "$PCACHE")"; printf '%s 5' "$(date +%s)" >"$PCACHE"
assert_contains "prompt line: a cache without a newline is read" "$(sb_stack_optimization_prompt_line "$TL_TMP/prepo" "$TL_TMP/g-on.json")" "score 5/100"
rm -f "$PCACHE"
tl_stub mktemp 'echo /nonexistent-dir/score.tmp'; hash -r
out="$(sb_stack_optimization_prompt_line "$TL_TMP/prepo" "$TL_TMP/g-on.json")"
assert_contains "prompt line: an unwritable cache temp file is cleaned up" "$out" "STACK OPTIMIZATION"
/bin/rm -f "$TL_BIN/mktemp" "$PCACHE"; hash -r
tl_stub mv 'exit 1'; hash -r
out="$(sb_stack_optimization_prompt_line "$TL_TMP/prepo" "$TL_TMP/g-on.json")"
assert_contains "prompt line: a failing cache rename is tolerated" "$out" "STACK OPTIMIZATION"
/bin/rm -f "$TL_BIN/mv" "$PCACHE"; hash -r

echo "=== every hook is inert when the shared prelude is missing ==="
HOOKS=(agentmemory-gate alumnium-gate context-mode-gate context-mode-read-deny graphify-gate leanctx-gate rtk-gate
  stack-compression-coordinator token-compression-tools-gate record-agentmemory-usage record-graphify-query
  record-leanctx-usage record-recommended-mcp record-token-compression-usage)
for h in "${HOOKS[@]}"; do
  FARM="$TL_TMP/farm-$h"; rm -rf "$FARM"; mkdir -p "$FARM/hooks/lib"
  ln -s "$TL_REPO_ROOT/hooks/$h.sh" "$FARM/hooks/$h.sh"
  for f in "$LIBDIR"/*; do [[ "${f##*/}" == opt-in-gate.sh ]] || ln -s "$f" "$FARM/hooks/lib/${f##*/}"; done
  out="$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}' | bash "$FARM/hooks/$h.sh" 2>&1)" && rc=0 || rc=$?
  assert_eq "$h: exit status without the shared prelude" "0" "$rc"
  assert_eq "$h: no output without the shared prelude" "" "$out"
done

tl_results
