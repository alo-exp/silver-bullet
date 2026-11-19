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
MARKBASE="$SD/files-written"
MARK="$MARKBASE.x"
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
  rm -rf "$SD"/files-written* "$SD/trivial" "$SD/state" "$SD/stall-block" "$SD"/.files-written.*
  date +%s >"$SESSION_FILE"
  MARK="$MARKBASE.$(cat "$SESSION_FILE")"
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
assert_eq "an entry is f<path>, in the file of the session" "f$(cd "$TMPD" && pwd -P)/a" "$(head -n1 "$MARK")"
assert_eq "a repeated target is recorded once" 1 "$(grep -c -F "f$(cd "$TMPD" && pwd -P)/a" "$MARK")"
# a link at the trace path is never written through, and is read as an unknown write (fail closed)
fresh
printf 'f%s/docs/a.txt\n' "$EC_PROJ" >"$TMPD/target"
cp "$TMPD/target" "$TMPD/target.orig"
ln -s "$TMPD/target" "$MARK"
run "$TF" "$(sbash 'echo x > src/a.js')"
assert_eq "a symlinked trace is not written through" "" "$(cmp "$TMPD/target" "$TMPD/target.orig" 2>&1)"
if stopped; then pass "a symlinked trace counts as an unknown write: Stop applies the floor"; else fail "a symlinked trace fails closed"; fi
# a dangling link: the recorder leaves it alone, Stop still treats it as a write
fresh
ln -s "$TMPD/nowhere" "$MARK"
run "$TF" "$(sbash 'echo x > src/a.js')"
assert_file_absent "a dangling symlinked trace is not created through" "$TMPD/nowhere"
if stopped; then pass "a dangling symlinked trace counts as an unknown write"; else fail "a dangling symlinked trace fails closed"; fi
fresh
mkdir "$MARK"
run "$TF" "$(sbash 'echo x > '"$TMPD"'/a')"
assert_eq "a trace that is a directory is tolerated by the recorder" 0 "$TL_STATUS"
if stopped; then pass "a trace that is a directory counts as an unknown write"; else fail "a directory trace fails closed"; fi
# a FIFO at the trace path must not block the recorder (opening it would hang), and counts as an unknown write
fresh
mkfifo "$MARK"
( cd "$EC_PROJ" && printf '%s' "$(sbash 'echo x > src/a.js')" | bash "$TF" >/dev/null 2>&1 ) & fp=$!
waited=0; while kill -0 "$fp" 2>/dev/null && (( waited < 100 )); do sleep 0.1; waited=$((waited + 1)); done
if kill -0 "$fp" 2>/dev/null; then kill -TERM "$fp" 2>/dev/null; fail "a FIFO at the trace path hangs the recorder"; else pass "a FIFO at the trace path does not hang the recorder"; fi
wait "$fp" 2>/dev/null || true
if stopped; then pass "a FIFO trace counts as an unknown write"; else fail "a FIFO trace fails closed"; fi
rm -f "$MARK"
# a trace from an earlier session never counts; the first record of this session removes it
fresh
printf 'f%s/src/app.js\n' "$EC_PROJ" >"$MARKBASE.1"
if stopped; then fail "a trace from an earlier session is ignored"; else pass "a trace from an earlier session is ignored"; fi
run "$TF" "$(sbash "echo x > $TMPD/a")"
assert_file_absent "the first record of a session removes the earlier trace" "$MARKBASE.1"
assert_eq "this session's trace holds its own entry only" 1 "$(wc -l <"$MARK" | tr -d ' ')"
fresh
printf 'f%s/src/app.js\n' "$EC_PROJ" >"$MARKBASE.1"; mkdir "$MARKBASE.3"
run "$TF" "$(sbash "echo x > $TMPD/a")"
assert_file_absent "an earlier regular trace goes" "$MARKBASE.1"
assert_file_exists "an earlier directory under a trace name is left alone" "$MARKBASE.3"
rmdir "$MARKBASE.3"
# rotation, not rewriting: a trace this session already has is never replaced (its inode stays)
fresh
run "$TF" "$(sbash "echo x > $TMPD/a")"
ino1="$(ls -i "$MARK" | awk '{print $1}')"
for i in $(seq 30); do run "$TF" "$(sbash "echo x > $TMPD/b$i")"; done
assert_eq "a live trace is appended to, never rewritten" "$ino1" "$(ls -i "$MARK" | awk '{print $1}')"
fresh
rm -f "$SESSION_FILE"
run "$TF" "$(sbash 'echo x > src/a.js')"
if stopped; then fail "unknown session start: the trace is not trusted"; else pass "unknown session start: the trace is not trusted"; fi
rm -f "$MARKBASE".-
date +%s >"$SESSION_FILE"
# a hook-written trace cannot be forged by a shell command (G2 state-tamper guard)
DCC="$TL_REPO_ROOT/hooks/dev-cycle-check.sh"
run "$DCC" "$(jq -cn --arg c "echo 'f$EC_PROJ/src/app.js' >> $MARKBASE.$(cat "$SESSION_FILE")" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}')"
assert_contains "the trace is in the guarded state directory" "$TL_OUT" "deny"
run "$DCC" "$(jq -cn --arg c "mknod $MARKBASE.$(cat "$SESSION_FILE") p" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}')"
assert_contains "mknod into the state directory is refused too" "$TL_OUT" "deny"
# the number of distinct targets is bounded; past the bound the trace says "anywhere" and records nothing more
fresh
lines=""; i=0; while (( i < 520 )); do lines="${lines}echo x > $TMPD/f$i; "; i=$((i+1)); done
run "$TF" "$(sbash "$lines")"
assert_eq "past the bound the trace says anywhere" 1 "$(grep -c -Fx '*' "$MARK")"
assert_eq "and stops growing at the bound" 501 "$(wc -l <"$MARK" | tr -d ' ')"
if stopped; then pass "past the bound: fail closed"; else fail "past the bound: fail closed"; fi
run "$TF" "$(sbash 'echo x > '"$TMPD"'/more')"
assert_eq "the 'anywhere' line is not repeated" 1 "$(grep -c -Fx '*' "$MARK")"
assert_eq "nothing more is recorded past the bound" 501 "$(wc -l <"$MARK" | tr -d ' ')"
# parallel writers over a trace near the bound keep their entries (no rewrite in the way)
fresh
i=0; : >"$MARK"; while (( i < 495 )); do printf 'f%s/pad%s\n' "$TMPD" "$i" >>"$MARK"; i=$((i+1)); done
lost=0
for t in $(seq 30); do
  cp "$MARK" "$TMPD/near.bak"
  for w in 1 2 3; do ( cd "$EC_PROJ" && printf '%s' "$(sbash "echo x > $TMPD/w$t$w")" | bash "$TF" >/dev/null 2>&1 ) & done
  wait
  [[ "$(grep -c -F "w${t}1" "$MARK")" == 1 || "$(grep -c -Fx '*' "$MARK")" == 1 ]] || lost=$((lost + 1))
  cp "$TMPD/near.bak" "$MARK"
