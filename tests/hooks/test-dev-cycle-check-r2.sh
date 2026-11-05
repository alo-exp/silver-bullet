#!/usr/bin/env bash
# dev-cycle-check round-2 repair: glob, brace and variable targets, patch and git apply, plugin-root
# copies, inline interpreter code, the contract unlock window, MCP path keys and verbs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/cov-a-dc.sh"
# shellcheck source=../../hooks/lib/planning-floor.sh
source "$TL_REPO_ROOT/hooks/lib/planning-floor.sh"

SD="$SB_RUNTIME_STATE_DIR"
RT="$SB_RUNTIME_NAME"

rm -f "$SD/contract-unlock"
not_deny() { if [[ "$(decision)" == deny ]]; then echo deny; else echo ok; fi; }

# ── glob metacharacters, brace lists and variables in a write target ─────────────────────────────
mkproj globs
state ""
mkdir -p "$PROJ/.planning" "$PROJ/docs" "$PROJ/build"
: >"$PROJ/.planning/ROADMAP.md"
: >"$PROJ/docs/a.md"
printf 'cp /tmp/x .silver-bullet.j?on\n' >"$PROJ/s4.sh"
for c in 'cp /tmp/x .silver-bullet.j?on' 'cp /tmp/x .silver-bullet.js[o]n' 'cp /tmp/x .silver-bullet.j*' \
  'mv /tmp/x .silver-bullet.{json,x}' 'for f in .silver-bullet.j*; do cp /tmp/x "$f"; done' 'bash s4.sh' 'touch .silver-bullet.p{rompt.json,y}'; do
  dc_cmd "$c"
  assert_contains "refused as the contract file it can name: $c" "$(message)" ".silver-bullet"
done
for c in 'rm silver-bullet.m?' 'rm silver-bullet.[m]d' 'cp /tmp/x silver-bullet.*'; do
  dc_cmd "$c"
  assert_contains "refused as silver-bullet.md: $c" "$(message)" "silver-bullet.md defines"
done
for c in "cp /tmp/x ${SD%?}?/state-test" "echo x > $SD/trivia[l]" "echo x > $SD/stat?" "cp /tmp/x \$T/state" 'echo hi > $OUT' "tee \${LOG}/state < /dev/null"; do
  dc_cmd "$c"
  assert_contains "refused as the state directory: $c" "$(message)" "STATE TAMPER"
done
state inst-a
dc_cmd 'cp /tmp/x .silver-bullet.j?on'
assert_contains "a finished planning floor does not matter for the contract" "$(message)" "ENFORCEMENT CONTRACT PROTECTED"
for c in 'ls .silver-bullet.j*' 'cat docs/*.md' 'rm -f build/*.o' 'cp a.txt build/out?.txt' 'sed -i s/a/b/ docs/*.md' 'cp /tmp/x "$DIST/out.js"' 'echo x > build/{a,b}.txt' 'git status --short'; do
  dc_cmd "$c"
  assert_eq "honest pattern passes: $c" "none" "$(decision)"
done
state ""
dc_cmd 'touch src/{a,b}.js'
assert_contains "every alternative of a brace list counts for the planning floor" "$(message)" "Planning incomplete"
dc_cmd 'cp /tmp/x src/ap?.js'
assert_contains "and a pattern inside src" "$(message)" "Planning incomplete"

# ── patch, git apply, git am: a tree written by a diff that cannot be read ─────────────────────
mkproj trees
state ""
for c in 'git apply /tmp/p.diff' 'patch -p1 < /tmp/p.diff' 'patch -i /tmp/p.diff' 'git am /tmp/p.mbox' 'git diff main | git apply'; do
  dc_cmd "$c"
  assert_contains "a source tree written without planning is refused: $c" "$(message)" "Planning incomplete"
done
dc_cmd "patch -d $HOME/.${RT} -p1 < /tmp/p.diff"
assert_contains "a patch applied above the state directory is refused" "$(message)" "STATE TAMPER"
dc_cmd "git -C $HOME/.${RT} apply /tmp/p.diff"
assert_contains "git -C above the state directory is refused" "$(message)" "STATE TAMPER"
printf -- '--- a/src/app.js\n+++ b/src/app.js\n@@ -0,0 +1 @@\n+x\n' >"$TL_TMP/p.diff"
dc_cmd "git apply $TL_TMP/p.diff"
assert_contains "a readable diff names its files" "$(message)" "Planning incomplete"
state inst-a
for c in 'git apply /tmp/p.diff' 'patch -p1 < /tmp/p.diff' 'git am /tmp/p.mbox' 'git apply --check /tmp/p.diff'; do
  dc_cmd "$c"
  assert_eq "after planning an honest patch passes: $c" "ok" "$(not_deny)"
