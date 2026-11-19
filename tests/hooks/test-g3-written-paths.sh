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
mkdir -p "$TMPD/other"

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

# ---- resolution: symlinks, loops, a cwd in the payload, tree extracts below the root -----------------------------
fresh
mkdir -p "$TMPD/outside-src"
mv "$EC_PROJ/src" "$EC_PROJ/src.real"; ln -s "$TMPD/outside-src" "$EC_PROJ/src"
run "$TF" "$(sbash 'echo x > src/a.js')"
if stopped; then pass "a source directory symlinked outside the project is still source by name"; else fail "symlinked source directory"; fi
rm -f "$EC_PROJ/src"; mv "$EC_PROJ/src.real" "$EC_PROJ/src"
fresh
ln -s "$TMPD/loop-b" "$TMPD/loop-a"; ln -s "$TMPD/loop-a" "$TMPD/loop-b"
run "$TF" "$(sbash "echo x > $TMPD/loop-a")"
assert_file_exists "a symlink loop is recorded lexically, not dropped" "$MARK"
if stopped; then fail "a symlink loop outside the project is not source"; else pass "a symlink loop outside the project is not source"; fi
fresh
run "$TF" "$(jq -cn --arg c "$EC_PROJ/src" '{hook_event_name:"PostToolUse",tool_name:"Write",cwd:$c,tool_input:{file_path:"x.js",content:"x"}}')"
if stopped; then pass "a relative Write path resolves against the payload cwd: src"; else fail "payload cwd"; fi
fresh
run "$TF" "$(jq -cn --arg c "$EC_PROJ/docs" '{hook_event_name:"PostToolUse",tool_name:"Write",cwd:$c,tool_input:{file_path:"x.js",content:"x"}}')"
if stopped; then fail "a relative Write path resolves against the payload cwd: docs is not source"; else pass "payload cwd: docs is not source"; fi
fresh
run "$TF" "$(sbash 'cd src && tar -xf a.tar')"
if stopped; then pass "a tree extracted into src: floor applies"; else fail "tar in src"; fi
fresh
run "$TF" "$(sbash 'cd docs && tar -xf a.tar')"
if stopped; then fail "a tree extracted into docs is not source"; else pass "a tree extracted into docs is not source"; fi
fresh
run "$TF" "$(sbash '')"
assert_file_absent "an empty command leaves no trace" "$MARK"
# the reader refuses a missing or linked trace
source "$TL_REPO_ROOT/hooks/lib/planning-floor.sh"
source "$TL_REPO_ROOT/hooks/lib/agent-writes.sh"
if sb_aw_wrote_source "$EC_PROJ" "$SD"; then fail "no trace: not source"; else pass "no trace: not source"; fi
rm -f "$MARK"
fresh
run "$TF" "$(sbash "tar -xf a.tar -C $TMPD")"
if stopped; then fail "a tree extracted outside the project is not source"; else pass "a tree extracted outside the project is not source"; fi
fresh
run "$TF" "$(sbash 'echo x > "/elsewhere/$D/a"')"
if stopped; then fail "an unresolved path under an absolute directory outside the project is not source"; else pass "an unresolved path outside the project is not source"; fi

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
run "$TF" ''
assert_file_exists "an empty payload leaves a trace" "$MARK"
fresh
run "$TF" 'not json at all'
assert_file_exists "an unreadable payload still leaves a trace" "$MARK"
if stopped; then pass "unreadable payload: counted as possible source (fail closed)"; else fail "unreadable payload: counted as possible source"; fi
fresh
NOPY="$(tl_path_without python3)"
tl_run_stdin "$(sbash 'echo x > /nowhere/a')" env PATH="$NOPY" bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$TF"
if stopped; then pass "python3 unavailable: a shell call counts as possible source (fail closed)"; else fail "python3 unavailable: fail closed"; fi
fresh
run "$TF" "$(jq -cn '{hook_event_name:"PostToolUse",tool_name:"NotebookEdit",tool_input:{}}')"
if stopped; then pass "a file tool whose path is unknown: counted as possible source"; else fail "a file tool whose path is unknown"; fi
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
assert_eq 'an entry is <session start><TAB>f<path>' "$(cat "$SESSION_FILE")"$'\t'"f$(cd "$TMPD" && pwd -P)/a" "$(head -n1 "$MARK")"
assert_eq "a repeated target is recorded once" 1 "$(grep -c -F "f$(cd "$TMPD" && pwd -P)/a" "$MARK")"
# a link at the trace path is never written through, and is read as an unknown write (fail closed)
fresh
printf '%s\tf%s/docs/a.txt\n' "$(cat "$SESSION_FILE")" "$EC_PROJ" >"$TMPD/target"
cp "$TMPD/target" "$TMPD/target.orig"
ln -s "$TMPD/target" "$MARK"
run "$TF" "$(sbash 'echo x > src/a.js')"
assert_eq "a symlinked trace is not written through" "" "$(cmp "$TMPD/target" "$TMPD/target.orig" 2>&1)"
if stopped; then pass "a symlinked trace counts as an unknown write: Stop applies the floor"; else fail "a symlinked trace fails closed"; fi
rm -f "$MARK"
fresh
mkdir "$MARK"
run "$TF" "$(sbash 'echo x > '"$TMPD"'/a')"
assert_eq "a trace that is a directory is tolerated by the recorder" 0 "$TL_STATUS"
if stopped; then pass "a trace that is a directory counts as an unknown write"; else fail "a directory trace fails closed"; fi
rmdir "$MARK"
# a trace from an earlier session never counts; this session's lines are appended after it
fresh
printf '1\tf%s/src/app.js\n' "$EC_PROJ" >"$MARK"
if stopped; then fail "a trace from an earlier session is ignored"; else pass "a trace from an earlier session is ignored"; fi
run "$TF" "$(sbash "echo x > $TMPD/a")"
assert_eq "the old line is kept, this session's is added" 2 "$(wc -l <"$MARK" | tr -d ' ')"
if stopped; then fail "the old session's source write still does not count"; else pass "the old session's source write still does not count"; fi
# a file past 256 KB is rewritten with this session's lines only
fresh
head -c 300000 /dev/zero | tr '\0' 'x' | sed 's/^/1\t/' >"$MARK"; printf '\n' >>"$MARK"
run "$TF" "$(sbash "echo x > $TMPD/a")"
assert_eq "an oversized trace is pruned to this session" 1 "$(wc -l <"$MARK" | tr -d ' ')"
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
assert_eq "past the bound the trace says anywhere" 1 "$(awk -F'\t' '$2 == "*"' "$MARK" | wc -l | tr -d ' ')"
if stopped; then pass "past the bound: fail closed"; else fail "past the bound: fail closed"; fi
run "$TF" "$(sbash 'echo x > '"$TMPD"'/more')"
assert_eq "the 'anywhere' line is not repeated" 1 "$(awk -F'\t' '$2 == "*"' "$MARK" | wc -l | tr -d ' ')"