done
assert_eq "parallel writers near the bound lose no entry" 0 "$lost"

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

# ---- r5: what the analysis cannot know counts as unknown --------------------------------------------------------------
for c in '"$BASH" -c '"'"'echo x > src/a.js'"'" '${SHELL} -c '"'"'echo x > src/a.js'"'" '"$(command -v bash)" -c '"'"'echo x > src/a.js'"'" \
  'exec "$BASH" -c '"'"'echo x > src/a.js'"'" 'env "$BASH" -c '"'"'echo x > src/a.js'"'" \
  'python3 -c "import shutil; shutil.copy(\"/tmp/x\", \"src\")"' "node -e \"require('fs').cpSync('/tmp/d','.',{recursive:true})\"" \
  "perl -e 'open F, \">src/a.js\"'" 'python3 -c "print(1)"' $'python3 - <<X\nprint(1)\nX' 'eval "$X"' 'bsdtar -xf /tmp/a.tar' 'gtar xf /tmp/a.tar'; do
  fresh
  run "$TF" "$(sbash "$c")"
  if stopped; then pass "unknowable write ($c): the planning floor applies"; else fail "unknowable write ($c): the floor must apply"; fi
done
# a plain script, module or task run names no write: not counted (documented residual); a provably read-only bash -c is not either
for c in 'python3 script.py' './run.sh' 'make' 'npm test' 'sh script.sh' 'bash -c "echo hi"' 'python3 -m pytest' 'bsdtar -tf /tmp/a.tar'; do
  fresh
  run "$TF" "$(sbash "$c")"
  if stopped; then fail "no write evidence ($c): Stop must pass"; else pass "no write evidence ($c): Stop passes"; fi