done
dc_cmd "patch -d $HOME/.${RT} -p1 < /tmp/p.diff"
assert_contains "but never above the state directory" "$(message)" "STATE TAMPER"

# ── the plugin root: copies and links of it (R3-01) ─────────────────────────────────────────────
INSTALLED="$SB_RUNTIME_HOME_ROOT/sbplugin"
mkdir -p "$INSTALLED/templates"
cp -R "$TL_REPO_ROOT/hooks" "$INSTALLED/hooks"
cp "$TL_REPO_ROOT/templates/silver-bullet.config.json.default" "$INSTALLED/templates/"
HOOKS_DIR="$INSTALLED/hooks"
inst() { HOOK_UNDER_TEST="$INSTALLED/hooks/dev-cycle-check.sh" run_dc "$@"; }
mkproj plugin
state inst-a
for c in "cp -r $INSTALLED $TL_TMP/c1" "cp -a $INSTALLED/. $TL_TMP/c1" "rsync -a $INSTALLED/ $TL_TMP/c1/" "mv $INSTALLED $TL_TMP/c1" "ln -s $INSTALLED $TL_TMP/c1" \
  "cp -r $SB_RUNTIME_HOME_ROOT $TL_TMP/c1" "tar -cf $TL_TMP/p.tar $INSTALLED" "find $INSTALLED -name 'record-s*' -exec mv {} $TL_TMP/x \;" \
  "mkdir -p $TL_TMP/w && cp -r $INSTALLED $TL_TMP/w/c && find $TL_TMP/w/c -name 'record-s*' -exec mv {} $TL_TMP/w/c/hooks/x.sh \;"; do
  inst "$(bash_json "$c")"
  assert_contains "copying, moving or linking the plugin root is refused: ${c:0:60}" "$(message)" "recorder hook"
done
inst "$(bash_json "bash $HOOKS_DIR/record-s*.sh")"
assert_contains "a recorder launched by glob is a recorder, not a hooks edit" "$(message)" "recorder hook"
for c in "ls $INSTALLED" "cat $HOOKS_DIR/record-skill.sh" "cp -r $INSTALLED/templates $TL_TMP/t" "cp -r $INSTALLED/skills $TL_TMP/s" "git status --short"; do
  inst "$(bash_json "$c")"
  assert_eq "reading it or copying its non-hook parts passes: ${c:0:50}" "none" "$(decision)"
done

# ── code given on the command line ─────────────────────────────────────────────────────────────
mkproj inline
state inst-a
for c in "python3 -c \"import os;os.replace('/tmp/x','.silver-'+'bullet.json')\"" "python3 -c \"print(1)\"" "node -e \"console.log(1)\"" "perl -e 'print 1'" "ruby -e 'puts 1'" \
  "awk 'BEGIN{system(\"ls\")}'" "python3 - <<'PY'
print(1)
PY"; do
  dc_cmd "$c"
  assert_contains "inline interpreter code is refused: ${c:0:50}" "$(message)" "cannot inspect"
done
dc_cmd "python3 -c \"print(1)\""
assert_contains "the message says which kind of code" "$(message)" "inline python code"
assert_contains "and how to proceed" "$(message)" "script file"
RUN_DIR="$NOCFG" dc_cmd "python3 -c \"print(1)\""
assert_eq "outside an SB project nothing is gated" "none" "$(decision)"
printf 'print(1)\n' >"$PROJ/ok.py"
for c in 'python3 ok.py' 'python3 -m pytest -q' 'node --version' 'git log --oneline' 'jq . .silver-bullet.json'; do
  dc_cmd "$c"
  assert_eq "honest command passes: $c" "none" "$(decision)"
done
unlock silver-init
dc_cmd "python3 -c \"print(1)\""
assert_eq "while the init skill runs its inline reads are allowed" "none" "$(decision)"
rm -f "$SD/contract-unlock"
dc_cmd "python3 -c \"print(open('.silver-bullet.json').read())\""
assert_contains "naming a contract file keeps the specific message, naming the file" "$(message)" ".silver-bullet.json defines"

