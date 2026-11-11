#!/usr/bin/env bash
# End to end: a shell push is an intermediate commit only in the provable shape (push_scope.py); anything else
# is final delivery. Claude Bash payloads (with cwd), Codex exec_command payloads (workdir, argv form) and MCP
# writes go through hooks/completion-audit.sh with only the planning floor recorded. The full attack/honest
# corpus with real-repository ground truth is tests/python/test_push_scope_corpus.py.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/cov-a-ca.sh"
export SILVER_BULLET_SKIP_ENFORCEMENT_TIER_GATE=1
export GIT_CONFIG_NOSYSTEM=1

# payload JSON -> hook, run from $RUN_DIR (the hook's own working directory)
run_payload() { # run_payload TOOL INPUT-JSON [CWD]
  local tool="$1" input="$2" cwd="${3:-}" json
  json="$(jq -cn --arg t "$tool" --argjson i "$input" --arg c "$cwd" \
    '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:$i} + (if $c == "" then {} else {cwd:$c} end)')"
  tl_run_stdin "$json" env bash -c 'cd "$1" && exec bash "$2"' _ "${RUN_DIR:-$PROJ}" "$HOOK"
}
run_bash() { run_payload Bash "$(jq -cn --arg c "$1" '{command:$c}')" "${2:-}"; }
expect_feature() { run_bash "$@"; assert_eq "intermediate: $1" "allow" "$(decision)"; }
expect_strict() { # expect_strict CMD REASON-FRAGMENT [CWD]
  run_bash "$1" "${3:-}"
  assert_eq "final delivery: $1" "deny" "$(decision)"
  assert_contains "final delivery gate: $1" "$(message)" "COMPLETION BLOCKED"
  assert_contains "reason for: $1" "$(message)" "$2"
}

add_origin() { # add_origin DIR: an origin remote whose default branch (main) is known locally, without a network
  git -C "$1" remote add origin https://github.com/acme/app.git
  git -C "$1" update-ref refs/remotes/origin/main "$(git -C "$1" rev-parse main)"
  git -C "$1" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
}

mkproj scope
state inst-a
add_origin "$PROJ"
git -C "$PROJ" worktree add -q "$TL_TMP/wt-main" main
WT="$TL_TMP/wt-main"
PROJ_REAL="$(cd "$PROJ" && pwd -P)"

# ── the accepted shape stays intermediate ────────────────────────────────────
expect_feature 'git push'
expect_feature 'git push -u origin HEAD'
expect_feature 'git push origin feature/test'
expect_feature 'git add -A && git commit -q -m x && git push'
expect_feature "git commit -q --allow-empty -m \"\$(cat <<'EOF'
subject
EOF
)\" && git push -u origin HEAD"
expect_feature 'git checkout -b feature/new && git push -u origin feature/new'
expect_feature "cd $PROJ_REAL && git push origin HEAD"
expect_feature 'git push' "$PROJ_REAL"
# Codex: argv form with workdir
run_payload exec_command "$(jq -cn --arg w "$PROJ_REAL" '{cmd:["git","push","-u","origin","HEAD"],workdir:$w}')"
assert_eq "Codex argv push from a feature checkout: intermediate" "allow" "$(decision)"

# ── attacks: final delivery, with the reason ─────────────────────────────────
expect_strict 'git checkout main && git push origin HEAD' 'git checkout'
expect_strict 'git switch main; git push' 'git switch'
expect_strict 'git push origin HEAD:main' 'default branch'
expect_strict 'git push origin +feature/test:v1' 'forced'
expect_strict 'git push --mir origin' '--mir'
expect_strict 'git -c push.default=matching push' 'plain top-level'
expect_strict 'git config push.default matching && git push' 'git config'
expect_strict 'sh -c "git checkout main" && git push origin HEAD' 'sh'
expect_strict 'git push origin feature/test &' 'background'
expect_strict 'if true; then git checkout -q main; fi; git push origin HEAD' 'compound'
expect_strict 'true || cd /tmp && git push origin HEAD' 'chain'
expect_strict 'git push origin feature/test && git push origin main' 'more than one'
expect_strict "cd $WT && git push origin HEAD" 'default branch'
expect_strict "git -C $WT push origin HEAD" 'default branch'
# the payload cwd, not the hook's own directory, decides where a push runs
expect_strict 'git push origin HEAD' 'default branch' "$WT"
run_payload exec_command "$(jq -cn --arg w "$WT" '{cmd:["git","push","origin","HEAD"],workdir:$w}')"
assert_eq "Codex workdir on main: final delivery" "deny" "$(decision)"
assert_contains "Codex workdir on main: reason" "$(message)" "default branch"
expect_strict 'git push' 'does not exist' "$TL_TMP/no-such-dir"
assert_contains "the block message explains the accepted shape" "$(message)" "A push stays an intermediate commit when it runs as its own command"
# git settings that change what a push sends
git -C "$PROJ" config push.default upstream
expect_strict 'git push' 'push.default'
git -C "$PROJ" config --unset push.default
git -C "$PROJ" config remote.origin.push 'refs/heads/feature/test:refs/heads/main'
expect_strict 'git push origin feature/test' 'remote.origin.push'
git -C "$PROJ" config --unset remote.origin.push
RUN_DIR="$PROJ" run_payload Bash "$(jq -cn '{command:"git push"}')" "$PROJ_REAL"
assert_eq "settings restored: the plain push is intermediate again" "allow" "$(decision)"