done

# ---- r5: an ancestor glob counts only when it can lead to the project ----------------------------------------------
PARENT="$(dirname "$EC_PROJ")"
for c in "sed -i s/a/b/ $PARENT/*.log" "echo x > $PARENT/*.txt" 'sed -i s/a/b/ ~/Downloads/*.zip' 'sed -i s/a/b/ /tmp/*.log' "sed -i s/a/b/ /*.conf"; do
  fresh
  run "$TF" "$(sbash "$c")"
  if stopped; then fail "ancestor glob that cannot reach the project ($c): Stop must pass"; else pass "ancestor glob that cannot reach the project ($c): Stop passes"; fi
done
STARS="$(printf '%s' "$EC_PROJ" | sed 's|[^/][^/]*|*|g')"
for c in "rm -f $PARENT/*" "cp x $PARENT/${EC_PROJ##*/}*/s*/a.js" "cp x $PARENT/p*/a.js" "sed -i s/a/b/ $PARENT/**/*.js" "sed -i s/a/b/ $STARS/src/*.js"; do
  fresh
  run "$TF" "$(sbash "$c")"
  if stopped; then pass "ancestor glob that can reach the project ($c): the planning floor applies"; else fail "ancestor glob that can reach the project ($c)"; fi
done

# ---- r5: only real path fields of a file tool; a remote service's paths are not local --------------------------------
NB="$(jq -cn --arg p "$EC_PROJ/analysis.ipynb" --arg t $'# Results\n* accuracy improved\nWhat is the mean?' '{hook_event_name:"PostToolUse",tool_name:"NotebookEdit",tool_input:{notebook_path:$p,new_source:$t}}')"
fresh
run "$TF" "$NB"
if stopped; then fail "notebook cell text is not a path: a root-level notebook edit is not source"; else pass "notebook cell text is not a path"; fi
fresh
run "$TF" "$(jq -cn --arg t "$(seq 600 | sed 's/^/line /')" --arg p "$EC_PROJ/docs/n.ipynb" '{hook_event_name:"PostToolUse",tool_name:"NotebookEdit",tool_input:{notebook_path:$p,new_source:$t}}')"
assert_eq "a 600-line notebook cell records one entry" 1 "$(wc -l <"$MARK" | tr -d ' ')"
for t in mcp__github__create_or_update_file mcp__github__push_files mcp__Figma__upload_assets; do
  fresh
  run "$TF" "$(jq -cn --arg t "$t" '{hook_event_name:"PostToolUse",tool_name:$t,tool_input:{path:"src/app.js",name:"src",content:"x"}}')"
  if stopped; then fail "a remote service's path ($t) is not a local file"; else pass "a remote service's path ($t) is not a local file"; fi
done
fresh
run "$TF" "$(jq -cn --arg p "$EC_PROJ/s*/a?.js" '{hook_event_name:"PostToolUse",tool_name:"Write",tool_input:{file_path:$p,content:"x"}}')"
if stopped; then fail "a file tool does not expand globs: * and ? are part of the name"; else pass "a file tool path is literal"; fi
fresh
run "$TF" "$(jq -cn '{hook_event_name:"PostToolUse",tool_name:"Write",cwd:"/tmp",tool_input:{file_path:"src/a.js",content:"x"}}')"
if stopped; then fail "a relative Write from a cwd outside the project is not source"; else pass "a relative Write from another cwd is outside the project"; fi

# ---- r5: an unresolved cwd is an unknown target, even when no ancestor rule would catch it ---------------------------
# (the path is rooted at a directory that is not an ancestor of the project)
mkdir -p "$TMPD/elsewhere"
fresh
run "$TF" "$(jq -cn --arg d "$TMPD/elsewhere" '{hook_event_name:"PostToolUse",tool_name:"Bash",cwd:$d,tool_input:{command:"cd \"$P\" && echo x > src/a.js"}}')"
if stopped; then pass "an unresolved cwd under a directory that is no ancestor: unknown, counted"; else fail "unresolved cwd rule"; fi
fresh
run "$TF" "$(jq -cn --arg d "$TMPD/elsewhere" '{hook_event_name:"PostToolUse",tool_name:"Bash",cwd:$d,tool_input:{command:"echo x > out.txt"}}')"
if stopped; then fail "a plain relative write from that cwd is not source"; else pass "a plain relative write from that cwd is not source"; fi

