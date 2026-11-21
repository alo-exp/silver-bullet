#!/usr/bin/env bash
# Behavior tests for hooks/record-site-session.sh (site profile projects only).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

ST="$SB_RUNTIME_STATE_DIR"
SS="$ST/site-session.json"
H=hooks/record-site-session.sh
PROFILE='{"sb_initiated":true,"site_profile":{"enabled":true,"dir":"site"}}'
P="$TL_TMP/proj"
dg_project "$P" "$PROFILE"
rm -rf "$P/.git"
git -C "$P" init -q -b main
git -C "$P" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C "$P" remote add origin https://example.invalid/r.git
git -C "$P" update-ref refs/remotes/origin/main HEAD
git -C "$P" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
P_REAL="$(cd "$P" && pwd -P)"
mkdir -p "$P/src" "$P/site" "$TL_TMP/outside"

reset() { rm -f "$SS" "$ST/site-visual-evidence.json" "$ST/site-vloops.json" "$ST/live-publish-evidence.json" "$ST/subagent-spawns.jsonl"; }
prompt_input() { jq -cn --arg p "$1" '{hook_event_name:"UserPromptSubmit", prompt:$p}'; }
post_input() { jq -cn --arg t "$1" --argjson i "$2" --arg d "${3:-$P}" '{hook_event_name:"PostToolUse", tool_name:$t, tool_input:$i, cwd:$d}'; }
shell_post() { post_input Bash "$(jq -cn --arg c "$1" '{command:$c}')" "${2:-$P}"; }
sj() { jq -r "$1" "$SS" 2>/dev/null || true; }
assert_no_session() {
  if [[ ! -e "$SS" && "$TL_STATUS" == 0 && -z "$TL_OUT" ]]; then tl_pass "$1"; else tl_fail "$1 (status=$TL_STATUS out=${TL_OUT:0:200} session=$([[ -e "$SS" ]] && echo present || echo absent))"; fi
}

# ------------------------------------------------------------------ file tools
reset; dg_run "$P" "$H" "$(post_input Edit '{"file_path":"site/index.html"}')"
assert_eq "session: site/ edit status" "0" "$TL_STATUS"
assert_eq "session: site/ edit activates session" "true" "$(sj .active)"
assert_eq "session: site/ edit touch reason" "edit:site/index.html" "$(sj .touch_reason)"
assert_eq "session: the edit is counted" "1" "$(sj .edit_seq)"
assert_eq "session: the session is stamped with its project" "$P_REAL" "$(sj .scope)"
assert_eq "session: the branch is stamped for information" "main" "$(sj .branch)"
assert_eq "session: site/ edit leaves push_intent false" "false" "$(sj .push_intent)"
assert_eq "session: site/ edit writes nothing to stdout" "" "$TL_OUT"
dg_run "$P" "$H" "$(post_input MultiEdit '{"file_path":"site/b.html"}')"
assert_eq "session: second edit updates touch reason" "edit:site/b.html" "$(sj .touch_reason)"
assert_eq "session: second edit moves the counter (R9-13)" "2" "$(sj .edit_seq)"

reset; dg_run "$P" "$H" "$(post_input Write "{\"file_path\":\"$P/site/help/a.html\"}")"
assert_eq "session: absolute site path inside the project is recorded" "edit:$P/site/help/a.html" "$(sj .touch_reason)"
reset; dg_run "$P" "$H" "$(post_input Write '{"file_path":"help/a.html"}' "$P/site")"
assert_eq "session: a relative path is judged from the payload cwd" "1" "$(sj .edit_seq)"
reset; dg_run "$P" "$H" "$(post_input Edit '{"file_path":"src/app.js"}')"
assert_no_session "session: non-site edit leaves no session"
reset; dg_run "$P" "$H" "$(post_input Edit '{"file_path":"node_modules/x/site/readme.md"}')"
assert_no_session "session: a site/ directory inside node_modules is not the site (R9-02)"
reset; dg_run "$P" "$H" "$(post_input Edit '{"file_path":"../site/index.html"}')"
assert_no_session "session: a path escaping the project is not the site (R9-02)"
reset; dg_run "$P" "$H" "$(post_input apply_patch '{"input":"*** Begin Patch\n*** Update File: site/x.html\n@@\n-a\n+b\n*** End Patch"}')"
assert_eq "session: apply_patch to a site file is recorded" "true" "$(sj .active)"
reset; dg_run "$P" "$H" "$(post_input Read '{"file_path":"site/index.html"}')"
assert_no_session "session: unrelated tools are ignored"