# ── facts the checkout must have ─────────────────────────────────────────────
mkproj nohead
state inst-a
git -C "$PROJ" remote add origin https://example.test/acme/app.git
expect_strict 'git push -u origin HEAD' 'set-head'
assert_contains "the missing remote HEAD names its remedy" "$(message)" "git remote set-head origin --auto"
mkproj noremote
state inst-a
expect_strict 'git push origin HEAD' 'URL or path'
git -C "$PROJ" checkout -q --detach
add_origin "$PROJ"
expect_strict 'git push origin HEAD' 'detached'

# ── opt-out: the project accepts default-branch pushes at the planning floor ──
mkproj optout '.project.push_to_default_branch_tier="intermediate"'
state inst-a
add_origin "$PROJ"
expect_feature "git push origin HEAD:main"

# ── the fixed fields of the payload: a non-string cwd is final delivery ──────
mkproj oddcwd
state inst-a
add_origin "$PROJ"
tl_run_stdin '{"hook_event_name":"PreToolUse","tool_name":"Bash","cwd":7,"tool_input":{"command":"git push"}}' \
  bash -c 'cd "$1" && exec bash "$2"' _ "$PROJ" "$HOOK"
assert_eq "a payload cwd that is not a string: final delivery" "deny" "$(decision)"
tl_run_stdin "$(jq -cn --arg c "$PROJ" '{hook_event_name:"PreToolUse",tool_name:"exec_command",cwd:$c,tool_input:{cmd:["git","push"],workdir:"no-such-subdir"}}')" \
  bash -c 'cd "$1" && exec bash "$2"' _ "$PROJ" "$HOOK"
assert_eq "a workdir that does not exist: final delivery" "deny" "$(decision)"
mkdir -p "$PROJ/sub"
tl_run_stdin "$(jq -cn --arg c "$PROJ" '{hook_event_name:"PreToolUse",tool_name:"exec_command",cwd:$c,tool_input:{cmd:["git","push"],workdir:"sub"}}')" \
  bash -c 'cd "$1" && exec bash "$2"' _ "$PROJ" "$HOOK"
assert_eq "a relative workdir joins the payload cwd: intermediate" "allow" "$(decision)"

# ── MCP writes (Invariant M): the repository must be a remote of the checkout in the payload cwd ──
mkproj mcpscope
state inst-a
add_origin "$PROJ"
mcp_allow() { # mcp_allow TOOL INPUT-JSON [CWD]
  run_payload "$1" "$2" "${3:-}"
  assert_eq "MCP intermediate: $1 $2" "allow" "$(decision)"
}
mcp_strict() { # mcp_strict TOOL INPUT-JSON REASON [CWD]
  run_payload "$1" "$2" "${4:-}"
  assert_eq "MCP final delivery: $1 $2" "deny" "$(decision)"
  assert_contains "MCP reason: $1 $2" "$(message)" "$3"
}
mcp_allow mcp__github__push_files '{"owner":"acme","repo":"app","branch":"feature/x","files":[]}'
mcp_allow mcp__github__create_or_update_file '{"owner":"ACME","repo":"App","branch":"feature/x","path":"a"}'
mcp_allow mcp__github__create_branch '{"owner":"acme","repo":"app","branch":"feature/new","from_branch":"main"}'
mcp_strict mcp__github__push_files '{"owner":"acme","repo":"app","branch":"main","files":[]}' 'default branch'
mcp_strict mcp__github__push_files '{"owner":"other","repo":"lib","branch":"feature/x"}' 'not a remote'
mcp_strict mcp__github__push_files '{"owner":"acme","repo":"app","files":[]}' 'default branch'
mcp_strict mcp__github__push_files '{"owner":"acme","repo":"app","branch":"refs/heads/main"}' 'default branch'
mcp_strict mcp__github__delete_file '{"owner":"acme","repo":"app","branch":"HEAD"}' 'default branch'
mcp_strict mcp__github__push_files '{"owner":["acme"],"repo":"app","branch":"feature/x"}' 'plain owner and repo'
mcp_strict mcp__github__push_files '{"repository":"acme/app","branch":"feature/x"}' 'plain owner and repo'
mcp_strict mcp__github__create_tag '{"owner":"acme","repo":"app","tag":"v1"}' 'cannot scope'
mcp_strict mcp__github__update_ref '{"owner":"acme","repo":"app","ref":"heads/x"}' 'cannot scope'
mkdir -p "$TL_TMP/plain"
mcp_strict mcp__github__push_files '{"owner":"acme","repo":"app","branch":"feature/x"}' 'could not be read' "$TL_TMP/plain"
mcp_strict mcp__github__push_files '{"owner":"acme","repo":"app","branch":"feature/x"}' 'does not exist' "$TL_TMP/no-such-dir"
git -C "$PROJ" symbolic-ref --delete refs/remotes/origin/HEAD
mcp_strict mcp__github__push_files '{"owner":"acme","repo":"app","branch":"feature/x"}' 'set-head'

tl_results