# ── the contract unlock: a window, and json-only skills ───────────────────────────────────────
mkproj window
state inst-a
CFGW='TMP=$(mktemp)
jq ".project.x=1" .silver-bullet.json > "$TMP" && mv "$TMP" .silver-bullet.json'
MDW='echo more >> silver-bullet.md'
rm -f "$SD/contract-unlock"
dc_cmd "$CFGW"
assert_contains "without an unlock record the rewrite is refused" "$(message)" "ENFORCEMENT CONTRACT PROTECTED"
state inst-a silver-add silver-init
dc_cmd "$CFGW"
assert_contains "a skill merely listed in the state unlocks nothing" "$(message)" "ENFORCEMENT CONTRACT PROTECTED"
for sk in silver-init silver-update silver-migrate; do
  unlock "$sk"
  dc_cmd "$CFGW"
  assert_eq "$sk unlocks the config" "none" "$(decision)"
  dc_cmd "$MDW"
  assert_eq "$sk unlocks silver-bullet.md" "none" "$(decision)"
done
for sk in silver-add silver-devops; do
  unlock "$sk"
  dc_cmd "$CFGW"
  assert_eq "$sk unlocks the config" "none" "$(decision)"
  dc_cmd "$MDW"
  assert_contains "$sk does not unlock silver-bullet.md" "$(message)" "ENFORCEMENT CONTRACT PROTECTED"
done
unlock silver-init "$(( $(date +%s) - 10000 ))"
dc_cmd "$CFGW"
assert_contains "an unlock that is older than its window has lapsed" "$(message)" "ENFORCEMENT CONTRACT PROTECTED"
unlock silver-plan
dc_cmd "$CFGW"
assert_contains "a record for a skill that does not own the files unlocks nothing" "$(message)" "ENFORCEMENT CONTRACT PROTECTED"
printf 'silver-init notanumber\n' >"$SD/contract-unlock"
dc_cmd "$CFGW"
assert_contains "a damaged record unlocks nothing" "$(message)" "ENFORCEMENT CONTRACT PROTECTED"
rm -f "$SD/contract-unlock"
ln -s "$TL_TMP/elsewhere" "$SD/contract-unlock"
dc_cmd "$CFGW"
assert_contains "a symbolic link unlocks nothing" "$(message)" "ENFORCEMENT CONTRACT PROTECTED"
rm -f "$SD/contract-unlock"

# ── MCP: path keys and verbs ──────────────────────────────────────────────────────────────────
mkproj mcp
state inst-a
mcp_json() { jq -cn --arg t "$1" --arg k "$2" --arg v "$3" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:{($k):$v}}'; }
for spec in "mcp__serena__create_text_file relative_path .silver-bullet.json" "mcp__fs__fs_mv from silver-bullet.md" "mcp__fs__copy_file destination .silver-bullet.prompt.json" \
  "mcp__serena__insert_at_line relative_path .silver-bullet.json" "mcp__x__put_file target silver-bullet.md" "mcp__x__upload_blob dest_path silver-bullet.md"; do
  # shellcheck disable=SC2086  # the spec is three words
  set -- $spec
  run_dc "$(mcp_json "$1" "$2" "$3")"
  assert_contains "MCP write tool $1 with $2 is judged" "$(message)" "ENFORCEMENT CONTRACT PROTECTED"
done
run_dc "$(mcp_json mcp__x__read_file relative_path .silver-bullet.json)"
assert_eq "an MCP read tool is not gated" "none" "$(decision)"
run_dc "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"mcp__x__write_file",tool_input:{path:"README.md",content:"silver-bullet.md .silver-bullet.json"}}')"
assert_eq "text in a content field is not a path" "none" "$(decision)"
MATCHER="$(jq -r '[.hooks.PreToolUse[] | select(.hooks | map(.command) | join(" ") | contains("dev-cycle-check")) | .matcher][0]' "$TL_REPO_ROOT/hooks/hooks.json")"
for n in mcp__serena__insert_after_symbol mcp__fs__fs_mv mcp__x__copy_file mcp__s__put_file mcp__s__upload_blob mcp__x__apply_diff mcp__x__write_file mcp__x__str_replace_editor mcp__x__delete_file mcp__x__append_text; do
  if printf '%s' "$n" | grep -Eq "^($MATCHER)\$"; then tl_pass "the hooks.json matcher covers $n"; else tl_fail "the hooks.json matcher misses $n"; fi
  sb_pf_mcp_write_tool "$n" && tl_pass "the guard treats $n as a writer" || tl_fail "the guard misses $n"