# ------------------------------------------------------------------ shell writes (R9-05)
reset; dg_run "$P" "$H" "$(shell_post "sed -i 's/a/b/' site/help/index.html")"
assert_eq "session: a sed -i into the site is a site edit (R9-05)" "true" "$(sj .active)"
reset; dg_run "$P" "$H" "$(shell_post 'printf x > site/index.html')"
assert_eq "session: a redirect into the site is a site edit (R9-05)" "edit:$P_REAL/site/index.html" "$(sj .touch_reason)"
reset; dg_run "$P" "$H" "$(post_input exec_command '{"command":"cp /tmp/a site/new.html"}')"
assert_eq "session: exec_command cp into the site is a site edit (R9-05)" "true" "$(sj .active)"
reset; dg_run "$P" "$H" "$(shell_post 'cat site/index.html')"
assert_no_session "session: reading the site starts no session"
reset; dg_run "$P" "$H" "$(shell_post 'printf x > src/a.js')"
assert_no_session "session: a shell write outside the site starts no session"

# ------------------------------------------------------------------ pushes (R9-01, R9-06)
reset; dg_run "$P" "$H" "$(shell_post 'git push origin main')"
assert_no_session "session: a push never creates a site session (R9-01)"
dg_run "$P" "$H" "$(post_input Edit '{"file_path":"site/index.html"}')"
dg_run "$P" "$H" "$(shell_post 'git push origin main')"
assert_eq "session: a push to the default branch after site edits records push intent" "true" "$(sj .push_intent)"
assert_eq "session: push intent does not move the edit counter" "1" "$(sj .edit_seq)"
assert_eq "session: push intent is the touch reason" "push-intent" "$(sj .touch_reason)"
reset; dg_run "$P" "$H" "$(post_input Edit '{"file_path":"site/index.html"}')"
dg_run "$P" "$H" "$(shell_post 'git -C . push origin main')"
assert_eq "session: a global option does not hide the push (R9-06)" "true" "$(sj .push_intent)"
reset; dg_run "$P" "$H" "$(post_input Edit '{"file_path":"site/index.html"}')"
git -C "$P" checkout -q -b feature/main-nav
dg_run "$P" "$H" "$(shell_post 'git push origin feature/main-nav')"
assert_eq "session: a feature branch whose name contains main is not a publish (R9-06)" "false" "$(sj .push_intent)"
git -C "$P" checkout -q main
reset; dg_run "$P" "$H" "$(post_input Edit '{"file_path":"site/index.html"}')"
dg_run "$P" "$H" "$(shell_post "grep -rn 'git push' docs/")"
assert_eq "session: a command that only mentions git push records nothing (R9-06)" "false" "$(sj .push_intent)"
dg_run "$P" "$H" "$(shell_post 'git status')"
assert_eq "session: other shell commands are ignored" "1" "$(sj .edit_seq)"


# ------------------------------------------------------------------ a branch switch keeps the session (review r1)
reset; dg_run "$P" "$H" "$(post_input Edit '{"file_path":"site/index.html"}')"
git -C "$P" checkout -q -b tmpx
dg_run "$P" "$H" "$(shell_post 'git push origin tmpx:main')"
assert_eq "session: a push of tmpx:main after a branch switch is a publish" "true" "$(sj .push_intent)"
assert_eq "session: the session survived the switch" "1" "$(sj .edit_seq)"
dg_run "$P" "$H" "$(post_input Edit '{"file_path":"site/b.html"}')"
assert_eq "session: edits on the new branch continue the same session" "2" "$(sj .edit_seq)"
assert_eq "session: the branch stamp follows" "tmpx" "$(sj .branch)"
git -C "$P" checkout -q main

# ------------------------------------------------------------------ writes the analysis cannot name (review r1)
reset; rm -f "$ST/site-tree-digest"; mkdir -p "$P/site"
dg_run "$P" "$H" "$(shell_post 'ls -la')"
assert_no_session "session: a read-only command starts nothing"
dg_run "$P" "$H" "$(shell_post 'make build')"
assert_no_session "session: the first non-read-only look only records the baseline"
echo changed >"$P/site/gen.html"
dg_run "$P" "$H" "$(shell_post 'bash gen.sh')"
assert_eq "session: a script that wrote the site is seen through the tree content (R9-05)" "true" "$(sj .active)"
assert_contains "session: the reason says the tree changed" "$(sj .touch_reason)" "site tree changed"
reset; echo more >>"$P/site/gen.html"
dg_run "$P" "$H" "$(shell_post "git apply p.diff")"
assert_eq "session: git apply into the site starts a session" "true" "$(sj .active)"
reset; echo more >>"$P/site/gen.html"
dg_run "$P" "$H" "$(shell_post "find . -name '*.html' -exec sed -i s/a/b/ {} +")"
assert_eq "session: find -exec sed into the site starts a session" "true" "$(sj .active)"
reset
dg_run "$P" "$H" "$(shell_post 'git status')"
assert_no_session "session: an unchanged site tree starts nothing"
reset; dg_run "$P" "$H" "$(post_input NotebookEdit '{"notebook_path":"site/a.ipynb","new_source":"x"}')"
assert_eq "session: a NotebookEdit under the site starts a session" "true" "$(sj .active)"
reset; dg_run "$P" "$H" "$(post_input mcp__filesystem__write_file '{"path":"site/q.html","content":"x"}')"
assert_eq "session: an MCP filesystem write under the site starts a session" "true" "$(sj .active)"
reset; dg_run "$P" "$H" "$(post_input mcp__filesystem__write_file '{"path":"src/q.html","content":"x"}')"
assert_no_session "session: an MCP write elsewhere starts nothing"
git -C "$P" checkout -q -- . 2>/dev/null || true
rm -rf "$P/site"; mkdir -p "$P/site"

