#!/usr/bin/env bash
# Review package G3, repair round 4: the agent-wrote-source trace records WHAT was written (hooks/lib/agent-writes.sh),
# so a scratch write outside the project's source never puts a chat-only session over the user's own pending edits
# behind the Stop planning floor, while a write that can be under source still does.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
unset SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT SILVER_BULLET_STATE_FILE SB_E2E_ENTERPRISE_MATRIX SB_AGENT_CLAUDE_DELEGATE
ec_project
SD="${SB_RUNTIME_STATE_DIR:?}"
SC="$TL_REPO_ROOT/hooks/stop-check.sh"
TF="$TL_REPO_ROOT/hooks/trivial-file-clear.sh"
MARK="$SD/files-written"
run() { tl_run_stdin "$2" bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$1"; }
reason() { jq -r '.reason // ""' <<<"$TL_OUT"; }
sbash() { jq -cn --arg c "$1" --arg t "${2:-Bash}" '{hook_event_name:"PostToolUse",tool_name:$t,tool_input:{command:$c,cmd:$c},tool_response:{}}'; }
swrite() { jq -cn --arg p "$1" --arg t "${2:-Write}" '{hook_event_name:"PostToolUse",tool_name:$t,tool_input:{file_path:$p,content:"x"},tool_response:{}}'; }
pass() { tl_pass "$1"; }
fail() { tl_fail "$1"; }
stopped() { run "$SC" "${1:-"{\"hook_event_name\":\"Stop\",\"session_id\":\"s\"}"}"; grep -q '"block"' <<<"$TL_OUT"; }
SESSION_FILE="$SD/session-start-time"
export SILVER_BULLET_SESSION_START_FILE="$SESSION_FILE"
fresh() {
  rm -f "$MARK" "$SD/trivial" "$SD/state" "$SD/stall-block" "$SD"/.files-written.*
  date +%s >"$SESSION_FILE"
  : >"$SD/state"
}
git -C "$EC_PROJ" config user.email a@b; git -C "$EC_PROJ" config user.name n
rm -rf "$EC_PROJ/src"; mkdir -p "$EC_PROJ/src" "$EC_PROJ/docs"
printf 'a\n' >"$EC_PROJ/src/app.js"; printf 'd\n' >"$EC_PROJ/docs/a.txt"
git -C "$EC_PROJ" add -A >/dev/null; git -C "$EC_PROJ" commit -qm init
printf 'user edit\n' >>"$EC_PROJ/src/app.js"   # the user's own pending change
TMPD="$(mktemp -d)"

# ---- honest chat-only variants: a write outside the project's source never engages the floor ----------------
for c in 'git diff > '"$TMPD"'/review.diff' 'pytest 2>&1 | tee '"$TMPD"'/test.log' 'echo hi > '"$TMPD"'/scratch.txt' 'cat src/app.js > '"$HOME"'/notes.txt' 'echo n > docs/notes.md'; do
  fresh
  run "$TF" "$(sbash "$c")"
  if stopped; then fail "chat-only session, scratch write ($c): Stop must pass"; else pass "chat-only session, scratch write ($c): Stop passes"; fi
  if stopped '{"hook_event_name":"Stop","session_id":"s","stop_hook_active":true}'; then fail "stop_hook_active too ($c)"; else pass "stop_hook_active too ($c)"; fi
done
fresh
run "$TF" "$(swrite "$TMPD/notes.md")"
if stopped; then fail "Write tool outside the project: Stop must pass"; else pass "Write tool outside the project: Stop passes"; fi
run "$TF" "$(swrite docs/b.md Edit)"
if stopped; then fail "Edit of docs/: Stop must pass"; else pass "Edit of docs/: Stop passes"; fi
fresh
run "$TF" "$(sbash 'ls src; git status --short')"
assert_file_absent "a read-only command leaves no trace" "$MARK"

# ---- writes that can be under source still engage the floor ---------------------------------------------------
# $TL_WRITES are shell commands (as the agent would send them) that write project source.
for c in 'echo x > src/a.js' 'echo x >> ./src/../src/a.js' 'sed -i s/a/b/ src/app.js' 'tee src/a.js </dev/null' 'cp docs/a.txt src/b.js' 'mv docs/a.txt src/c.js' \
  'python3 -c "open(\"src/a.js\",\"w\").write(\"x\")"' $'cat <<EOF > src/h.js\nhi\nEOF' 'echo x > "$D/a.js"' 'echo x > "$(pwd)/src/a.js"' 'tar -xf a.tar'; do
  fresh
  run "$TF" "$(sbash "$c")"
  if stopped; then pass "source write ($c): the planning floor applies"; else fail "source write ($c): the planning floor must apply"; fi
done
for t in Write Edit MultiEdit; do
  fresh
  run "$TF" "$(swrite "$EC_PROJ/src/new.js" $t)"
  if stopped; then pass "$t into src: floor applies"; else fail "$t into src: floor must apply"; fi
done
fresh
run "$TF" "$(swrite src/rel.js)"
if stopped; then pass "relative Write path resolves under the project: floor applies"; else fail "relative Write path resolves under the project"; fi
fresh
run "$TF" "$(jq -cn --arg p "$EC_PROJ/src/n.js" '{hook_event_name:"PostToolUse",tool_name:"apply_patch",tool_input:{command:("*** Begin Patch\n*** Add File: " + $p + "\n+x\n*** End Patch\n")},tool_response:{}}')"
if stopped; then pass "apply_patch into src: floor applies"; else fail "apply_patch into src: floor must apply"; fi

# ---- a project-configured source pattern decides ---------------------------------------------------------------
ec_cfg '{"config_version":"0.40.0","sb_initiated":true,"project":{"src_pattern":"/lib/","src_exclude_pattern":"\\.gen\\."},"skills":{}}'
mkdir -p "$EC_PROJ/lib"; printf 'l\n' >"$EC_PROJ/lib/x.js"
fresh
run "$TF" "$(sbash 'echo x > src/a.js')"
if stopped; then fail "custom src_pattern /lib/: a write into src/ is not source"; else pass "custom src_pattern /lib/: a write into src/ is not source"; fi
fresh
run "$TF" "$(sbash 'echo x > lib/a.js')"
if stopped; then pass "custom src_pattern /lib/: a write into lib/ is source"; else fail "custom src_pattern /lib/: a write into lib/ is source"; fi
fresh
run "$TF" "$(sbash 'echo x > lib/a.gen.js')"
if stopped; then fail "src_exclude_pattern: a generated file is not source"; else pass "src_exclude_pattern: a generated file is not source"; fi
ec_cfg '{"config_version":"0.40.0","sb_initiated":true,"skills":{}}'

# ---- fail closed when the target cannot be determined ----------------------------------------------------------
fresh
run "$TF" 'not json at all'
assert_file_exists "an unreadable payload still leaves a trace" "$MARK"
if stopped; then pass "unreadable payload: counted as possible source (fail closed)"; else fail "unreadable payload: counted as possible source"; fi
fresh
run "$TF" "$(sbash 'echo "unterminated > src/a.js')"
if stopped; then pass "unparsable shell write naming src: floor applies"; else fail "unparsable shell write naming src: floor applies"; fi
fresh
run "$TF" "$(sbash 'echo "unterminated')"
if stopped; then pass "unparsable shell with no target: counted as possible source (fail closed)"; else fail "unparsable shell with no target"; fi
fresh
run "$TF" "$(jq -cn '{hook_event_name:"PostToolUse",tool_name:"Write",tool_input:{content:"x"}}')"
if stopped; then pass "a Write without a path: counted as possible source"; else fail "a Write without a path"; fi

# ---- the trace: format, tamper safety, session scoping ----------------------------------------------------------
fresh
run "$TF" "$(sbash "echo x > $TMPD/a; echo y > $TMPD/a")"
assert_eq "the header carries the session start" "#$(cat "$SESSION_FILE")" "$(head -n1 "$MARK")"
assert_eq "a repeated target is recorded once" 1 "$(grep -c -Fx "f$(cd "$TMPD" && pwd -P)/a" "$MARK")"
rm -f "$MARK"; ln -s "$TMPD/elsewhere" "$MARK"
run "$TF" "$(sbash 'echo x > src/a.js')"
assert_file_absent "a symlinked trace is never written through" "$TMPD/elsewhere"
rm -f "$MARK"
fresh
mkdir "$MARK"
run "$TF" "$(sbash 'echo x > src/a.js')"
assert_eq "a trace that is a directory is tolerated" 0 "$TL_STATUS"
rmdir "$MARK"
# a trace from an earlier session never counts, and the next write starts a fresh one
fresh
printf '#1\nf%s/src/app.js\n' "$EC_PROJ" >"$MARK"
if stopped; then fail "a trace from an earlier session is ignored"; else pass "a trace from an earlier session is ignored"; fi
run "$TF" "$(sbash "echo x > $TMPD/a")"
assert_eq "an old trace is replaced, not extended" "#$(cat "$SESSION_FILE")" "$(head -n1 "$MARK")"
assert_not_contains "the old entries are gone" "$(cat "$MARK")" "app.js"
fresh
rm -f "$SESSION_FILE"
run "$TF" "$(sbash 'echo x > src/a.js')"
if stopped; then fail "unknown session start: the trace is not trusted"; else pass "unknown session start: the trace is not trusted"; fi
date +%s >"$SESSION_FILE"
# a hook-written trace cannot be forged by a shell command (G2 state-tamper guard)
DCC="$TL_REPO_ROOT/hooks/dev-cycle-check.sh"
run "$DCC" "$(jq -cn --arg c "echo 'f$EC_PROJ/src/app.js' >> $MARK" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}')"
assert_contains "the trace is in the guarded state directory" "$TL_OUT" "deny"
# the number of distinct targets is bounded; past the bound the trace says "anywhere"
fresh
lines=""; i=0; while (( i < 520 )); do lines="${lines}echo x > $TMPD/f$i; "; i=$((i+1)); done
run "$TF" "$(sbash "$lines")"
assert_eq "past the bound the trace says anywhere" 1 "$(grep -c '^\*$' "$MARK")"
if stopped; then pass "past the bound: fail closed"; else fail "past the bound: fail closed"; fi
run "$TF" "$(sbash 'echo x > '"$TMPD"'/more')"
assert_eq "the 'anywhere' line is not repeated" 1 "$(grep -c '^\*$' "$MARK")"

# ---- the legacy trivial marker is still cleared by every write ---------------------------------------------------
fresh
: >"$SD/trivial"
run "$TF" "$(sbash "echo x > $TMPD/a")"
assert_file_absent "a write clears the legacy trivial marker" "$SD/trivial"
: >"$SD/trivial"
run "$TF" "$(sbash 'cat src/app.js')"
assert_file_exists "a read keeps it" "$SD/trivial"
rm -rf "$TMPD"
tl_results