# ---- r4: bulk edits through the root, globs, unresolved first components, other cwds --------------------------------
sbashc() { jq -cn --arg c "$1" --arg d "$2" '{hook_event_name:"PostToolUse",tool_name:"Bash",cwd:$d,tool_input:{command:$c},tool_response:{}}'; }
for c in 'git checkout HEAD~1 -- .' 'cp -r /tmp/d .' 'rsync -a /tmp/d/ .' 'rsync -a /tmp/d/ ./' 'cp -r /tmp/d/. .' "find . -name '*.js' -exec sed -i s/a/b/ {} +" \
  'find . -type f | xargs sed -i s/a/b/' 'git ls-files -z | xargs -0 sed -i s/a/b/' 'find . -name app.js -delete' "find $EC_PROJ -exec sed -i s/a/b/ {} +" \
  'sed -i s/a/b/ */*.js' 'sed -i s/a/b/ **/*.js' 'sed -i s/a/b/ s*/app.js' 'echo x > sr?/a.js' 'echo x > [s]rc/a.js' 'cp /tmp/x s*/' \
  'sed -i s/a/b/ $(git ls-files)' 'echo x > "$P/src/a.js"' 'cd "$P" && echo x > src/a.js'; do
  fresh
  run "$TF" "$(sbash "$c")"
  if stopped; then pass "bulk/glob/unresolved write ($c): the planning floor applies"; else fail "bulk/glob/unresolved write ($c): the floor must apply"; fi