# ------------------------------------------------------------------ project / branch scope (R9-08)
jq '.scope="/elsewhere" | .edit_seq=7 | .push_intent=true' "$SS" >"$ST/s.t" && mv "$ST/s.t" "$SS"
dg_run "$P" "$H" "$(post_input Edit '{"file_path":"site/index.html"}')"
assert_eq "session: a session left by another project starts afresh" "1" "$(sj .edit_seq)"
assert_eq "session: the fresh session is in this scope" "$P_REAL" "$(sj .scope)"
assert_eq "session: the fresh session carries no stale push intent" "false" "$(sj .push_intent)"

# ------------------------------------------------------------------ prompts (R9-02, R9-12)
reset; dg_run "$P" "$H" "$(prompt_input 'please update the help center page')"
assert_no_session "session: a site prompt alone starts no session"
reset; dg_run "$P" "$H" "$(post_input Edit '{"file_path":"site/index.html"}')"
dg_run "$P" "$H" "$(prompt_input 'please update the help center page')"
assert_eq "session: a site prompt annotates the existing session" "site-intent" "$(sj .touch_reason)"
assert_eq "session: a plain site prompt has no live claim" "false" "$(sj .live_claim_pending)"
assert_eq "session: a prompt does not move the edit counter" "1" "$(sj .edit_seq)"
dg_run "$P" "$H" "$(prompt_input 'edit site/index.html and publish it live')"
assert_eq "session: a live claim prompt sets live_claim_pending" "true" "$(sj .live_claim_pending)"
dg_run "$P" "$H" "$(prompt_input 'refactor the parser module')"
assert_eq "session: an unrelated prompt changes nothing" "live-claim" "$(sj .touch_reason)"
printf '{}' >"$ST/site-visual-evidence.json"
dg_run "$P" "$H" "$(prompt_input 'delegate with silver-agent-claude to fix the homepage in site/')"
assert_eq "session: a delegation prompt keeps the session (R9-12)" "true" "$(sj .active)"
assert_eq "session: a delegation prompt still evaluates site intent (R9-12)" "site-intent" "$(sj .touch_reason)"
[[ -e "$ST/site-visual-evidence.json" ]] && tl_pass "session: a delegation prompt keeps the evidence" || tl_fail "session: delegation prompt deleted evidence"
dg_run "$P" "$H" "$(post_input Task '{"prompt":"run silver-agent-codex on the site"}')"
assert_eq "session: a delegation spawn keeps the session (R9-12)" "true" "$(sj .active)"

# ------------------------------------------------------------------ inert / invalid input
reset; dg_run "$P" "$H" "$(jq -cn '{hook_event_name:"Stop", tool_name:"Edit", tool_input:{file_path:"site/a.html"}}')"
assert_no_session "session: events other than PostToolUse/UserPromptSubmit are ignored"
reset; dg_run "$P" "$H" "not json at all"
assert_no_session "session: unparsable stdin is a no-op"
reset; dg_run "$P" "$H" ""
assert_no_session "session: empty stdin is a no-op"
reset; dg_run_closed_stdin "$P" "$H"
assert_no_session "session: unreadable stdin is a no-op"
reset; dg_run_nojq "$P" "$H" "$(post_input Edit '{"file_path":"site/index.html"}')"
assert_no_session "session: missing jq is a no-op"
reset; dg_run "$TL_TMP/outside" "$H" "$(post_input Edit '{"file_path":"site/index.html"}' "$TL_TMP/outside")"
assert_no_session "session: outside an SB project is a no-op"
reset; dg_run "$P/src" "$H" "$(post_input Edit '{"file_path":"site/index.html"}' "$P")"
assert_eq "session: walk-up finds the project from a subdirectory" "true" "$(sj .active)"
reset; dg_run_gate_missing "$P" "$H" "$(post_input Edit '{"file_path":"site/index.html"}')"
assert_no_session "session: a missing project gate fails open"
reset; dg_run_nolib "$H" "$(post_input Edit '{"file_path":"site/index.html"}')"
assert_no_session "session: missing lib dir fails open"
reset; dg_project "$TL_TMP/plain" '{"sb_initiated":true}'
dg_run "$TL_TMP/plain" "$H" "$(post_input Edit '{"file_path":"site/index.html"}' "$TL_TMP/plain")"
assert_no_session "session: a project without a site_profile records nothing (R9-02)"
dg_project "$TL_TMP/off" '{"sb_initiated":true,"site_profile":{"enabled":false}}'
dg_run "$TL_TMP/off" "$H" "$(post_input Edit '{"file_path":"site/index.html"}' "$TL_TMP/off")"
assert_no_session "session: site_profile.enabled false records nothing"

tl_results