# ---- r6: everyday read-only commands never count (an allowlist of the reasons that do) ---------------------------------
for c in 'node --version' 'node -v && npm -v' 'python3 --version' 'python3 -V' 'python --version' 'bash --version' 'zsh --version' 'perl -v' 'ruby -v' 'php -v' 'lua -v' 'node --help' 'python3 -h' \
  'curl -s https://api.github.com/repos/o/r/pulls' 'curl -sI https://example.com' 'wget -qO- https://example.com/x.json | jq .name' 'gh api graphql -F query=@q.graphql' 'gh api repos/o/r/pulls' 'gh pr list' 'gh pr view 1' \
  'sed -f s.sed f' 'awk -f p.awk f' 'awk "BEGIN{print 1}"' 'sed -n 1p README.md' 'git log --oneline | head -5' 'git diff HEAD~1 -- src' 'git status --short' 'git show HEAD:src/app.js' \
  'grep -rn foo src' 'cat src/app.js | wc -l' 'jq . package.json' 'docker ps' 'kubectl get pods' 'make -n' 'npm ls' 'npm test' 'pytest -q' 'cargo test' 'go test ./...' 'ls -la' 'find src -name "*.js"' 'diff a b' 'tree src' 'wc -l src/*.js' 'which node' 'echo hello' 'date' 'env | sort' 'git rev-parse HEAD' 'git branch --show-current' 'npx tsc --noEmit' 'terraform plan' 'uname -a'; do
  for tool in Bash exec_command; do
    fresh
    run "$TF" "$(sbash "$c" "$tool")"
    if stopped; then fail "everyday read-only command via $tool ($c): Stop must pass"; else pass "everyday read-only command via $tool ($c): Stop passes"; fi
  done
done
# the blocked unknowns stay blocked (positive list): variable program, eval, inline code of every interpreter, stdin programs
for c in '"$BASH" -c "x"' 'python3 -c "print(1)"' 'node -p "1+1"' 'php -r "echo 1;"' 'ruby -e "1"' 'lua -e "x=1"' 'perl -e "1"' 'sed -e "e echo x" f' 'awk "BEGIN{system(\"touch a\")}"' 'node < prog.js' 'cat p.js | node' 'bash -s' 'eval "$X"'; do
  fresh
  run "$TF" "$(sbash "$c")"
  if stopped; then pass "unknown program ($c): counted"; else fail "unknown program ($c): must count"; fi
done

# ---- r6: rotation with earlier traces present never loses an append ----------------------------------------------------
A="$(jq -cn --arg p "$EC_PROJ/src/a.js" '{hook_event_name:"PostToolUse",tool_name:"Write",tool_input:{file_path:$p}}')"
B="$(jq -cn --arg p "$TMPD/zz" '{hook_event_name:"PostToolUse",tool_name:"Write",tool_input:{file_path:$p}}')"
lost=0
for t in $(seq 100); do
  fresh
  for e in 1 2 3 4 5 6 7 8; do printf 'f/old%s\n' "$e" >"$MARKBASE.$e"; done
  (cd "$EC_PROJ" && printf '%s' "$A" | bash "$TF" >/dev/null 2>&1) & p1=$!
  (cd "$EC_PROJ" && printf '%s' "$B" | bash "$TF" >/dev/null 2>&1) & p2=$!
  (cd "$EC_PROJ" && printf '%s' "$B" | bash "$TF" >/dev/null 2>&1) & p3=$!
  wait "$p1" "$p2" "$p3"
  grep -q "src/a.js" "$MARK" || lost=$((lost + 1))
done
assert_eq "100 trials with 8 earlier traces: no src entry lost" 0 "$lost"