done
# from a cwd outside the project the same idioms are unknown targets
for c in 'echo x > "$P/src/a.js"' "grep -rl a $EC_PROJ/src | xargs sed -i s/a/b/" "find $EC_PROJ -exec sed -i s/a/b/ {} +" 'cd "$P" && echo x > src/a.js' "cp -r /tmp/d $EC_PROJ" "echo x > $EC_PROJ/s*/a.js"; do
  fresh
  run "$TF" "$(sbashc "$c" /tmp)"
  if stopped; then pass "from cwd /tmp ($c): the planning floor applies"; else fail "from cwd /tmp ($c): the floor must apply"; fi
done
# honest scratch writes never count
for c in 'sed -i s/a/b/ docs/*.md' 'echo x > docs/a.md' "echo x > $TMPD/f" 'cp docs/a.txt /tmp/copy.txt' 'echo x > "/elsewhere/$D/a"' "git -C $TMPD/other status > $TMPD/o.txt" 'echo x > ~/n.txt' "cat src/app.js > $SD/scratch"; do
  fresh
  run "$TF" "$(sbash "$c")"
  if stopped; then fail "honest write ($c): Stop must pass"; else pass "honest write ($c): Stop passes"; fi
done
for c in "echo x > $TMPD/f" "cp a $TMPD/b" 'echo x > /tmp/y'; do
  fresh
  run "$TF" "$(sbashc "$c" /tmp)"
  if stopped; then fail "from cwd /tmp, honest write ($c): Stop must pass"; else pass "from cwd /tmp, honest write ($c): Stop passes"; fi
done
# an apply_patch with a relative path resolves against the payload cwd, not the hook's cwd
fresh
PL="$(jq -cn --arg c "$EC_PROJ" '{hook_event_name:"PostToolUse",tool_name:"apply_patch",cwd:$c,tool_input:{command:"*** Begin Patch\n*** Add File: src/n.js\n+x\n*** End Patch\n"},tool_response:{}}')"
tl_run_stdin "$PL" bash -c 'cd /tmp && exec bash "$1"' _ "$TF"
if stopped; then pass "apply_patch with a relative path resolves against the payload cwd"; else fail "apply_patch relative path against the payload cwd"; fi
# NotebookEdit and MCP file writes
fresh
run "$TF" "$(jq -cn --arg p "$EC_PROJ/src/n.ipynb" '{hook_event_name:"PostToolUse",tool_name:"NotebookEdit",tool_input:{notebook_path:$p,new_source:"x"}}')"
if stopped; then pass "NotebookEdit of a source notebook: floor applies"; else fail "NotebookEdit into src"; fi
fresh
run "$TF" "$(jq -cn --arg p "$EC_PROJ/src/m.js" '{hook_event_name:"PostToolUse",tool_name:"mcp__fs__write_file",tool_input:{path:$p,content:"x"}}')"
if stopped; then pass "an MCP file write into src: floor applies"; else fail "MCP write into src"; fi
fresh
run "$TF" "$(jq -cn --arg p "$TMPD/m.txt" '{hook_event_name:"PostToolUse",tool_name:"mcp__fs__write_file",tool_input:{path:$p,content:"x"}}')"
if stopped; then fail "an MCP file write outside the project: Stop must pass"; else pass "an MCP file write outside the project: Stop passes"; fi
fresh
run "$TF" "$(jq -cn '{hook_event_name:"PostToolUse",tool_name:"mcp__github__create_issue",tool_input:{title:"t",body:"b"}}')"
assert_file_absent "an MCP API call without a path writes no local file" "$MARK"