done
for n in mcp__x__read_file mcp__x__get_file_contents mcp__x__list_directory mcp__x__search_code mcp__github__pull_request_read; do
  if printf '%s' "$n" | grep -Eq "^($MATCHER)\$"; then tl_fail "the matcher fires for the reader $n"; else tl_pass "the matcher leaves $n alone"; fi
  sb_pf_mcp_write_tool "$n" && tl_fail "the guard treats the reader $n as a writer" || tl_pass "the guard leaves $n alone"
done

# ── Edit and Write need no interpreter ──────────────────────────────────────────────────────
mkproj fast
state inst-a
REALPY="$(command -v python3)"
tl_stub python3 "printf 'x\n' >>\"$TL_TMP/py-calls\"; exec \"$REALPY\" \"\$@\""
: >"$TL_TMP/py-calls"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "an Edit with a file_path starts no interpreter" 0 "$(wc -l <"$TL_TMP/py-calls" | tr -d ' ')"
assert_eq "and still passes with planning done" "ok" "$(not_deny)"
state ""
run_dc "$(edit_json "$PROJ/src/app.js" Write PreToolUse)"
assert_eq "and still refuses without it" "deny" "$(decision)"
rm -f "$TL_BIN/python3"

# ── variables, ranges, scripts, in-place filters, scripts written by the command ─────────────────
mkproj vars
state inst-a
printf 'echo x > "$OUT"\n' >"$PROJ/s5.sh"
for c in 'T=$(mktemp); echo x > "$T"' 'echo x > "$(mktemp)"' 'T=$(mktemp -d); echo x > $T/f' 'bash s5.sh' 'echo x > build/f{1..3}.txt' 'cat > "${TMPDIR:-/tmp}/x.log" < /dev/null'; do
  dc_cmd "$c"
  assert_eq "honest variable, range or script passes: $c" "none" "$(decision)"
done
for c in 'echo x > "$OUT"' 'echo x > $OUT'; do
  dc_cmd "$c"
  assert_contains "an unknown bare variable target is refused: $c" "$(message)" "STATE TAMPER"
done
dc_cmd "perl -pi -e 's/a/b/' docs/a.md"
assert_eq "a perl in-place filter over named files passes" "none" "$(decision)"
dc_cmd "ruby -pi -e 'x' docs/a.md"
assert_eq "so does ruby" "none" "$(decision)"
dc_cmd "perl -e 'print 1'"
assert_contains "perl code that is not a filter is refused" "$(message)" "inline perl code"
printf 'print(1)\n' >"$PROJ/ok2.py"
dc_cmd "printf 'print(1)' > gen.py; python3 gen.py"
assert_contains "a script the command writes and runs is refused" "$(message)" "gen.py"
dc_cmd "cat > gen.sh <<'EOF'
echo hi
EOF
bash gen.sh"
assert_contains "a shell script written by a heredoc and run is refused" "$(message)" "gen.sh"
mkdir -p "$PROJ/d.py"
dc_cmd "python3 d.py"
assert_contains "a script path that cannot be read is refused" "$(message)" "d.py"
dc_cmd "python3 missing.py"
assert_eq "a script that does not exist yet fails by itself" "none" "$(decision)"
dc_cmd "python3 ok2.py"
assert_eq "a readable script passes" "none" "$(decision)"
mkdir -p "$PROJ/src/sub"
dc_cmd "cd src && patch -p1 < /tmp/p.diff"
assert_eq "a patch in a source subdirectory after planning is not refused" "ok" "$(not_deny)"
state ""
dc_cmd "cd src && patch -p1 < /tmp/p.diff"
assert_contains "and needs the planning floor without it" "$(message)" "Planning incomplete"

# ── the remaining branches: huge globs, odd variables, odd braces, no interpreter ────────────────
mkproj odd
state inst-a
mkdir -p "$PROJ/many"
for i in $(seq 1 210); do : >"$PROJ/many/f$i.o"; done
dc_cmd 'rm -f many/f*.o'
assert_eq "a pattern with hundreds of matches is capped, not refused" "none" "$(decision)"
dc_cmd 'echo x > $1'
assert_contains "a positional parameter as a target could be anything" "$(message)" "STATE TAMPER"
for c in '(echo build/{a,b})' 'echo ${HOME}x{a,b}' 'touch {,}'; do
  dc_cmd "$c"
  assert_eq "odd brace words are handled: $c" "none" "$(decision)"
done
state ""
NOPY2="$(tl_path_without python3)"
run_dc "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"mcp__x__write_file",tool_input:{path:"src/app.js"}}')" PATH="$NOPY2"
assert_contains "an MCP write needs no interpreter to be judged" "$(message)" "Planning incomplete"

tl_results