# ---- r6: a glob spelling of the state directory is an unknown write ------------------------------------------------------
fresh
run "$TF" "$(swrite "$EC_PROJ/src/app.js")"
rm -f "$MARK"
run "$TF" "$(sbash 'rm ~/.c*/.s*/files-written*')"
if stopped; then pass "an erase of the trace by a glob spelling of the state dir: unknown, the floor applies"; else fail "glob erase of the trace"; fi
SDH="${SD%/*}"
fresh
run "$TF" "$(sbash "rm $SDH/.s*/files-w*")"
if stopped; then pass "a glob inside the state dir's parent that can match it counts"; else fail "glob into the state dir"; fi
fresh
run "$TF" "$(sbash "rm $SDH/.q*/files-w*")"
if stopped; then fail "a glob that cannot match the state dir is not an erase"; else pass "a glob that cannot match the state dir is not an erase"; fi
fresh
run "$TF" "$(sbash 'rm /tmp/*.log')"
if stopped; then fail "/tmp/*.log cannot reach the state dir"; else pass "/tmp/*.log cannot reach the state dir"; fi

# ---- r6: local MCP tools use the same path keys as the PreToolUse write guard -------------------------------------------
for pl in '{pathInProject:$p,text:"x"}' '{filename:$p,content:"x"}' '{file:$p}' '{uri:$p}' '{edits:[{path:$p,newText:"x"}]}' '{params:{target_file:$p}}'; do
  fresh
  run "$TF" "$(jq -cn --arg p "$EC_PROJ/src/m.js" "{hook_event_name:\"PostToolUse\",tool_name:\"mcp__jetbrains__replace_file_text_by_path\",tool_input:$pl}")"
  if stopped; then pass "local MCP write ($pl): the planning floor applies"; else fail "local MCP write ($pl) must count"; fi
done
fresh
run "$TF" "$(jq -cn --arg p "$EC_PROJ/src/m.js" '{hook_event_name:"PostToolUse",tool_name:"mcp__localGoogleSync__write_file",tool_input:{path:$p}}')"
if stopped; then pass "a local server whose name merely contains Google is not remote"; else fail "mcp__localGoogleSync__ is local"; fi
fresh
run "$TF" "$(jq -cn --arg p "$EC_PROJ/src/m.js" '{hook_event_name:"PostToolUse",tool_name:"mcp__fs__write_file",tool_input:{content:$p,body:$p}}')"
if stopped; then fail "content and body are never paths"; else pass "content and body are never paths"; fi
# a single-line notebook cell: the newline filter alone cannot make this pass; only notebook_path is read
fresh
run "$TF" "$(jq -cn --arg p "$EC_PROJ/analysis.ipynb" '{hook_event_name:"PostToolUse",tool_name:"NotebookEdit",tool_input:{notebook_path:$p,new_source:"* accuracy improved"}}')"
if stopped; then fail "a single-line notebook cell is not a path"; else pass "a single-line notebook cell is not a path"; fi
fresh
run "$TF" "$(jq -cn --arg p "$EC_PROJ/docs/n.ipynb" '{hook_event_name:"PostToolUse",tool_name:"NotebookEdit",tool_input:{notebook_path:$p,new_source:"what is the mean?"}}')"
if stopped; then fail "a single-line question cell is not a path"; else pass "a single-line question cell is not a path"; fi

# ---- concurrent recorders never lose an entry (header-less append-only trace) --------------------------------------
A="$(jq -cn --arg p "$EC_PROJ/src/a.js" '{hook_event_name:"PostToolUse",tool_name:"Write",tool_input:{file_path:$p}}')"
B="$(jq -cn --arg p "$TMPD/zz" '{hook_event_name:"PostToolUse",tool_name:"Write",tool_input:{file_path:$p}}')"
lost=0; N=60
for i in $(seq "$N"); do
  fresh
  (cd "$EC_PROJ" && printf '%s' "$A" | bash "$TF" >/dev/null 2>&1) & p1=$!
  (cd "$EC_PROJ" && printf '%s' "$B" | bash "$TF" >/dev/null 2>&1) & p2=$!
  (cd "$EC_PROJ" && printf '%s' "$B" | bash "$TF" >/dev/null 2>&1) & p3=$!
  wait "$p1" "$p2" "$p3"
  grep -q "src/a.js" "$MARK" || lost=$((lost + 1))
done
assert_eq "60 concurrent first writes by 3 hooks: no src entry lost" 0 "$lost"

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