# a relative target with a static first component and an unresolved tail is a `d` entry under the project
fresh
run "$TF" "$(sbash 'echo x > src/$N.js')"
if stopped; then pass "src/\$N.js: an unresolved tail under a static directory counts"; else fail "src/\$N.js"; fi
fresh
run "$TF" "$(sbash 'echo x > docs/$N.md')"
if stopped; then pass "docs/\$N.md: a project path with an unresolved tail counts (fail closed)"; else fail "docs/\$N.md counts"; fi
# a patch tool with no readable path is an unknown write
fresh
run "$TF" "$(jq -cn '{hook_event_name:"PostToolUse",tool_name:"apply_patch",tool_input:{command:"nothing"}}')"
if stopped; then pass "apply_patch without a path: counted as possible source"; else fail "apply_patch without a path"; fi
# a glob below the root counts when what it matches is source under a custom pattern
ec_cfg '{"config_version":"0.40.0","sb_initiated":true,"project":{"src_pattern":"/lib/gen/"},"skills":{}}'
mkdir -p "$EC_PROJ/lib/gen" "$EC_PROJ/lib/other"; printf 'g\n' >"$EC_PROJ/lib/gen/x.js"
fresh
run "$TF" "$(sbash 'sed -i s/a/b/ lib/g*/x.js')"
if stopped; then pass "a glob that expands into a source directory counts"; else fail "glob expanding into source"; fi
fresh
run "$TF" "$(sbash 'sed -i s/a/b/ lib/o*/x.js')"
if stopped; then fail "a glob that expands outside source does not count"; else pass "a glob that expands outside source does not count"; fi
ec_cfg '{"config_version":"0.40.0","sb_initiated":true,"skills":{}}'

# ---- concurrent recorders never lose an entry (header-less append-only trace) --------------------------------------
A="$(jq -cn --arg p "$EC_PROJ/src/a.js" '{hook_event_name:"PostToolUse",tool_name:"Write",tool_input:{file_path:$p}}')"
B="$(jq -cn --arg p "$TMPD/zz" '{hook_event_name:"PostToolUse",tool_name:"Write",tool_input:{file_path:$p}}')"
lost=0; N=40
for i in $(seq "$N"); do
  fresh
  (cd "$EC_PROJ" && printf '%s' "$A" | bash "$TF" >/dev/null 2>&1) & p1=$!
  (cd "$EC_PROJ" && printf '%s' "$B" | bash "$TF" >/dev/null 2>&1) & p2=$!
  wait "$p1" "$p2"
  grep -q "src/a.js" "$MARK" || lost=$((lost + 1))
done
assert_eq "40 concurrent first writes: no src entry lost" 0 "$lost"

# ---- read-only chains skip the analysis ----------------------------------------------------------------------------
source "$TL_REPO_ROOT/hooks/lib/plain-read-only.sh"
for c in 'git status && git diff | head -20' 'ls src; git status --short' 'ls 2>/dev/null | wc -l' 'cat src/app.js > /dev/null' 'git log --oneline 2>&1 | head -5' 'ls || echo' 'ls 2> /dev/null'; do
  if sb_pf_plain_read_only_chain "$c"; then pass "read-only chain: $c"; else fail "should be a read-only chain: $c"; fi
done
for c in 'ls > out' 'ls | tee x' 'ls >> x' 'echo $(date)' 'ls &' 'ls | sed -i s/a/b/ f' 'git status &> x' "ls 'a b'" 'ls | sort -o x' 'ls &&' $'ls\ngit status' 'ls > /dev/nullx' 'ls > /tmp/x' 'ls >'; do
  if sb_pf_plain_read_only_chain "$c"; then fail "must go to the analysis: $c"; else pass "goes to the analysis: $c"; fi
done

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
